# syntax=docker/dockerfile:1.7
# Use forky to have lua-dbi-duckdb and libduckdb
FROM debian:forky-slim AS builder

ARG OSRM_VERSION
ENV OSRM_VERSION ${OSRM_VERSION:-v26.6.5}

ARG DOCKER_TAG
ARG BUILD_CONCURRENCY
# Pinned vcpkg baseline; keep in sync with vcpkg-configuration.json at the repo root.
ARG VCPKG_COMMIT=c3867e714dd3a51c272826eea77267876517ed99

RUN apt-get update && \
    apt-get -y --no-install-recommends --no-install-suggests install \
        autoconf \
        automake \

        build-essential \
        ca-certificates \
        ccache \
        cmake \
        curl \
        git \
        libtool \
        make \
        ninja-build \
        pkg-config \
        tar \
        unzip \
        zip && \
    rm -rf /var/lib/apt/lists/*

ARG OSRM_REPOSITORY
ENV OSRM_REPOSITORY ${OSRM_REPOSITORY:-https://github.com/Project-OSRM/osrm-backend.git}

RUN git clone ${OSRM_REPOSITORY} --branch ${OSRM_VERSION} src
WORKDIR /src

COPY fixed-zoom-level-simplification.diff .
RUN git apply fixed-zoom-level-simplification.diff

# COPY max_class.diff .
# RUN git apply max_class.diff


# NOTE: VCPKG_ROOT lives outside /opt so the runstage's COPY --from=builder /opt
# /opt doesn't drag the ~5 GB vcpkg tree along.
ENV VCPKG_ROOT=/vcpkg \
    VCPKG_FORCE_SYSTEM_BINARIES=1
RUN mkdir -p ${VCPKG_ROOT} && \
    curl -fsSL https://github.com/microsoft/vcpkg/archive/${VCPKG_COMMIT}.tar.gz | \
    tar -xz --strip-components=1 -C ${VCPKG_ROOT} && \
    ${VCPKG_ROOT}/bootstrap-vcpkg.sh -disableMetrics

WORKDIR /src

# Install manifest deps as their own layer so source-only changes don't
# invalidate the (expensive) vcpkg install. The three cache mounts persist
# across docker builds on the host:
#   - /root/.cache/vcpkg/archives : vcpkg's per-package binary cache (the big win)
#   - /vcpkg/downloads            : upstream tarball cache (avoids re-downloading boost, etc.)
#   - /vcpkg/buildtrees           : partial builds (helps when a single port fails)
# COPY vcpkg.json vcpkg-configuration.json ./
# COPY vcpkg-overlay-ports/ ./vcpkg-overlay-ports/
# TARGETARCH is auto-populated by BuildKit (amd64, arm64).  Map it to the
# matching vcpkg triplet so native ARM64 builds don't fail with a hardcoded
# x64-linux triplet (see docker/build-push-action platforms: linux/arm64).
ARG TARGETARCH
RUN --mount=type=cache,target=/root/.cache/vcpkg/archives,sharing=locked \
    --mount=type=cache,target=/vcpkg/downloads,sharing=locked \
    --mount=type=cache,target=/vcpkg/buildtrees,sharing=locked \
    export VCPKG_DEFAULT_BINARY_CACHE=/root/.cache/vcpkg/archives && \
    mkdir -p build/vcpkg_installed "$VCPKG_DEFAULT_BINARY_CACHE" && \
    case "${TARGETARCH}" in \
        amd64) VCPKG_TRIPLET=x64-linux ;; \
        arm64) VCPKG_TRIPLET=arm64-linux ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    echo "Using vcpkg triplet: ${VCPKG_TRIPLET}" && \
    ${VCPKG_ROOT}/vcpkg install \
        --x-manifest-root=/src \
        --x-install-root=/src/build/vcpkg_installed \
        --triplet=${VCPKG_TRIPLET} \
        --no-print-usage \
        --clean-buildtrees-after-build \
        --clean-packages-after-build

# Now copy the rest of the source tree. This layer is the one that gets
# invalidated by code changes — everything above stays cached.
# COPY . /src

RUN --mount=type=cache,target=/root/.ccache \
    NPROC=${BUILD_CONCURRENCY:-$(nproc)} && \
    export CXXFLAGS="-Wno-array-bounds -Wno-uninitialized -Wno-stringop-overflow" && \
    export CCACHE_DIR=/root/.ccache && \
    export CCACHE_MAXSIZE=2G && \
    export CCACHE_COMPRESSLEVEL=6 && \
    echo "Building OSRM ${DOCKER_TAG}" && \
    git show --format="%H" | head -n1 > /opt/OSRM_GITSHA && \
    echo "Building OSRM gitsha $(cat /opt/OSRM_GITSHA)" && \
    cd build && \
    BUILD_TYPE="Release" && \
    ENABLE_ASSERTIONS="Off" && \
    case ${DOCKER_TAG} in *"-debug"*) BUILD_TYPE="Debug";; esac && \
    case ${DOCKER_TAG} in *"-assertions"*) BUILD_TYPE="RelWithDebInfo" && ENABLE_ASSERTIONS="On";; esac && \
    echo "Building ${BUILD_TYPE} with ENABLE_ASSERTIONS=${ENABLE_ASSERTIONS}" && \
    cmake .. -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DENABLE_ASSERTIONS=${ENABLE_ASSERTIONS} \
        -DENABLE_LTO=On \
        -DCMAKE_EXE_LINKER_FLAGS="-rdynamic" \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache && \
    ninja -j${NPROC} install && \
    ccache -s && \
    # Copy the TBB shared lib out of vcpkg so the runstage image can load it
    # without bringing in the whole vcpkg tree. Boost, expat, bzip2, lua, etc.
    #all link statically under the x64-linux triplet, so only TBB needs
    # runtime shipping. In manifest mode vcpkg installs per-build under
    # build/vcpkg_installed/<triplet>/, not $VCPKG_ROOT/installed/.
    mkdir -p /opt/vcpkg-runtime-libs && \
    find vcpkg_installed -name 'libtbb*.so*' -exec cp -a {} /opt/vcpkg-runtime-libs/ \; && \
    cd ../profiles && \
    cp -r * /opt && \
    strip /usr/local/bin/*

RUN apt update && \
    apt install -y nodejs npm && \
    npm install

# Multistage build to reduce image size - https://docs.docker.com/build/building/multi-stage/#use-multi-stage-builds
# Only the content below ends up in the image, this helps remove /src and vcpkg from the image.
# FROM debian:forky-slim AS runstage

# COPY --from=builder /usr/local /usr/local
# COPY --from=builder /opt /opt
# COPY --from=builder /opt/vcpkg-runtime-libs/ /usr/local/lib/

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libgcc-s1 \
        libstdc++6 && \
    rm -rf /var/lib/apt/lists/* && \
# Add /usr/local/lib to ldconfig so TBB (and any other shared vcpkg libs) load
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
        curl \
        duckdb \
        lua-dbi-duckdb \
        lua-redis \
        osmium-tool \
        wget && \
    duckdb -c "INSTALL spatial"
# Use lua-redis from 5.3, as not available in 5.5
# Manual Lua path. As default path not load from /usr
ENV LUA_PATH="/usr/share/lua/5.5/?.lua;/usr/share/lua/5.3/?.lua"
ENV LUA_CPATH="/usr/lib/x86_64-linux-gnu/lua/5.5/?.so"

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
ENV OSRM_ISOCHRONE_VERSION ${OSRM_ISOCHRONE_VERSION:-26.6.0}

# Install osrm-isochrone-server
RUN echo "{\"name\":\"install\",\"dependencies\":{\"@project-osrm/osrm\":\"file:/src\",\"osrm-isochrone-server\":\"git+https://github.com/cartoway/osrm-isochrone-server.git#v${OSRM_ISOCHRONE_VERSION}\"}}" > package.json && \
    cp /usr/bin/echo /usr/bin/husky && \
    npm install --allow-git=all && \
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
