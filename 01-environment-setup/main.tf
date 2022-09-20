/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/******************************************
Local variables declaration
 *****************************************/

locals {
project_id                  = "${var.project_id}"
project_nbr                 = "${var.project_number}"
admin_upn_fqn               = "${var.gcp_account_name}"
location                    = "${var.gcp_region}"
zone                        = "${var.gcp_zone}"
location_multi              = "${var.gcp_multi_region}"
umsa                        = "s8s-lab-sa"
umsa_fqn                    = "${local.umsa}@${local.project_id}.iam.gserviceaccount.com"
s8s_spark_jars_bucket       = "s8s-spark-jars-bucket-${local.project_nbr}"
s8s_spark_scripts_bucket    = "s8s-spark-scripts-bucket-${local.project_nbr}"
s8s_spark_checkpoint_bucket = "s8s-spark-checkpoint-bucket-${local.project_nbr}"
s8s_spark_bucket            = "s8s-spark-bucket-${local.project_nbr}"
s8s_spark_bucket_fqn        = "gs://s8s-spark-${local.project_nbr}"
s8s_spark_sphs_nm           = "s8s-sphs-${local.project_nbr}"
s8s_spark_sphs_bucket       = "s8s-sphs-${local.project_nbr}"
s8s_spark_sphs_bucket_fqn   = "gs://s8s-sphs-${local.project_nbr}"
s8s_code_bucket            = "s8s-code-bucket-${local.project_nbr}"
s8s_code_bucket_fqn        = "gs://s8s-code-${local.project_nbr}"
vpc_nm                      = "s8s-vpc-${local.project_nbr}"
spark_subnet_nm             = "spark-snet"
spark_subnet_cidr           = "10.0.0.0/16"
bq_datamart_ds              = "marketing_ds"
bq_connector_jar_gcs_uri    = "${var.bq_connector_jar_gcs_uri}"
}

/******************************************
Update organization policies in parallel
 *****************************************/
resource "google_project_organization_policy" "orgPolicyUpdate_disableSerialPortLogging" {
  project     = var.project_id
  constraint = "compute.disableSerialPortLogging"
  boolean_policy {
    enforced = false
  }
}

resource "google_project_organization_policy" "orgPolicyUpdate_requireOsLogin" {
  project     = var.project_id
  constraint = "compute.requireOsLogin"
  boolean_policy {
    enforced = false
  }
}

resource "google_project_organization_policy" "orgPolicyUpdate_requireShieldedVm" {
  project     = var.project_id
  constraint = "compute.requireShieldedVm"
  boolean_policy {
    enforced = false
  }
}

resource "google_project_organization_policy" "orgPolicyUpdate_vmCanIpForward" {
  project     = var.project_id
  constraint = "compute.vmCanIpForward"
  list_policy {
    allow {
      all = true
    }
  }
}

resource "google_project_organization_policy" "orgPolicyUpdate_vmExternalIpAccess" {
  project     = var.project_id
  constraint = "compute.vmExternalIpAccess"
  list_policy {
    allow {
      all = true
    }
  }
}

resource "google_project_organization_policy" "orgPolicyUpdate_restrictVpcPeering" {
  project     = var.project_id
  constraint = "compute.restrictVpcPeering"
  list_policy {
    allow {
      all = true
    }
  }
}

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_org_policy_updates" {
  create_duration = "120s"
  depends_on = [
    google_project_organization_policy.orgPolicyUpdate_disableSerialPortLogging,
    google_project_organization_policy.orgPolicyUpdate_requireOsLogin,
    google_project_organization_policy.orgPolicyUpdate_requireShieldedVm,
    google_project_organization_policy.orgPolicyUpdate_vmCanIpForward,
    google_project_organization_policy.orgPolicyUpdate_vmExternalIpAccess,
    google_project_organization_policy.orgPolicyUpdate_restrictVpcPeering
  ]
}

/******************************************
Enable Google APIs in parallel
 *****************************************/

resource "google_project_service" "enable_orgpolicy_google_apis" {
  project = var.project_id
  service = "orgpolicy.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

resource "google_project_service" "enable_compute_google_apis" {
  project = var.project_id
  service = "compute.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}


resource "google_project_service" "enable_dataproc_google_apis" {
  project = var.project_id
  service = "dataproc.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

resource "google_project_service" "enable_bigquery_google_apis" {
  project = var.project_id
  service = "bigquery.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

resource "google_project_service" "enable_storage_google_apis" {
  project = var.project_id
  service = "storage.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}


/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_api_enabling" {
  create_duration = "180s"
  depends_on = [
    google_project_service.enable_orgpolicy_google_apis,
    google_project_service.enable_compute_google_apis,
    google_project_service.enable_dataproc_google_apis,
    google_project_service.enable_bigquery_google_apis,
    google_project_service.enable_storage_google_apis
  ]
}

/******************************************
Create User Managed Service Account 
 *****************************************/
module "umsa_creation" {
  source     = "terraform-google-modules/service-accounts/google"
  project_id = local.project_id
  names      = ["${local.umsa}"]
  display_name = "User Managed Service Account"
  description  = "User Managed Service Account for Serverless Spark"
   depends_on = [time_sleep.sleep_after_api_enabling]
}

/******************************************
Grant IAM roles to User Managed Service Account
 *****************************************/

module "umsa_role_grants" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = "${local.umsa_fqn}"
  prefix                  = "serviceAccount"
  project_id              = local.project_id
  project_roles = [
    
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/dataproc.worker",
    "roles/bigquery.dataEditor",
    "roles/bigquery.admin",
    "roles/dataproc.editor",
    "roles/viewer"
  ]
  depends_on = [
    module.umsa_creation
  ]
}

/******************************************************
Grant Service Account Impersonation privilege to yourself/Admin User
 ******************************************************/

module "umsa_impersonate_privs_to_admin" {
  source  = "terraform-google-modules/iam/google//modules/service_accounts_iam/"
  service_accounts = ["${local.umsa_fqn}"]
  project          = local.project_id
  mode             = "additive"
  bindings = {
    "roles/iam.serviceAccountUser" = [
      "user:${local.admin_upn_fqn}"
    ],
    "roles/iam.serviceAccountTokenCreator" = [
      "user:${local.admin_upn_fqn}"
    ]

  }
  depends_on = [
    module.umsa_creation
  ]
}

/******************************************************
Grant IAM roles to Admin User/yourself
 ******************************************************/

module "administrator_role_grants" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  projects = ["${local.project_id}"]
  mode     = "additive"

  bindings = {
    "roles/storage.admin" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/dataproc.admin" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.admin" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.user" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.dataEditor" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.jobUser" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/iam.serviceAccountUser" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/iam.serviceAccountTokenCreator" = [
      "user:${local.admin_upn_fqn}",
    ]
  }
  depends_on = [
    module.umsa_role_grants,
    module.umsa_impersonate_privs_to_admin
  ]
  }

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_identities_permissions" {
  create_duration = "120s"
  depends_on = [
    module.umsa_creation,
    module.umsa_role_grants,
    module.umsa_impersonate_privs_to_admin,
    module.administrator_role_grants
  ]
}

/************************************************************************
Create VPC network, subnet & reserved static IP creation
 ***********************************************************************/
module "vpc_creation" {
  source                                 = "terraform-google-modules/network/google"
  project_id                             = local.project_id
  network_name                           = local.vpc_nm
  routing_mode                           = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${local.spark_subnet_nm}"
      subnet_ip             = "${local.spark_subnet_cidr}"
      subnet_region         = "${local.location}"
      subnet_range          = local.spark_subnet_cidr
      subnet_private_access = true
    }
  ]
  depends_on = [
    time_sleep.sleep_after_identities_permissions
  ]
}

/******************************************
Create Firewall rules 
*****************************************/

resource "google_compute_firewall" "allow_intra_snet_ingress_to_any" {
  project   = local.project_id 
  name      = "allow-intra-snet-ingress-to-any"
  network   = local.vpc_nm
  direction = "INGRESS"
  source_ranges = [local.spark_subnet_cidr]
  allow {
    protocol = "all"
  }
  description        = "Creates firewall rule to allow ingress from within Spark subnet on all ports, all protocols"
  depends_on = [
    module.vpc_creation, 
    module.administrator_role_grants
  ]
}

resource "google_compute_router" "router_creation" {
  name    = "s8s-spark-router"
  region  = local.location
  network = local.vpc_nm

  bgp {
    asn = 64514
  }
  depends_on = [
    module.vpc_creation, 
    module.administrator_role_grants
  ]
}

resource "google_compute_router_nat" "nat_creation" {
  name                               = "s8s-spark-nat"
  router                             = google_compute_router.router_creation.name
  region                             = local.location
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [
    module.vpc_creation, 
    google_compute_router.router_creation,
    module.administrator_role_grants
  ]
}

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_network_and_firewall_creation" {
  create_duration = "120s"
  depends_on = [
    module.vpc_creation,
    google_compute_firewall.allow_intra_snet_ingress_to_any
  ]
}

/******************************************
Create Storage bucket 
*****************************************/

resource "google_storage_bucket" "s8s_spark_bucket_creation" {
  project                           = local.project_id 
  name                              = local.s8s_spark_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}

resource "google_storage_bucket" "s8s_spark_sphs_bucket_creation" {
  project                           = local.project_id 
  name                              = local.s8s_spark_sphs_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}

resource "google_storage_bucket" "spark_kafka_checkpoint_bucket_creation" {
  project                           = local.project_id 
  name                              = local.s8s_spark_checkpoint_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}

resource "google_storage_bucket" "spark_jar_bucket_creation" {
  project                           = local.project_id 
  name                              = local.s8s_spark_jars_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}

resource "google_storage_bucket" "spark_scripts_bucket_creation" {
  project                           = local.project_id 
  name                              = local.s8s_spark_scripts_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}

resource "google_storage_bucket" "spark_code_bucket_creation" {
  project                           = local.project_id 
  name                              = local.s8s_code_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}

/******************************************
Upload to storage buckets 
*****************************************/

resource "google_storage_bucket_object" "jars_upload_to_gcs" {
  for_each = fileset("../05-jars/", "*")
  source = "../05-jars/${each.value}"
  name = "${each.value}"
  bucket = "${local.s8s_spark_jars_bucket}"
  depends_on = [
    time_sleep.sleep_after_bucket_creation,
    google_storage_bucket.spark_jar_bucket_creation
  ]
}

resource "google_storage_bucket_object" "code_upload_to_gcs" {
  for_each = fileset("../02-scripts/pyspark/", "*")
  source = "../02-scripts/pyspark/${each.value}"
  name = "${each.value}"
  bucket = "${local.s8s_code_bucket}"
  depends_on = [
    time_sleep.sleep_after_bucket_creation,
    google_storage_bucket.spark_code_bucket_creation
  ]
}

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/

resource "time_sleep" "sleep_after_bucket_creation" {
  create_duration = "60s"
  depends_on = [
    google_storage_bucket.s8s_spark_sphs_bucket_creation,
    google_storage_bucket.s8s_spark_bucket_creation
  ]
}

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/

resource "time_sleep" "sleep_after_network_and_storage_steps" {
  create_duration = "90s"
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation,
      time_sleep.sleep_after_bucket_creation
  ]
}

/******************************************
PHS creation
******************************************/

resource "google_dataproc_cluster" "sphs_creation" {
  project  = local.project_id 
  provider = google-beta
  name     = local.s8s_spark_sphs_nm
  region   = local.location

  cluster_config {
    
    endpoint_config {
        enable_http_port_access = true
    }

    staging_bucket = local.s8s_spark_bucket
    
    # Override or set some custom properties
    software_config {
      image_version = "2.0"
      override_properties = {
        "dataproc:dataproc.allow.zero.workers"=true
        "dataproc:job.history.to-gcs.enabled"=true
        "spark:spark.history.fs.logDirectory"="${local.s8s_spark_sphs_bucket_fqn}/*/spark-job-history"
        "mapred:mapreduce.jobhistory.read-only.dir-pattern"="${local.s8s_spark_sphs_bucket_fqn}/*/mapreduce-job-history/done"
      }      
    }
    gce_cluster_config {
      subnetwork =  "projects/${local.project_id}/regions/${local.location}/subnetworks/${local.spark_subnet_nm}" 
      service_account = local.umsa_fqn
      service_account_scopes = [
        "cloud-platform"
      ]
    }
  }
  depends_on = [
    module.administrator_role_grants,
    module.vpc_creation,
    time_sleep.sleep_after_api_enabling,
    time_sleep.sleep_after_network_and_storage_steps
  ]  
}

/******************************************
BigQuery dataset creation
******************************************/

resource "google_bigquery_dataset" "bq_dataset_creation" {
  dataset_id                  = local.bq_datamart_ds
  location                    = local.location_multi
}

resource "google_bigquery_table" "entries_table_creation" {
  dataset_id = "${google_bigquery_dataset.bq_dataset_creation.dataset_id}"
  table_id   = "entries"
  deletion_protection = "false"
  schema = "${file("../02-scripts/bigquery/entries_schema.json")}"
}

resource "google_bigquery_table" "promotions_table_creation" {
  dataset_id = "${google_bigquery_dataset.bq_dataset_creation.dataset_id}"
  table_id   = "promotions"
  deletion_protection = "false"
  schema = "${file("../02-scripts/bigquery/promotions_schema.json")}"
}

resource "google_bigquery_table" "winners_table_creation" {
  dataset_id = "${google_bigquery_dataset.bq_dataset_creation.dataset_id}"
  table_id   = "winners"
  deletion_protection = "false"
  schema = "${file("../02-scripts/bigquery/winners_schema.json")}"
}

/******************************************
Output variables
******************************************/

output "PROJECT_ID" {
  value = local.project_id
}

output "PROJECT_NBR" {
  value = local.project_nbr
}

output "LOCATION" {
  value = local.location
}

output "VPC_NM" {
  value = local.vpc_nm
}

output "SPARK_SERVERLESS_SUBNET" {
  value = local.spark_subnet_nm
}

output "PERSISTENT_HISTORY_SERVER_NM" {
  value = local.s8s_spark_sphs_nm
}

output "UMSA_FQN" {
  value = local.umsa_fqn
}

/******************************************
DONE
******************************************/
