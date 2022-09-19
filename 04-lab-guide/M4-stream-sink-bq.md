# About

This module demonstrates (embarassingly) basic integration from Kafka to BigQuery using Apache Spark connectors for Kafka and BigQuery. Such an integration is ideal if you want to consume from Kafka and into BigQuery, but dont have a low latency requirement.

## 1. Variables
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
KAFKA_CONNECTOR_JAR_GCS_URI="gs://s8s-spark-jars-bucket-541847919356/spark-sql-kafka-0-10_2.12-3.1.2.jar"
BQ_CONNECTOR_JAR_GCS_URI="gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.22.2.jar"
YOUR_GCP_REGION="us-central1"
KAFKA_BOOTSTRAP_SERVERS="YOUR_KAFKA_BOOTSTRAP_SERVERS"
KAFKA_API_KEY="YOUR_KAFKA_API_KEY" 
KAFKA_API_SECRET="YOUR_KAFKA_API_SECRET"


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
