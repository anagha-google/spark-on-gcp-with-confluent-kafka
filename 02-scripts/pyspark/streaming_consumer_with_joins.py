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
kafkaTopicNm=sys.argv[4]
projectID=sys.argv[5]
bqScratchBucket=sys.argv[6]
checkpointGCSUri=sys.argv[7]
bqPromotionsTableFQN=sys.argv[8]
bqWinnersTableFQN=sys.argv[9]
printArguments=sys.argv[10]

# Variables
kafkaJaasConfig="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"" + kafkaAPIKey + "\" password=\"" + kafkaAPISecret + "\";"

if printArguments:
#{{
    print("Arguments:")
    print(f"kafkaBrokerAndPortCSV={kafkaBrokerAndPortCSV}")
    print(f"kafkaAPIKey={kafkaAPIKey}")
    print(f"kafkaAPISecret={kafkaAPISecret}")
    print(f"kafkaTopicNm={kafkaTopicNm}")
    print(f"projectID={projectID}")
    print(f"bqScratchBucket={bqScratchBucket}")
    print(f"checkpointGCSUri={checkpointGCSUri}")
    print(f"bqPromotionsTableFQN={bqPromotionsTableFQN}")
    print(f"bqWinnersTableFQN={bqWinnersTableFQN}")
    print("kafka.sasl.jaas.config="+kafkaJaasConfig)
#}}

# Spark session
spark = SparkSession \
        .builder \
        .appName("winners-consumer") \
        .config("spark.streaming.stopGracefullyOnShutdown", "true") \
        .config("spark.sql.streaming.schemaInference", "true") \
        .getOrCreate()

# Config for use by Spark BQ connector
spark.conf.set("parentProject", projectID)
spark.conf.set("temporaryGcsBucket",bqScratchBucket)

# Read static source into a dataframe - Promotions data in BigQuery
promotionsStaticDF = spark.read.format("bigquery").option("table",bqPromotionsTableFQN).load()
promotionsStaticDF.show(2)

# Read from Kafka topic
entriesRawStreamingDF = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", kafkaBrokerAndPortCSV) \
    .option("subscribe", kafkaTopicNm) \
    .option("kafka.security.protocol", "SASL_SSL") \
    .option("kafka.sasl.mechanism", "PLAIN") \
    .option("kafka.sasl.jaas.config", kafkaJaasConfig) \
    .option("startingOffsets", "earliest") \
    .option("failOnDataLoss", "true") \
    .load()


# Select key and payload and cast as string
entriesKvStreamingDF = entriesRawStreamingDF.selectExpr("CAST(key AS STRING) as case_id", "CAST(value AS STRING) as json_payload")

# Define schema for parsing payload
schema = StructType([ 
    StructField("email",StringType(),True), 
    StructField("name",StringType(),True), 
    StructField("entry_time",StringType(),True), 
    StructField("day", StringType(),True), 
    StructField("participationnumber", IntegerType(),True)
  ])

# Parse the JSON payload into individual columns
entriesParsedStreamingDF = entriesKvStreamingDF.withColumn("jsonData",from_json(col("json_payload"),schema)).select("jsonData.*")

# Rename columns 
entriesStreamingDF=entriesParsedStreamingDF.toDF("email","name","entry_time","day","participation_number")
entriesStreamingDF.show(2)

# Inner join the stream with the static data to determine winners
joinedDF=entriesStreamingDF.join(promotionsStaticDF, (entriesStreamingDF.day == promotionsStaticDF.day) & (entriesStreamingDF.participation_number == promotionsStaticDF.participation_number),"inner").drop(promotionsStaticDF.participation_number).drop(promotionsStaticDF.day)  
joinedDF.show(2)

# Process the stream joined with static data into a precreated BigQuery table in append mode
queryDF=joinedDF.writeStream.format("bigquery").outputMode("append").option("table", bqWinnersTableFQN).option("checkpointLocation", checkpointGCSUri).start()

# Terminate gracefully 
queryDF.awaitTermination()