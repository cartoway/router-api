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
docker compose --profile=* build
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

Configure the landuses database path in the profile.

#### Landuse database from "Corine Land Cover"
Download GeoPackage from [Copernicus](https://land.copernicus.eu/en/products/corine-land-cover/clc2018#download) into the `landuses` directory. Double unzip.

```
duckdb -c "
INSTALL spatial; LOAD spatial;
SET geometry_always_xy = true;
COPY (
    WITH
    bounds AS (SELECT ST_GeomFromGeoJSON('{\"type\":\"Polygon\",\"coordinates\":[[[-21.11,26.04],[12.04,31.15],[8.19,52.76],[-20.94,43.03],[-21.11,26.04]]]}') AS geom),
    bounds_box AS (SELECT ST_Extent(geom)::BOX_2D AS box, ST_Extent(geom)::BOX_2D::STRUCT(min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE) AS b FROM bounds),
    source AS (
        SELECT
            CASE CODE_18
            WHEN '111' THEN 1
            WHEN '112' THEN 2 WHEN '121' THEN 2 WHEN '123' THEN 2 WHEN '124' THEN 2
            WHEN '511' THEN 5 WHEN '512' THEN 5
            END AS code,
            Shape AS geom
        FROM ST_Read('U2018_CLC2018_V2020_20u1.gpkg')
        WHERE ST_Intersects(Shape, ST_Transform((SELECT geom FROM bounds), 'EPSG:4326', 'EPSG:3035'))
    ),
    agg AS (SELECT code, ST_Transform(ST_Union_Agg(ST_Buffer(geom, CASE code WHEN 2 THEN 100 ELSE 0 END, 2)), 'EPSG:3035', 'EPSG:4326') AS geom FROM source GROUP BY code),
    diff AS (
        SELECT agg.code, ST_Difference(agg.geom, ST_Union_Agg(obb.geom)) AS geom FROM agg JOIN agg AS obb ON obb.code != 2 AND ST_Intersects(agg.geom, obb.geom) WHERE agg.code = 2 GROUP BY agg.code, agg.geom
        UNION ALL
        SELECT * FROM agg WHERE code != 2
    ),
    exploded AS (SELECT code, (unnest(ST_Dump(geom))).geom AS geom FROM diff),
    grid AS (
        SELECT ST_MakeEnvelope(x / 10, y / 10, x / 10 + 0.1, y / 10 + 0.1) AS cell
        FROM
            generate_series((SELECT (floor((b).min_x) * 10)::INT FROM bounds_box), (SELECT (ceil((b).max_x) * 10)::INT FROM bounds_box)) AS xs(x),
            generate_series((SELECT (floor((b).min_y) * 10)::INT FROM bounds_box), (SELECT (ceil((b).max_y) * 10)::INT FROM bounds_box)) AS ys(y)
    ),
    clipped AS (
        SELECT s.code, ST_Intersection(s.geom, g.cell) AS geom
        FROM exploded s
        JOIN grid g ON ST_Intersects(s.geom, g.cell)
        WHERE s.code IS NOT NULL AND NOT ST_IsEmpty(ST_Intersection(s.geom, g.cell))
    )
    SELECT * FROM clipped ORDER BY ST_Hilbert(geom, (SELECT box FROM bounds_box))
) TO 'urban-eu.parquet' (FORMAT parquet, COMPRESSION zstd);"
```

#### Landuse database from OSM
Download an .osm.pbf file. Eg. with Morocco

```
duckdb -c "
INSTALL osmium FROM community; LOAD osmium;
INSTALL spatial; LOAD spatial;
SET geometry_always_xy = true;
COPY (
    WITH
    bounds AS (SELECT ST_GeomFromGeoJSON('{\"type\":\"Polygon\",\"coordinates\":[[[-0.10,32.51],[-13.2,20.72],[-20.0,20.81],[-6.21,36.18],[-1.58,35.64],[-0.10,32.51]]]}') AS geom),
    bounds_box AS (SELECT ST_Extent(geom)::BOX_2D AS box, ST_Extent(geom)::BOX_2D::STRUCT(min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE) AS b FROM bounds),
    landuse_utm AS (
        SELECT
            ST_Union_Agg(ST_Buffer(
                ST_Transform(geometry, 'EPSG:4326', 'EPSG:32629'),
                CASE WHEN tags['landuse'] IS NOT NULL THEN 100 ELSE 50 END
            )) AS geom
        FROM 'morocco-latest.osm.pbf'
        WHERE
            kind = 'area' AND
            tags['landuse'] IN ('residential','retail','railway','industrial','garages','construction','commercial','cemetery','village_green','religious','education') AND
            (tags['building'] IS NULL OR tags['building'] != 'no')
    ),
    exploded AS (SELECT (unnest(ST_Dump(geom))).geom AS geom FROM landuse_utm),
    urban AS (
        SELECT ST_Transform(ST_Simplify(geom, 20), 'EPSG:32629', 'EPSG:4326') AS geom
        FROM exploded
        WHERE ST_Area(ST_Simplify(geom, 20)) > 30000
    ),
    grid AS (
        SELECT ST_MakeEnvelope(x / 10, y / 10, x / 10 + 0.1, y / 10 + 0.1) AS cell
        FROM
            generate_series((SELECT (floor((b).min_x) * 10)::INT FROM bounds_box), (SELECT (ceil((b).max_x) * 10)::INT FROM bounds_box)) AS xs(x),
            generate_series((SELECT (floor((b).min_y) * 10)::INT FROM bounds_box), (SELECT (ceil((b).max_y) * 10)::INT FROM bounds_box)) AS ys(y)
    ),
    clipped AS (
        SELECT 2 AS code, ST_Intersection(u.geom, g.cell) AS geom
        FROM urban u
        JOIN grid g ON ST_Intersects(u.geom, g.cell)
        WHERE NOT ST_IsEmpty(ST_Intersection(u.geom, g.cell))
    )
    SELECT * FROM clipped ORDER BY ST_Hilbert(geom, (SELECT box FROM bounds_box))
) TO 'urban-mc.parquet' (FORMAT parquet, COMPRESSION zstd);"
```

#### Generate Low Emission Zone and Limited Traffic Zone GeoJSON

Add the file at `docker/osrm/low_emission_zone.geojson` and `docker/osrm/limited_traffic_zone.geojson`.

#### Build the graph
```
docker compose --profile=build up -d osrm-build-postgis osrm-build-redis
docker compose --profile=build run --rm osrm-car-iceland build.sh
```

After the build process `osrm-build-postgis` and `osrm-build-redis` could be stoped.
```
docker compose --profile=build exec osrm-build-redis redis-cli SAVE
docker compose --profile=build down osrm-build-postgis osrm-build-redis
```

### GraphHopper
#### Build the graph
```
docker compose --profile=build run --rm gh-car-iceland build.sh
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
