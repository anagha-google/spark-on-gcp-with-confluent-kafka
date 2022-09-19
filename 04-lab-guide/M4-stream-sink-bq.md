# About

This module demonstrates (embarassingly) basic integration from Kafka to BigQuery using Apache Spark connectors for Kafka and BigQuery. Such an integration is ideal if you want to consume from Kafka and into BigQuery, but dont have a low latency requirement.

## 1. Start the producer

In the prior module we learned to send messages to a Kafka topic. Start the producer as detailed in the prior module, unless its already running.

## 2. Declare variables
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
KAFKA_CONNECTOR_JAR_GCS_URI="gs://s8s-spark-jars-bucket-541847919356/spark-sql-kafka-0-10_2.12-3.2.1.jar"
BQ_CONNECTOR_JAR_GCS_URI="gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.22.2.jar"
YOUR_GCP_REGION="us-central1"
KAFKA_BOOTSTRAP_SERVERS="YOUR_KAFKA_BOOTSTRAP_SERVERS"
KAFKA_API_KEY="YOUR_KAFKA_API_KEY" 
KAFKA_API_SECRET="YOUR_KAFKA_API_SECRET"
```

## 3. Start the consumer
```
gcloud dataproc batches submit \
  pyspark --batch $STREAMING_JOB_NM-streaming-${RANDOM} \
  $CODE_BUCKET_URI/entries-consumer.py  \
  --deps-bucket $CODE_BUCKET_URI \
  --project $PROJECT_ID \
  --region $YOUR_GCP_REGION \
  --subnet $SPARK_SERVERLESS_SUBNET \
  --service-account $UMSA_FQN \
  --history-server-cluster projects/$PROJECT_ID/regions/$YOUR_GCP_REGION/clusters/$PERSISTENT_HISTORY_SERVER_NM \
  --jars "${KAFKA_CONNECTOR_JAR_GCS_URI},${BQ_CONNECTOR_JAR_GCS_URI}" \
  --properties "spark.jars.packages=org.apache.spark:spark-streaming-kafka-0-10_2.13:3.1.2"
  -- $KAFKA_BOOTSTRAP_SERVERS $KAFKA_API_KEY $KAFKA_API_SECRET $PROJECT_ID $BQ_SCRATCH_BUCKET $CHECKPOINT_BUCKET_URI $BQ_SINK_FQN 
 ```
 
 <hr>

## 4. Validate entries in BigQuery UI

You should see properly parsed events in BigQuery-
```
SELECT * FROM marketing_ds.entries LIMIT 1000
```

<hr>

## 5. Stop your streaming job

To avoid charges, stop the streaming job. 
1. First hit control+c from the keyboard to exit out of the gcloud command running the streaming job
2. Next, issue a kill from the CLI
<br>
E.g. If you have a job called entries-kafka-consumer-streaming-15789 in us-central1, run the below
```
gcloud dataproc batches cancel  entries-kafka-consumer-streaming-15789 --region=us-central1
```

Validate with the command below or on the UI-
```
gcloud dataproc batches list  --region=us-central1
```
<hr>
This concludes the module, proceed to the next module that covers joining a stream to static data.
