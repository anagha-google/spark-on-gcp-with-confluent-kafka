# About

This module demonstrates (embarassingly) basic integration from Kafka to BigQuery using Apache Spark connectors for Kafka and BigQuery. Such an integration is ideal if you want to consume from Kafka and into BigQuery, but dont have a low latency requirement.

### Versions used:
Spark 3.2.1 with Scala 2.12<br>
Kafka connector class: org.apache.spark:spark-sql-kafka-0-10_2.12:3.2.1<br>
BigQuery connector class: com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.22.2<br>
Dataproc Serverless Spark Batches Runtime: 1.0.15<br>

### Jar location:
1. BigQuery connector: gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.22.2.jar
2. Kafka connector: Downloaded from Maven and persisted in GCS - part of Terraform in module 1


### Resources:
1. Dataproc https://cloud.google.com/dataproc-serverless/docs/concepts/versions/spark-runtime-versions
2. Spark and Kafka: https://spark.apache.org/docs/latest/structured-streaming-kafka-integration.html
3. Spark and BigQuery: https://cloud.google.com/dataproc/docs/tutorials/bigquery-connector-spark-example

### Architecture:

![M4](../00-images/M4-00.png) 
<br><br>


 <hr>

## 1. Start the producer

In the prior module we learned to send messages to a Kafka topic. Start the producer in a Cloud shell terminal window as detailed in the prior module, unless its already running.

 <hr>

## 2. Declare variables

If you have the producer running, open a new terminal tab in Cloud shell and paste the variables. Its important to be in the right project, as you run this module.

### 2.1. Your custom variables
Replace the variables below with your region and Kafka details, and paste in Cloud Shell-
```
YOUR_GCP_REGION="us-central1"
KAFKA_BOOTSTRAP_SERVERS="YOUR_KAFKA_BOOTSTRAP_SERVERS"
KAFKA_API_KEY="YOUR_KAFKA_API_KEY" 
KAFKA_API_SECRET="YOUR_KAFKA_API_SECRET"
```
 <hr>
 
### 2.2. Other variables
```
PROJECT_ID=`gcloud config list --format "value(core.project)" 2>/dev/null`
PROJECT_NBR=`gcloud projects describe $PROJECT_ID | grep projectNumber | cut -d':' -f2 |  tr -d "'" | xargs`
SPARK_SERVERLESS_SUBNET=spark-snet
PERSISTENT_HISTORY_SERVER_NM=s8s-sphs-${PROJECT_NBR}
UMSA_FQN=s8s-lab-sa@$PROJECT_ID.iam.gserviceaccount.com
BQ_SCRATCH_BUCKET="s8s-spark-bucket-${PROJECT_NBR}/bq/" 
CHECKPOINT_BUCKET_URI="gs://s8s-spark-checkpoint-bucket-${PROJECT_NBR}/entries_consumer_checkpoint"
CODE_BUCKET_URI="gs://s8s-code-bucket-${PROJECT_NBR}"
BQ_SINK_FQN="marketing_ds.entries"
STREAMING_JOB_NM="entries-kafka-consumer"
KAFKA_CONNECTOR_JAR_GCS_URI="gs://s8s-spark-jars-bucket-${PROJECT_NBR}/spark-sql-kafka-0-10_2.12-3.2.1.jar"
KAFKA_PACKAGE_COORDS="org.apache.spark:spark-sql-kafka-0-10_2.12:3.2.1"
BQ_CONNECTOR_JAR_GCS_URI="gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.22.2.jar"
SPARK_PACKAGE_COORDS="com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.22.2,${KAFKA_PACKAGE_COORDS}"
KAFKA_TOPIC="entries"

```
 <hr>

## 3. Start the Kafka consumer application

```
gcloud dataproc batches submit \
  pyspark $CODE_BUCKET_URI/streaming_consumer_basic.py  \
  --batch $STREAMING_JOB_NM-streaming-${RANDOM} \
  --deps-bucket $CODE_BUCKET_URI \
  --project $PROJECT_ID \
  --region $YOUR_GCP_REGION \
  --subnet $SPARK_SERVERLESS_SUBNET \
  --service-account $UMSA_FQN \
  --history-server-cluster projects/$PROJECT_ID/regions/$YOUR_GCP_REGION/clusters/$PERSISTENT_HISTORY_SERVER_NM \
  --properties "spark.dynamicAllocation.enabled=false,spark.jars.packages=$KAFKA_PACKAGE_COORDS" \
  --jars $BQ_CONNECTOR_JAR_GCS_URI,$KAFKA_CONNECTOR_JAR_GCS_URI \
  --version 1.0.15 \
  -- $KAFKA_BOOTSTRAP_SERVERS $KAFKA_API_KEY $KAFKA_API_SECRET $KAFKA_TOPIC $PROJECT_ID $BQ_SCRATCH_BUCKET $CHECKPOINT_BUCKET_URI $BQ_SINK_FQN true

 ```

 <hr>
 
 ## 4. Monitor the Kafka consumer Spark application in the Dataproc Batches UI on Cloud Console 
 
 <br>
 
 
![DP](../00-images/module4-01.png) 
 <br><br>
 
![DP](../00-images/module4-02.png) 
 <br><br>
 
![DP](../00-images/module4-03.png) 
 <br><br>

 
 <hr>

## 4. Validate entries in BigQuery UI

You should see properly parsed events in BigQuery with this-
```
SELECT * FROM marketing_ds.entries LIMIT 1000
```

![DP](../00-images/module4-04.png) 
 <br><br>

<hr>

## 5. Stop your streaming job

To avoid charges, stop the streaming job. 
1. First hit control+c from the keyboard to exit out of the gcloud command running the streaming job
2. Next, issue a kill from the CLI

```
gcloud dataproc batches cancel  YOUR_SPARK_BATCH_ID_TO_KILL --region=us-central1
```
<br>
E.g. If you have a job called entries-kafka-consumer-streaming-15789 in us-central1, run the below

```
gcloud dataproc batches cancel  entries-kafka-consumer-streaming-15789 --region=us-central1
```

Validate with the command below or on the UI-
```
gcloud dataproc batches list  --region=us-central1
```
 <br><br>

<hr>

This concludes the module, proceed to the [next module](../04-lab-guide/M5-stream-join-sink-bq.md) that covers joining a stream to static data.
