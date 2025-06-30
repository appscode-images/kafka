# Build cruise control image to get the metrics reporter jar file
FROM eclipse-temurin:21-jdk AS cruise_control
ARG CC_VERSION

# Fetch Cruise-Control binary
# https://github.com/linkedin/cruise-control/releases contains all the kafka release binary
RUN set -eux \
    && apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends ca-certificates wget git \
    && wget -O /opt/cc.tar.gz https://github.com/linkedin/cruise-control/archive/refs/tags/${CC_VERSION}.tar.gz

# Extract
RUN set -eux \
	&& cd /opt \
	&& tar xzvf cc.tar.gz \
	&& mv /opt/cruise-control-* /opt/cruise-control \
    && rm cc.tar.gz

WORKDIR /opt/cruise-control

### Setup git user and init repo, otherwise build gradle will fail
RUN set -eux \
	&& git config --global user.email root@localhost \
	&& git config --global user.name root \
	&& git init \
	&& git add . \
	&& git commit -m "Init local repo." \
	&& git tag -a ${CC_VERSION} -m "Init local version."

### Setup git user and init repo ###
RUN set -eux \
    && ./gradlew clean \
    && ./gradlew jar :cruise-control-metric-reporter:jar

# Build kafka jsa files
# This part is used from kafka official docker image
FROM eclipse-temurin:21-jre-alpine AS build-jsa

USER root

# Get kafka from https://archive.apache.org/dist/kafka and pass the url through build arguments
ARG KAFKA_URL

COPY jsa_start.sh /opt/kafka/jsa_start.sh

RUN set -eux ; \
    apk update ; \
    apk upgrade ; \
    apk add --no-cache wget gcompat gpg gpg-agent procps bash; \
    mkdir -p /opt/kafka; \
    wget -nv -O kafka.tgz "$KAFKA_URL"; \
    wget -nv -O kafka.tgz.asc "$KAFKA_URL.asc"; \
    tar xfz kafka.tgz -C /opt/kafka --strip-components 1; \
    wget -nv -O KEYS https://downloads.apache.org/kafka/KEYS; \
    gpg --import KEYS; \
    gpg --batch --verify kafka.tgz.asc kafka.tgz

# Generate jsa files using dynamic CDS for kafka server start command and kafka storage format command
RUN /opt/kafka/jsa_start.sh

FROM eclipse-temurin:21-jre

ARG KAFKA_VERSION
ARG SCALA_VERSION
ARG KAFKA_URL
ARG CC_VERSION
ARG TARGETARCH
ENV HOME=/opt/kafka
ENV PATH=${PATH}:${HOME}/bin

LABEL name="kafka" version=${KAFKA_VERSION}
LABEL org.opencontainers.image.source=https://github.com/appscode-images/kafka

# Install dependencies
# Create a non-root user with uid 1001
# Download and extract Kafka from the provided KAFKA_URL
# Set the home directory to /opt/kafka
# Install kafkactl from deviceinsight/kafkactl
# Remove unnecessary directories and files
# Clean up apt cache and set permissions for the kafka user
# Set permissions for the home directory to allow group access
# OpenShifter requires the user to be in group 0 (root) to allow access to the mounted volumes
RUN apt-get update && apt-get upgrade -y ; \
    apt-get install -y wget nano ; \
    mkdir -p ${HOME}; \
    groupadd -r -g 1001 kafka; \
    useradd -m -d $HOME -s /bin/bash -u 1001 -r -g kafka kafka ; \
    wget -nv -O /tmp/kafka.tgz ${KAFKA_URL}; \
    tar xfz /tmp/kafka.tgz -C ${HOME} --strip-components 1; \
    rm /tmp/kafka.tgz; \
    rm -rf ${HOME}/bin/windows ${HOME}/site-docs ; \
    latest_version=$(curl -s https://api.github.com/repos/deviceinsight/kafkactl/releases/latest | grep "tag_name" | cut -d '"' -f 4 | sed 's/^v//') ; \
    curl -LO "https://github.com/deviceinsight/kafkactl/releases/download/v${latest_version}/kafkactl_${latest_version}_linux_${TARGETARCH}.deb" ; \
    dpkg -i kafkactl_${latest_version}_linux_${TARGETARCH}.deb ; \
    rm kafkactl_${latest_version}_linux_${TARGETARCH}.deb ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/log/kafka; \
    chown -R kafka:0 $HOME /var/log/kafka; \
    chmod -R g=u $HOME

# Placing the Cruise Control metric reporter jar into the /opt/kafka/libs/ directory of every Kafka broker
# allows Kafka to find the reporter at runtime
COPY --from=cruise_control /opt/cruise-control/cruise-control-metrics-reporter/build/libs/cruise-control-metrics-reporter-${CC_VERSION}.jar /opt/kafka/libs/cruise-control-metrics-reporter.jar
COPY --from=build-jsa kafka.jsa /opt/kafka/kafka.jsa
COPY --from=build-jsa storage.jsa /opt/kafka/storage.jsa
# Copy scripts directory to the home directory of the container
COPY scripts/ ${HOME}/scripts/

# Add Prometheus JMX exporter agent
COPY ./jmx-exporter-config.yaml /opt/jmx_exporter/jmx-exporter-config.yaml
RUN wget -O /opt/jmx_exporter/jmx_prometheus_javaagent-0.20.0.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar
ENV EXTRA_ARGS="$EXTRA_ARGS -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent-0.20.0.jar=56790:/opt/jmx_exporter/jmx-exporter-config.yaml"
ENV KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1"

USER kafka

WORKDIR $HOME
EXPOSE 9092 9093

ENTRYPOINT ["/opt/kafka/scripts/entrypoint.sh"]
CMD ["/opt/kafka/scripts/setup.sh"]
