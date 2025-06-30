# --------------- Builder stage ---------------
FROM eclipse-temurin:21-jdk AS cruisecontrol

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

# Build
RUN set -eux \
    && ./gradlew clean \
    && ./gradlew jar \
    && ./gradlew jar copyDependantLibs


FROM node:20.11.1-buster as cruisecontrol_ui

ARG CCUI_VERSION

# Fetch Cruise-Control-UI binary
# https://github.com/linkedin/cruise-control-ui/releases contains all the kafka release binary
RUN set -eux \
    && wget -O /opt/ccui.tar.gz https://github.com/linkedin/cruise-control-ui/archive/refs/tags/v${CCUI_VERSION}.tar.gz

# Extract
RUN set -eux \
	&& cd /opt \
	&& tar xzvf ccui.tar.gz \
	&& mv /opt/cruise-control-ui-* /opt/cruise-control-ui \
    && rm ccui.tar.gz

# Build
RUN set -eux \
    && cd /opt/cruise-control-ui \
    && npm install \
    && npm run build

# --------------- Final stage ---------------
FROM eclipse-temurin:21-jre

ENV HOME=/opt/cruise-control
WORKDIR $HOME

COPY --from=cruisecontrol /opt/cruise-control/cruise-control/build/libs/* /opt/cruise-control/cruise-control/build/libs/
COPY --from=cruisecontrol /opt/cruise-control/config /opt/cruise-control/config
COPY --from=cruisecontrol /opt/cruise-control/*.sh /opt/cruise-control/
COPY --from=cruisecontrol /opt/cruise-control/cruise-control/build/dependant-libs /opt/cruise-control/cruise-control/build/dependant-libs
COPY --from=cruisecontrol_ui /opt/cruise-control-ui/dist /opt/cruise-control/cruise-control-ui/dist

COPY /scripts/entrypoint.sh /opt/cruise-control/config/entrypoint.sh
COPY /scripts/merge_custom_config.sh /opt/cruise-control/config/merge_custom_config.sh

# Update dependencies and create a non-root user
# Add permissions for the home directory
# Set the group to 0 and the directory permissions to g=u for OpenShift compatibility
# Clean up apt cache and remove unnecessary files
# add a+rw permissions to the home directory to ensure Cruise Control writable for logs
RUN apt-get update && apt-get upgrade -y; \
    groupadd -r -g 1001 cruise-control; \
    useradd -m -d $HOME -s /bin/bash -u 1001 -r -g cruise-control cruise-control; \
    chown -R cruise-control:0 $HOME; \
    chmod -R g=u $HOME; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chmod a+rw -R .

# Set the user to cruise-control
USER cruise-control

EXPOSE 9090
ENTRYPOINT ["/opt/cruise-control/config/entrypoint.sh"]
