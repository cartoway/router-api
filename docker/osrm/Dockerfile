ARG OSRM_VERSION
FROM ghcr.io/project-osrm/osrm-backend:${OSRM_VERSION:-v5.27.1}

VOLUME /srv/osrm/data

RUN apt-get update && \
    apt-get install -y runit nodejs npm

# Isochrone part
################

ARG OSRM_ISOCHRONE_VERSION
ENV OSRM_ISOCHRONE_VERSION ${OSRM_ISOCHRONE_VERSION:-5.12.1}

# Install osrm-isochrone-server
RUN echo "{\"dependencies\":{\"osrm\":\"file:////osrm-backend\",\"osrm-isochrone-server\":\"git+https://github.com/Mapotempo/osrm-isochrone-server.git#v${OSRM_ISOCHRONE_VERSION}\"}}" > package.json && \
    npm install

# Services part
###############

# Copy service files

COPY service/routed/run /etc/service/routed/run
# COPY service/routed/log/run /etc/service/routed/log/run

COPY service/isochrone/run /etc/service/isochrone/run
# COPY service/isochrone/log/run /etc/service/isochrone/log/run

# Copy startup and load scripts

COPY osrm-start.sh /usr/bin/osrm-start.sh
COPY osrm-load.sh /usr/bin/osrm-load.sh

ENV NODE_CONFIG "{ \"maxspeed\": 115 }"
ENV PROFILE ""
ENV REGION ""

# Define entry point
CMD [ "/usr/bin/osrm-start.sh" ]
