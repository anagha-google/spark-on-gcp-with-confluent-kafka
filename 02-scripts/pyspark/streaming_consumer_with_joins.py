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
bqPromotionsTableFQN=sys.argv[7]
bqWinnersTableFQN=sys.argv[8]
printArguments=sys.argv[9]

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
    print(f"bqPromotionsTableFQN={bqPromotionsTableFQN}")
    print("kafka.sasl.jaas.config="+kafkaJaasConfig)
#}}

# Spark session
spark = SparkSession \
        .builder \
        .appName("entries-consumer") \
        .config("spark.streaming.stopGracefullyOnShutdown", "true") \
        .config("spark.sql.streaming.schemaInference", "true") \
        .getOrCreate()

# Variables
kafkaTopic="entries"

# Config for use by Spark BQ connector
spark.conf.set("parentProject", projectID)
spark.conf.set("temporaryGcsBucket",bqScratchBucket)

# Read static source into a dataframe - Promotions data in BigQuery
promotionsDF = spark.read.format("bigquery").option("table",bqPromotionsTableFQN).load()

# Read from Kafka topic
entriesRawDF = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", kafkaBrokerAndPortCSV) \
    .option("subscribe", kafkaTopic) \
    .option("kafka.security.protocol", "SASL_SSL") \
    .option("kafka.sasl.mechanism", "PLAIN") \
    .option("kafka.sasl.jaas.config", kafkaJaasConfig) \
    .option("startingOffsets", "earliest") \
    .option("failOnDataLoss", "true") \
    .load()


# Select key and payload and cast as string
entriesKvDF = entriesRawDF.selectExpr("CAST(key AS STRING) as case_id", "CAST(value AS STRING) as json_payload")

# Define schema for parsing payload
schema = StructType([ 
    StructField("email",StringType(),True), 
    StructField("name",StringType(),True), 
    StructField("entry_time",StringType(),True), 
    StructField("day", StringType(),True), 
    StructField("participationnumber", IntegerType(),True)
  ])

# Parse the JSON payload into individual columns
entriesParsedDF = entriesKvDF.withColumn("jsonData",from_json(col("json_payload"),schema)).select("jsonData.*")

# Rename columns 
entriesDF=entriesParsedDF.toDF("email","name","entry_time","day","participation_number")

# Inner join the stream with the static data to determine winners
joinedDF=entriesDF.join(promotionsDF, (entriesDF.day == promotionsDF.day) & (entriesDF.participation_number == promotionsDF.participation_number),"inner").drop(promotionsDF.participation_number).drop(promotionsDF.day)  

# Process the stream joined with static data into a precreated BigQuery table in append mode
queryDF=joinedDF.writeStream.format("bigquery").outputMode("append").option("table", bqWinnersTableFQN).option("checkpointLocation", checkpointGCSUri).start()

# Terminate gracefully 
queryDF.awaitTermination()