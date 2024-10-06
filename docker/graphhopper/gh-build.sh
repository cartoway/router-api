#!/bin/bash

set -e

die() {
    echo $*
    exit 1
}

[ -z "${BASENAME}" ] && die "BASENAME environment variable must be provided."
[ -z "${PBF_URLS}" ] && die "PBF_URLS environment variable must be provided."

DATE=$(date +%Y%m%d)

PBF_LATESTS=""
for PBF_URL in $PBF_URLS; do
    PBF_LATEST=$(basename "$PBF_URL")
    PBF_DATE=${PBF_LATEST/latest/$DATE}

    if [[ -s "/srv/graphhopper/data/${PBF_DATE}" ]]; then
        echo "PBF exists, skip download: ${PBF_DATE}"
    else
        echo "Dowload PBF ${PBF_DATE}"
        curl -L ${PBF_URL} > /srv/graphhopper/data/${PBF_DATE}
        rm -fr /srv/graphhopper/data/${PBF_LATEST}
        ln -s ${PBF_DATE} /srv/graphhopper/data/${PBF_LATEST}
    fi

    PBF_LATESTS="${PBF_LATESTS} /srv/graphhopper/data/${PBF_DATE}"
done

BASENAME_PBF_LATEST=${BASENAME}-latest.osm.pbf
BASENAME_PBF_DATE=${BASENAME}-${DATE}.osm.pbf
rm -fr /srv/graphhopper/data/${BASENAME_PBF_DATE}

if [[ ${PBF_LATESTS:1} =~ " " ]]; then
    osmium merge ${PBF_LATESTS} -o /srv/graphhopper/data/${BASENAME_PBF_DATE}
else
    ln -s $PBF_LATESTS /srv/graphhopper/data/${BASENAME_PBF_DATE}
fi

java \
    -Ddw.graphhopper.datareader.file=/srv/graphhopper/data/${BASENAME_PBF_DATE} \
    -Ddw.graphhopper.graph.location=/srv/graphhopper/data/${BASENAME_PBF_DATE%.osm.pbf}.osm-gh \
    -jar graphhopper.jar \
        import \
        config.yaml

rm -fr /srv/graphhopper/data/${BASENAME_PBF_LATEST%.osm.pbf}.osm-gh
ln -s ${BASENAME_PBF_DATE%.osm.pbf}.osm-gh /srv/graphhopper/data/${BASENAME_PBF_LATEST%.osm.pbf}.osm-gh
