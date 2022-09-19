from pyspark.sql import SparkSession
from pyspark.sql.types import StructType,StructField, StringType,IntegerType,LongType
from pyspark.sql.functions import col,from_json
from pyspark.sql.functions import *
from pyspark.sql.types import *
import sys

# Arguments
kafkaBrokerAndPortCSV=sys.argv[1]
kafkaAPIKey=sys.argv[2]
kafkaAPISecret=sys.argv[3]
projectID=sys.argv[4]
bqScratchBucket=sys.argv[5]
checkpointGCSUri=sys.argv[6]
bqTableFQN=sys.argv[7]
printArguments=sys.argv[8]

# Variables
kafkaJaasConfig="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"" + kafkaAPIKey + "\" password=\"" + kafkaAPISecret + "\";"

if printArguments:
#{{
    print("Arguments:")
    print(f"kafkaBrokerAndPortCSV={kafkaBrokerAndPortCSV}")
    print(f"kafkaAPIKey={kafkaAPIKey}")
    print(f"kafkaAPISecret={kafkaAPISecret}")
    print(f"projectID={projectID}")
    print(f"bqScratchBucket={bqScratchBucket}")
    print(f"checkpointGCSUri={checkpointGCSUri}")
    print(f"bqTableFQN={bqTableFQN}")
    print("kafka.sasl.jaas.config="+kafkaJaasConfig)
#}}

# Spark session
spark = SparkSession \
        .builder \
        .appName("entries-consumer") \
        .config("spark.streaming.stopGracefullyOnShutdown", "true") \
        .config("spark.sql.streaming.schemaInference", "true") \
        .config("spark.js", "gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.22.2.jar") \
		.config("spark.jars.packages","com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.25.2,org.apache.spark:spark-sql-kafka-0-10_2.12:3.2.1") \
        .getOrCreate()


# Variables
kafkaTopic="entries"

# Read from Kafka topic
promoEntriesDF = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", kafkaBrokerAndPortCSV) \
    .option("subscribe", kafkaTopic) \
    .option("kafka.security.protocol", "SASL_SSL") \
    .option("kafka.sasl.mechanism", "PLAIN") \
    .option("kafka.sasl.jaas.config", kafkaJaasConfig) \
    .option("startingOffsets", "latest") \
    .option("failOnDataLoss", "true") \
    .load()


# Select key and payload and cast as string
kvDF = promoEntriesDF.selectExpr("CAST(key AS STRING) as case_id", "CAST(value AS STRING) as json_payload")

# Define schema for parsing payload
schema = StructType([ 
    StructField("email",StringType(),True), 
    StructField("name",StringType(),True), 
    StructField("entry_time",StringType(),True), 
    StructField("day", StringType(),True), 
    StructField("participationnumber", IntegerType(),True)
  ])

# Parse the JSON payload into individual columns
parsedDF = kvDF.withColumn("jsonData",from_json(col("json_payload"),schema)).select("jsonData.*")

# Rename columns 
finalDF=parsedDF.toDF("email","name","entry_time","day","participation_number")

# Config for use by Spark BQ connector
spark.conf.set("parentProject", projectID)
spark.conf.set("temporaryGcsBucket",bqScratchBucket)

# Process the stream from Kafka into a precreated BigQuery table in append mode
queryDF=finalDF.writeStream.format("bigquery").outputMode("append").option("table", bqTableFQN).option("checkpointLocation", checkpointGCSUri).start()

# Terminate gracefully 
queryDF.awaitTermination()