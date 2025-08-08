# Router API

Offers an unified API for multiple routers based on countries distribution and other parameters like means of transport.
Build in Ruby with a [Grape](https://github.com/intridea/grape) REST [swagger](http://swagger.io/) API.

## API

The API is defined in Swagger format at
http://localhost:8082/0.1/swagger_doc
and can be tested with Swagger-UI
https://petstore.swagger.io/?url=https://localhost:8082/0.1/swagger_doc

### Capability
Retrieve the available modes (eg routers) for APIs by GET request.

```
http://localhost:8082/0.1/capability.json?&api_key=demo
```

Returns JSON:
```json
{
  "route": [
    {
      "mode": "mode1",
      "name": "translation1",
      "area": [
        "Area1", "Area2"
      ]
    }
  ],
  "matrix": [],
  "isoline": []
}
```

### Route
Return the route between list of points using GET request.

For instance, route between Bordeaux, Mérignac and Talence
```
http://localhost:8082/0.1/route.json?api_key=demo&mode=osrm&geometry=true&loc=44.837778,-0.579197,44.844866,-0.656377,44.808047,-0.588598
```

### Routes
Return many routes between list of points using GET request.

For instance, routes between Bordeaux, Mérignac and Mérignac, Talence
```
http://localhost:8082/0.1/routes.json?api_key=demo&mode=osrm&geometry=true&locs=44.837778,-0.579197,44.844866,-0.656377;44.844866,-0.656377,44.808047,-0.588598
```

## Docker

Copy and adjust environments files.
```bash
cp ./config/environments/production.rb ./docker/
cp ./config/access.rb ./docker/
```

Create a `.env` from `.env.template`, and adapt if required.
Enable components in `COMPOSE_FILE` var. Only required for non external engines.

Build docker images
```
docker compose build
```

Launch containers
```
docker compose up -d
```

## Without Docker

Install package containing `ogr2ogr` bin as system package (GDAL).

In `router-api` as root directory:

```
bundle install
```

```
bundler exec puma -v -p 8082 --pidfile 'tmp/server.pid'
```

And in production mode:
```
APP_ENV=production bundle exec puma -v -p 8082 --pidfile 'tmp/server.pid'
```

Available production extra environment variables are:
```
REDIS_HOST=example.com
```

## Backends
### OTP
```
cd docker/otp
./otp-rebuild-all.sh
# OR
./otp-rebuild.sh bordeaux
```

The script will build `bordeaux` graph from `./otp/data/graphs` in `/srv/docker`

### OSRM

Landuses give better estimatid driving speed, but optional.

#### Landuse database from "Corine Land Cover"
Download GeoPackage from [Copernicus](https://land.copernicus.eu/pan-european/corine-land-cover/clc2018?tab=download) into the `landuses` directory. Double unzip.

Convert the data
```bash
ogr2ogr -sql "SELECT * FROM (SELECT CASE CODE_18 WHEN 111 THEN 1 WHEN 112 THEN 2 WHEN 121 THEN 2 WHEN 123 THEN 2 WHEN 124 THEN 2 WHEN 511 THEN 5 WHEN 512 THEN 5 END AS code, Shape FROM U2018_CLC2018_V2020_20u1) AS t WHERE code is NOT NULL" -t_srs EPSG:4326 urban.shp U2018_CLC2018_V2020_20u1.gpkg
```

#### Landuse database from OSM
Download an .osm.pbf file. Eg. with Morocco

```bash
osmium \
    tags-filter \
    --overwrite -o morocco-landuse.osm.pbf \
    morocco-latest.osm.pbf \
    wr/landuse=residential,retail,railway,industrial,garages,construction,commercial,cemetery,village_green,religious,education \
    wr/building!=no

# Use meter unit, eg UTM zone
ogr2ogr \
    -t_srs EPSG:32629 \
    morocco-landuse.gpkg \
    morocco-landuse.osm.pbf \
    multipolygons

# Over simply approach, but it works
ogr2ogr \
    morocco-landuse-union.gpkg \
    -dialect spatialite -sql 'SELECT ST_Union(ST_Buffer(geom, CASE WHEN landuse IS NOT NULL THEN 100 ELSE 50 END, 1)) AS geom FROM multipolygons' \
    -explodecollections \
    morocco-landuse.gpkg
ogr2ogr \
    -t_srs EPSG:4326 \
    morocco-urban.shp \
    -dialect spatialite -sql 'SELECT 2 AS code, ST_Simplify(geom, 20) AS geom FROM "SELECT" WHERE ST_Area(ST_Simplify(geom, 20)) > 30000' \
    -explodecollections \
    morocco-landuse-union.gpkg
```

#### Init landuse database
```bash
docker compose -f docker-compose-tools.yml up -d postgis
docker compose -f docker-compose-tools.yml exec postgis bash -c "\\
  psql -U \${POSTGRES_USER} -w \${POSTGRES_PASSWORD} -c \"
    CREATE TABLE urban (gid serial, code int4);
    ALTER TABLE urban ADD PRIMARY KEY (gid);
    SELECT AddGeometryColumn('','urban','geom','0','MULTIPOLYGON',2);
    ALTER TABLE urban ALTER COLUMN geom TYPE geometry(MultiPolygon, 4326);
    CREATE INDEX urban_idx_geom ON urban USING gist(geom);
  \"
"
```

Load a shapefile. See below how to get shapefile.
```bash
docker compose -f docker-compose-tools.yml up -d postgis
docker compose -f docker-compose-tools.yml exec postgis bash -c "\\
    apt update && apt install -y postgis && \\
    shp2pgsql -a /landuses/urban.shp urban | psql -U \${POSTGRES_USER} -w \${POSTGRES_PASSWORD} \\
"
```

Alternatively, for test purpose only, add just one record into the table
```bash
docker compose -f docker-compose-tools.yml exec postgis bash -c "\\
  psql -U \${POSTGRES_USER} -w \${POSTGRES_PASSWORD} -c \"
    INSERT INTO urban (code, geom) VALUES ('1', NULL);
  \"
"
```

#### Generate Low Emission Zone and Limited Traffic Zone GeoJSON

Add the file at `docker/osrm/low_emission_zone.geojson` and `docker/osrm/limited_traffic_zone.geojson`.

#### Build the graph
```
docker compose -f docker-compose-tools.yml up -d postgis
docker compose -f docker-compose-tools.yml up -d redis-build
docker compose run --rm osrm-car-iceland osrm-build.sh
```

After the build process `postgis` and `redis-build` could be stoped.
```
docker compose -f docker-compose-tools.yml exec redis-build redis-cli SAVE
docker compose -f docker-compose-tools.yml down postgis
docker compose -f docker-compose-tools.yml down redis-build
```

### GraphHopper
#### Build the graph
```
docker compose run --rm gh-car-iceland gh-build.sh
```

## Local router-demo submodule

To work on with the router-demo locally, you must load the front-end submodule `router-demo` (web interface).

Before using Docker or building, run:
```bash
git submodule update --init --recursive
```

Build and update the router-demo with docker:
```bash
git submodule update --remote --merge
docker compose --profile=* run --rm router-demo-build
```

This build of the `router-demo` submodule. The generated files are copied into the `public/` folder and served staticaly by the api service.

Access the web interface, once api service lunched, with: [http://localhost:8082/route.html](http://localhost:8082/route.html)
