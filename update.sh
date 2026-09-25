#!/bin/bash

set -e

docker compose run --rm api bash -c "rm -f docker/osrm/data/*"
docker compose run --rm api bash -c "rm -fr docker/graphhopper/data/*"

docker compose --profile=build down

for service in $(docker compose config --services | egrep "osrm-|gh-"); do
    docker compose --profile=build run --rm -T $service build.sh
done

docker compose --profile=build stop osrm-build-redis

docker compose up -d
