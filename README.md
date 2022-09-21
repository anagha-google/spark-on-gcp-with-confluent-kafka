# Streaming at scale with Spark on GCP and Confluent Kafka

## 1. About 

<hr>

## 2. Architecture

### 2.1. Potential Development Environment

![LP](00-images/LP-Dev.png) 
<br><br>
Note: The above is not covered in the lab. The scripts are pre-created.

### 2.2. Solution Architecture

![LP](00-images/LP-SolArch.png) 
<br><br>

## 3. Use Case

The use case is basic sales and marketing campaign and promotion centric. Assume users logging on to a website and their data streamed to Kafka, and automatically entered into  promotions/lotto for a trip. 

<hr>

## 4. The Data


![LP](00-images/LP-data.png) 
<br><br>

<hr>

## 5. Lab Modules

| Module| Collaborators | 
| -- | :--- | 
| Module 1 | [Provision Google Cloud environment with Terraform](04-lab-guide/M1-gcp-setup.md) | 
| Module 2 | [Provision Confluent Cloud environment](04-lab-guide/M2-confluent-kafka-setup.md) |
| Module 3 | [Publish events to Kafka](04-lab-guide/M3-produce-messages.md) |
| Module 4 | [Spark Strctured Streaming Kafka consumer - basic](04-lab-guide/M4-stream-sink-bq.md) |
| Module 5 | [Spark Strctured Streaming Kafka  consumer - join with static data](04-lab-guide/M5-stream-join-sink-bq.md) |

## 6. Remember...
Shut down/delete resources when done to avoid unnecessary billing.

<hr>

## 7. Credits
| # | Collaborators | Company  | Contribution  | 
| -- | :--- | :--- | :--- |
| 1. | Anagha Khanolkar | Google Cloud | Author of Spark application |
| 2. | Elena Cuevas | Confluent  | Lab vision & Kafka producer code |

<hr>

## 8. Contributions 
Community contribution to improve the lab is very much appreciated. <br>

<hr>

## 9. Getting Help
If you have any questions or if you found any problems with this repository, please report through GitHub issues.

<hr>

