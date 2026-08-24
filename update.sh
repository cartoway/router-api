#!/bin/bash

set -e

docker compose down

rm -f docker/osrm/data/*
rm -fr docker/graphhopper/data/*

for service in $(docker compose config --services | egrep "osrm-|gh-"); do
    docker compose --profile=build run --rm -T $service build.sh
done

docker compose --profile=build stop osrm-build-redis

docker compose up -d
