# Image is reused in the workflow builds for master and the latest version
FROM docker.io/maven:3.9.9-amazoncorretto-21-alpine AS build
ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3002
USER root

WORKDIR /tmp/ors

COPY ors-api/pom.xml /tmp/ors/ors-api/pom.xml
COPY ors-engine/pom.xml /tmp/ors/ors-engine/pom.xml
COPY pom.xml /tmp/ors/pom.xml
COPY ors-report-aggregation/pom.xml /tmp/ors/ors-report-aggregation/pom.xml
COPY ors-test-scenarios/pom.xml /tmp/ors/ors-test-scenarios/pom.xml

# Build the project
RUN mvn -pl '!ors-test-scenarios,!ors-report-aggregation' -q dependency:go-offline

COPY ors-api /tmp/ors/ors-api
COPY ors-engine /tmp/ors/ors-engine

# Build the project
RUN mvn -pl '!ors-test-scenarios,!ors-report-aggregation' \
    -q clean package -DskipTests -Dmaven.test.skip=true

FROM docker.io/maven:3.9.9-amazoncorretto-21-alpine AS build-go
RUN apk update && apk add --no-cache go && \
    GO111MODULE=on go install github.com/mikefarah/yq/v4@v4.44.5

# build final image, just copying stuff inside
FROM docker.io/amazoncorretto:21.0.4-alpine3.20 AS publish

# Set environment variables
ENV ORS_HOME=/home/ors
ENV LANG='en_US' LANGUAGE='en_US' LC_ALL='en_US'
ENV OSM_PBF_URL='https://download.geofabrik.de/south-america/chile-latest.osm.pbf'
ENV FORCE_DOWNLOAD='false'
ENV ORS_CONFIG=/home/ors/ors-config.yml


# Setup the target system with the right user and folders.
RUN echo "ipv6" >> /etc/modules && \
    echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf && \
    apk update && apk add --no-cache bash jq openssl wget bind-tools curl && \
    addgroup -g 1000 ors && \
    mkdir -p /home/ors/logs /home/ors/files /home/ors/graphs /home/ors/elevation_cache && \
    adduser -D -h /home/ors -u 1000 --system -G ors ors && \
    chown -R ors:ors /home/ors && \
    chmod -R 777 /home/ors
# Create directories for OSM files
RUN mkdir -p /home/ors/files && \
    chown -R ors:ors /home/ors/files


# Copy over the needed bits and pieces from the other stages.
COPY --chown=ors:ors --from=build /tmp/ors/ors-api/target/ors.jar /ors.jar
COPY --chown=ors:ors ./docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY --chown=ors:ors --from=build-go /root/go/bin/yq /bin/yq

# Copy and configure the config files
COPY --chown=ors:ors ./ors-config.yml /home/ors/ors-config.yml
COPY --chown=ors:ors ./ors-config.env /home/ors/ors-config.env

# Rewrite the config to use the right files in the container
RUN yq -i -p=props -o=props \
    '.ors.engine.profile_default.build.source_file="/home/ors/files/chile-latest.osm.pbf"' \
    /home/ors/ors-config.env && \
    yq -i e '.ors.engine.profile_default.build.source_file = "/home/ors/files/chile-latest.osm.pbf"' \
    /home/ors/ors-config.yml && \
    chmod 644 /home/ors/ors-config.yml /home/ors/ors-config.env

ENV BUILD_GRAPHS="False"
ENV REBUILD_GRAPHS="False"

WORKDIR /home/ors

# Healthcheck
HEALTHCHECK --interval=3s --timeout=2s CMD ["sh", "-c", "wget --quiet --tries=1 --spider http://localhost:8082/ors/v2/health || exit 1"]

# Start the container
ENTRYPOINT ["/entrypoint.sh"]
