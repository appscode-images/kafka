#!/bin/bash

KAFKA_CLUSTER_ID="$(opt/kafka/bin/kafka-storage.sh random-uuid)"
TOPIC="test-topic"

KAFKA_JVM_PERFORMANCE_OPTS="-XX:ArchiveClassesAtExit=storage.jsa" opt/kafka/bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c opt/kafka/config/server.properties

KAFKA_JVM_PERFORMANCE_OPTS="-XX:ArchiveClassesAtExit=kafka.jsa" opt/kafka/bin/kafka-server-start.sh opt/kafka/config/server.properties &

check_timeout() {
    if [ $TIMEOUT -eq 0 ]; then
        echo "Server startup timed out"
        exit 1
    fi
    echo "Check will timeout in $(( TIMEOUT-- )) seconds"
    sleep 1
}

opt/kafka/bin/kafka-topics.sh --create --topic $TOPIC --bootstrap-server localhost:9092
[ $? -eq 0 ] || exit 1

echo "test" | opt/kafka/bin/kafka-console-producer.sh --topic $TOPIC --bootstrap-server localhost:9092
[ $? -eq 0 ] || exit 1

opt/kafka/bin/kafka-console-consumer.sh --topic $TOPIC --from-beginning --bootstrap-server localhost:9092 --max-messages 1 --timeout-ms 20000
[ $? -eq 0 ] || exit 1

opt/kafka/bin/kafka-server-stop.sh

# Wait until jsa file is generated
TIMEOUT=100
until [ -f /kafka.jsa ]
do
    check_timeout
done
