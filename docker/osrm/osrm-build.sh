#!/bin/bash

set -e

die() {
    echo $*
    exit 1
}

[ -z "${BASENAME}" ] && die "BASENAME environment variable must be provided."
[ -z "${PBF_URLS}" ] && die "PBF_URLS environment variable must be provided."
[ -z "${PROFILE}" ] && die "PROFILE environment variable must be provided."

DATE=$(date +%Y%m%d)

PBF_LATESTS=""
for PBF_URL in $PBF_URLS; do
    PBF_LATEST=$(basename "$PBF_URL")
    PBF_DATE=${PBF_LATEST/latest/$DATE}

    if [[ -s "/srv/osrm/data/${PBF_DATE}" ]]; then
        echo "PBF exists, skip download: ${PBF_DATE}"
    else
        echo "Dowload PBF ${PBF_DATE}"
        curl ${PBF_URL} > /srv/osrm/data/${PBF_DATE}
        rm -fr /srv/osrm/data/${PBF_LATEST}
        ln -s ${PBF_DATE} /srv/osrm/data/${PBF_LATEST}
    fi

    PBF_LATESTS="${PBF_LATESTS} /srv/osrm/data/${PBF_DATE}"
done

BASENAME_PBF_LATEST=${BASENAME}-latest.osm.pbf
BASENAME_PBF_DATE=${BASENAME}-${DATE}.osm.pbf
rm -fr /srv/osrm/data/${BASENAME_PBF_DATE}

if [[ ${PBF_LATESTS:1} =~ " " ]]; then
    osmium merge ${PBF_LATESTS} -o /srv/osrm/data/${BASENAME_PBF_DATE}
else
    ln -s $PBF_LATESTS /srv/osrm/data/${BASENAME_PBF_DATE}
fi

osrm-extract \
    --location-dependent-data /usr/local/share/osrm/data/driving_side.geojson \
    --location-dependent-data /usr/local/share/osrm/data/maxheight.geojson \
    --location-dependent-data /usr/local/share/osrm/data/low_emission_zone.geojson \
    --with-osm-metadata \
    -p ${PROFILE} \
    /srv/osrm/data/${BASENAME_PBF_DATE}

if [ "$ALGORITHM" == "ch" ]; then
    osrm-contract \
        /srv/osrm/data/${BASENAME_PBF_DATE%.osm.pbf}.osrm
else
    osrm-partition \
        /srv/osrm/data/${BASENAME_PBF_DATE%.osm.pbf}.osrm
    osrm-customize \
        /srv/osrm/data/${BASENAME_PBF_DATE%.osm.pbf}.osrm
fi

rm -fr /srv/osrm/data/${BASENAME_PBF_LATEST%.osm.pbf}.osrm.timestamp
ln -s ${BASENAME_PBF_DATE%.osm.pbf}.osrm.timestamp /srv/osrm/data/${BASENAME_PBF_LATEST%.osm.pbf}.osrm.timestamp
