#!/bin/bash

set -e

docker compose run --rm api bash -c "rm -f docker/osrm/data/*"
docker compose run --rm api bash -c "rm -fr docker/graphhopper/data/*"

docker compose --profile=build down
docker compose --profile=build up -d osrm-build-redis

for service in $(docker compose config --services | egrep "osrm-|gh-" | sort); do
    docker compose --profile=build run --rm -T $service build.sh
done

docker compose --profile=build exec osrm-build-redis redis-cli BGSAVE
docker compose --profile=build down osrm-build-redis

docker compose up -d
