#!/bin/bash

set -e

[ -z "${BASENAME}" ] && die "BASENAME environment variable must be provided."

java \
    -Xmx4g \
    -Ddw.graphhopper.graph.location=/srv/graphhopper/data/${BASENAME}-latest.osm-gh \
    -jar graphhopper.jar \
        server \
        config.yaml
