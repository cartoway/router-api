# Build

FROM maven:3.9.5-eclipse-temurin-21 AS build

ARG GRAPHHOPPER_VERSION
ENV GRAPHHOPPER_VERSION ${GRAPHHOPPER_VERSION:-DijkstraOneToManyMatrixCalculator}

RUN git clone --depth 1 --branch ${GRAPHHOPPER_VERSION} https://github.com/cartoway/graphhopper.git
RUN cd graphhopper && \
    mvn clean install -DskipTests


# Runtime

FROM eclipse-temurin:21

RUN apt update && \
    apt install -y --no-install-recommends \
        osmium-tool \
        curl

RUN mkdir /opt/app
WORKDIR /opt/app
COPY --from=build /graphhopper/web/target/graphhopper*.jar ./graphhopper.jar

COPY build.sh /usr/bin/build.sh
COPY start.sh /usr/bin/start.sh

COPY config.yaml config.yaml

CMD [ "/usr/bin/start.sh" ]
EXPOSE 8989

HEALTHCHECK \
    --start-interval=5s \
    --start-period=120s \
    --interval=30s \
    --timeout=20s \
    --retries=5 \
    CMD curl -f http://127.0.0.1:8989/health || exit 1
