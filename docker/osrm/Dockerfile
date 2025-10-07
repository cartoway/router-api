# Modified from Docker file from OSRM to use Lua 5.3 in place of 5.4
# Beacause lua-sql-postgres not capataible with lua-redis Lua 5.4 in debian:bullseye
# https://github.com/Project-OSRM/osrm-backend/blob/master/docker/Dockerfile-debian
FROM debian:bookworm-slim AS builder
ARG DOCKER_TAG
ARG BUILD_CONCURRENCY

ARG OSRM_VERSION
ENV OSRM_VERSION ${OSRM_VERSION:-v6.0.0}

RUN mkdir -p /src /opt && \
    apt-get update && \
    apt-get -y --no-install-recommends --no-install-suggests install \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        git \
        libboost1.81-all-dev \
        libbz2-dev \
        liblua5.3-dev \
        libtbb-dev \
        libxml2-dev \
        libzip-dev \
        lua5.3 \
        make \
        npm \
        pkg-config

ARG OSRM_REPOSITORY
ENV OSRM_REPOSITORY ${OSRM_REPOSITORY:-https://github.com/Project-OSRM/osrm-backend.git}

RUN git clone ${OSRM_REPOSITORY} --branch ${OSRM_VERSION} src
WORKDIR /src

COPY fixed-zoom-level-simplification.diff .
RUN git apply fixed-zoom-level-simplification.diff

RUN npm install cmake-js

# RUN NPROC=${BUILD_CONCURRENCY:-$(nproc)} && \
RUN NPROC=1 && \
    export CXXFLAGS="-Wno-array-bounds -Wno-uninitialized -Wno-stringop-overflow" && \
    echo "Building OSRM ${DOCKER_TAG}" && \
    git show --format="%H" | head -n1 > /opt/OSRM_GITSHA && \
    echo "Building OSRM gitsha $(cat /opt/OSRM_GITSHA)" && \
    mkdir -p build && \
    cd build && \
    BUILD_TYPE="Release" && \
    ENABLE_ASSERTIONS="Off" && \
    case ${DOCKER_TAG} in *"-debug"*) BUILD_TYPE="Debug";; esac && \
    case ${DOCKER_TAG} in *"-assertions"*) BUILD_TYPE="RelWithDebInfo" && ENABLE_ASSERTIONS="On";; esac && \
    echo "Building ${BUILD_TYPE} with ENABLE_ASSERTIONS=${ENABLE_ASSERTIONS}" && \
    cmake .. -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DENABLE_ASSERTIONS=${ENABLE_ASSERTIONS} -DENABLE_LTO=On -DENABLE_NODE_BINDINGS=On && \
    make -j${NPROC} install && \
    cd ../profiles && \
    cp -r * /opt && \
    strip /usr/local/bin/*

# Multistage build to reduce image size - https://docs.docker.com/build/building/multi-stage/#use-multi-stage-builds
# Only the content below ends up in the image, this helps remove /src from the image (which is large)
# FROM debian:bookworm-slim AS runstage

# COPY --from=builder /usr/local /usr/local
# COPY --from=builder /opt /opt

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        expat \
        libboost-date-time1.81.0 \
        libboost-iostreams1.81.0 \
        libboost-program-options1.81.0 \
        libboost-thread1.81.0 \
        liblua5.3-0 \
        libtbb12 && \
    rm -rf /var/lib/apt/lists/* && \
# Add /usr/local/lib to ldconfig to allow loading libraries from there
    ldconfig /usr/local/lib

RUN /usr/local/bin/osrm-extract --help && \
    /usr/local/bin/osrm-routed --help && \
    /usr/local/bin/osrm-contract --help && \
    /usr/local/bin/osrm-partition --help && \
    /usr/local/bin/osrm-customize --help

WORKDIR /opt

EXPOSE 5000

############ END of Dockerfile from OSRM

# ARG OSRM_VERSION
# FROM ghcr.io/project-osrm/osrm-backend:${OSRM_VERSION:-v6.0.0}

VOLUME /srv/osrm/data

# Build
RUN apt update && \
    apt install -y --no-install-recommends \
        lua-sql-postgres \
        lua-redis \
        osmium-tool \
        wget \
        curl

# Runtime
RUN apt update && \
    apt install -y runit nodejs npm curl

HEALTHCHECK \
    --start-interval=5s \
    --start-period=120s \
    --interval=30s \
    --timeout=20s \
    --retries=5 \
    CMD curl -f http://127.0.0.1:5000/nearest/v1/_/0,0.json || exit 1

# Isochrone part
################

ARG OSRM_ISOCHRONE_VERSION
ENV OSRM_ISOCHRONE_VERSION ${OSRM_ISOCHRONE_VERSION:-6.0.0}

# Install osrm-isochrone-server
RUN echo "{\"name\":\"install\",\"dependencies\":{\"@project-osrm/osrm\":\"file:/src\",\"osrm-isochrone-server\":\"git+https://github.com/cartoway/osrm-isochrone-server.git#v${OSRM_ISOCHRONE_VERSION}\"}}" > package.json && \
    npm install --legacy-peer-deps && \
    npm link /src

# Services part
###############

# Copy service files

COPY service/routed/run /etc/service/routed/run
# COPY service/routed/log/run /etc/service/routed/log/run

COPY service/isochrone/run /etc/service/isochrone/run
# COPY service/isochrone/log/run /etc/service/isochrone/log/run

# Copy startup and load scripts

COPY start.sh /usr/bin/start.sh
COPY load.sh /usr/bin/load.sh
COPY build.sh /usr/bin/build.sh

ENV NODE_CONFIG "{ \"maxspeed\": 115 }"
ENV PROFILE ""
ENV REGION ""

CMD [ "/usr/bin/start.sh" ]
