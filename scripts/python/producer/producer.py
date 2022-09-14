#!/usr/bin/env python
#
# Copyright 2020 Confluent Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# =============================================================================
#
# Produce messages to Confluent Cloud
# Using Confluent Python Client for Apache Kafka
#
# =============================================================================

from confluent_kafka import Producer, KafkaError
import json
import ccloud_lib
import time
import names
import random
from datetime import date

if __name__ == '__main__':

    domains = [ "hotmail.com", "gmail.com", "aol.com", "mail.com" , "mail.kz", "yahoo.com"]


    # Read arguments and configurations and initialize
    args = ccloud_lib.parse_args()
    config_file = args.config_file
    topic = args.topic
    max_messages = int(args.messages)
    conf = ccloud_lib.read_ccloud_config(config_file)

    # Create Producer instance
    producer_conf = ccloud_lib.pop_schema_registry_params_from_config(conf)
    producer = Producer(producer_conf)

    # Create topic if needed
    ccloud_lib.create_topic(conf, topic)
    
    def read_daily_participants():
        daily_participants = {}
        with open("data.out") as fh:
            for line in fh:
                line = line.strip()
                if len(line) != 0 and line[0] != "#":
                    day, offset = line.strip().split(' ', 1)
                    daily_participants[day] = offset.strip()
        return daily_participants

    def get_last_participant(participants):
        if today in participants:
            return participants[today]
        else:
            write_daily_participants(today,0)
            return 0

    def write_daily_participants(date,offset):
        out = open("data.out", "w")
        print(date+" "+str(offset),file=out)
        out.close()


    def random_email(name):
        email = ''.join(c.lower() for c in name if not c.isspace())
        email += str(random.randint(0,99))
        email += '@'+domains[random.randint( 0, len(domains)-1)]
        return (email)



    # Optional per-message on_delivery handler (triggered by poll() or flush())
    # when a message has been successfully delivered or
    # permanently failed delivery (after retries).
    def acked(err, msg):
        global delivered_records
        """Delivery report handler called on
        successful or failed delivery of message
        """
        if err is not None:
            print("Failed to deliver message: {}".format(err))
        else:
            delivered_records += 1
            print("Produced record to topic {} partition [{}] @ offset {}"
                  .format(msg.topic(), msg.partition(), msg.offset()))


    delivered_records = 0
    today = date.today().strftime('%Y%m%d')
    lastparticipant = get_last_participant(read_daily_participants())



    for n in range(max_messages):
        rand_name = names.get_full_name()
        participationnumber = int(lastparticipant) + n
        record_key = today+'_'+str(participationnumber)
        record_value = json.dumps({'email': random_email(rand_name), 'name': rand_name, 'entry_time': time.time(), 'day': today, 'participationnumber': participationnumber})
        print("Producing record: {}\t{}".format(record_key, record_value))
        producer.produce(topic, key=record_key, value=record_value, on_delivery=acked)
        # p.poll() serves delivery reports (on_delivery)
        # from previous produce() calls.
        producer.poll(0)


    producer.flush()

    write_daily_participants(today, int(lastparticipant)+delivered_records)
    print("{} messages were produced to topic {}!".format(delivered_records, topic))
