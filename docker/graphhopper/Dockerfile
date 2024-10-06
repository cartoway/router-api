FROM eclipse-temurin:21

RUN apt update && \
    apt install -y --no-install-recommends \
        osmium-tool \
        curl

ARG GRAPHHOPPER_VERSION
ENV GRAPHHOPPER_VERSION ${GRAPHHOPPER_VERSION:-9.1}

RUN mkdir /opt/app
WORKDIR /opt/app
RUN curl -L https://github.com/graphhopper/graphhopper/releases/download/${GRAPHHOPPER_VERSION}/graphhopper-web-${GRAPHHOPPER_VERSION}.jar > graphhopper.jar

COPY gh-build.sh /usr/bin/gh-build.sh
COPY gh-start.sh /usr/bin/gh-start.sh

COPY config.yaml config.yaml

CMD [ "/usr/bin/gh-start.sh" ]
EXPOSE 8989
