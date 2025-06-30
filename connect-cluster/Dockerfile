FROM eclipse-temurin:21-jre

ARG KAFKA_VERSION
ARG SCALA_VERSION
ARG KAFKA_REGISTRY
ARG KAFKA_URL
ARG JMX_PROMETHEUS_AGENT_VERSION=0.20.0
ENV HOME=/opt/kafka
ENV PATH=${PATH}:${HOME}/bin
# This Dockerfile is used to build a Connect Cluster image with the specified Kafka version.
# It sets the image name and version as labels and specifies the source code repository.
LABEL name="connect-cluster" version=${KAFKA_VERSION}
LABEL org.opencontainers.image.source=https://github.com/kubedb/kafka-docker

# Install dependencies
# Create a non-root user with uid 1001
# Download and extract Kafka from the provided KAFKA_URL
# Set the home directory to /opt/kafka
# Remove unnecessary directories and files
# Clean up apt cache and set permissions for the kafka user
# Set permissions for the home directory to allow group access
# For OpenShift, we need to set the group to 0 and the directory permissions to g=u
RUN apt-get update && apt-get upgrade -y ; \
    apt-get install -y wget nano ; \
    mkdir -p ${HOME}; \
    groupadd -r -g 1001 kafka; \
    useradd -m -d $HOME -s /bin/bash -u 1001 -r -g kafka kafka ; \
    wget -O /tmp/kafka.tgz ${KAFKA_URL}; \
    tar xfz /tmp/kafka.tgz -C ${HOME} --strip-components 1; \
    rm /tmp/kafka.tgz; \
    rm -rf /opt/kafka/bin/windows /opt/kafka/site-docs; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chown -R kafka:0 ${HOME}; \
    chmod -R g=u ${HOME}

# Copy the JAAS configuration file to the config directory of Kafka
COPY ./kafka_connect_jaas.conf /opt/kafka/config

# Add Prometheus JMX exporter agent
COPY ./jmx-exporter-config.yaml /opt/jmx_exporter/jmx-exporter-config.yaml
RUN wget -O /opt/jmx_exporter/jmx_prometheus_javaagent-${JMX_PROMETHEUS_AGENT_VERSION}.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_PROMETHEUS_AGENT_VERSION}/jmx_prometheus_javaagent-${JMX_PROMETHEUS_AGENT_VERSION}.jar
ENV EXTRA_ARGS="$EXTRA_ARGS -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent-${JMX_PROMETHEUS_AGENT_VERSION}.jar=56790:/opt/jmx_exporter/jmx-exporter-config.yaml"
ENV KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1"
# Copy scripts directory to the home directory of the container
COPY scripts/ ${HOME}/scripts/
# Set the user to kafka
USER kafka
# Set the working directory to the home directory of the kafka user
WORKDIR $HOME
# Expose port 8083
EXPOSE 8083
# Set the entrypoint to /opt/kafka/scripts/entrypoint.sh
ENTRYPOINT ["/opt/kafka/scripts/entrypoint.sh"]