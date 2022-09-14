# About 

This module covers how to create your Confluent Cloud environmnent, cluster and topic for use in the lab.

## 1. Provision Confluent Cloud from the GCP marketplace
https://console.cloud.google.com/marketplace/product/endpoints/payg-prod.gcpmarketplace.confluent.cloud

1. Search for Confluent Cloud

![CC](../00-images/cc1.png) 

2. Click "SUBSCRIBE" button

3. Review and agree to the terms (if you agree) and click "SUBSCRIBE"

![CC](../00-images/cc2.png)  

4. The "order request" will be sent to Confluent and then click "GO TO PRODUCT PAGE"
![CC](../00-images/cc3.png)  

5. Now click the "ENABLE" button

![CC](../00-images/cc4.png)  

6. Click the "MANAGE VIA CONFLUENT" button

![CC](../00-images/cc5.png)  

7. Signup for a new Confluent Cloud account
If you are a GCP CE, use your @google.com address and not Argolis email.

![CC](../00-images/cc6.png)  

8. Check your email for the verification link and click it to login to Confluent Cloud

![CC](../00-images/cc6.png)  

<br><br>

![CC](../00-images/cc7.png)  



## N. Install Confluent Cloud client on gcloud

### N1. Download and install the latest version in the default directory, ./bin:
```
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
```

### N2. Set the PATH environment to include the directory that you downloaded the CLI binaries, ./bin:
```
export PATH=$(pwd)/bin:$PATH
```

### N3. Add this entry into your .bashrc:
```
export CONFLUENT_HOME=~/bin
export PATH=$CONFLUENT_HOME/bin:$PATH
```

### N4. Check Confluent version in cloud shell:
```
confluent version
```

Author's output
```
confluent - Confluent CLI

Version:     v2.25.0
Git Ref:     ffd9f35c
Build Date:  2022-09-14T00:47:25Z
Go Version:  go1.18.1 (linux/amd64)
Development: false
```

### N4. Login to the Confluent CLI:
```
confluent login
```

## O. Create Confluent environment and cluster

### O.1. Create environment
```
confluent environment create gaia-env-dev
```

Authors output:
```
+------+--------------+
| ID   | env-rrg1v9   |
| Name | gaia-env-dev |
+------+--------------+
```

Other confluent environment commands are available here-
https://docs.confluent.io/confluent-cli/current/command-reference/environment/index.html

### O.2. Create cluster




