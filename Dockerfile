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
ENV OSM_PBF_URL='http://osm-data.railway.internal:8080/osm/osm-data.pbf'


# Setup the target system with the right user and folders.
RUN echo "ipv6" >> /etc/modules && \
    echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf && \
    apk update && apk add --no-cache bash jq openssl wget bind-tools curl && \
    addgroup -g 1000 ors && \
    mkdir -p /home/ors/logs /home/ors/files /home/ors/graphs /home/ors/elevation_cache && \
    adduser -D -h /home/ors -u 1000 --system -G ors ors && \
    chown -R ors:ors /home/ors && \
    chmod -R 777 /home/ors

# Download Chile OSM file and set up files
RUN mkdir -p /home/ors/files && \
    echo "Intentando descarga con curl..." && \
    curl -v -L --retry 5 --retry-delay 10 --retry-all-errors --retry-max-time 300 ${OSM_PBF_URL} -o /home/ors/files/chile-latest.osm.pbf && \
    chown ors:ors /home/ors/files/chile-latest.osm.pbf

# Copy over the needed bits and pieces from the other stages.
COPY --chown=ors:ors --from=build /tmp/ors/ors-api/target/ors.jar /ors.jar
COPY --chown=ors:ors ./docker-entrypoint.sh /entrypoint.sh
COPY --chown=ors:ors --from=build-go /root/go/bin/yq /bin/yq

# Copy the example config files to the build folder
COPY --chown=ors:ors ./ors-config.yml /example-ors-config.yml
COPY --chown=ors:ors ./ors-config.env /example-ors-config.env

# Rewrite the example config to use the right files in the container
RUN yq -i -p=props -o=props \
    '.ors.engine.profile_default.build.source_file="/home/ors/files/chile-latest.osm.pbf"' \
    /example-ors-config.env && \
    yq -i e '.ors.engine.profile_default.build.source_file = "/home/ors/files/chile-latest.osm.pbf"' \
    /example-ors-config.yml

ENV BUILD_GRAPHS="False"
ENV REBUILD_GRAPHS="False"

WORKDIR /home/ors

# Healthcheck
HEALTHCHECK --interval=3s --timeout=2s CMD ["sh", "-c", "wget --quiet --tries=1 --spider http://localhost:8082/ors/v2/health || exit 1"]

# Start the container
ENTRYPOINT ["/entrypoint.sh"]
