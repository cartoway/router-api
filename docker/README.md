# Building images

```
docker-compose build
```

# Run the services

```
docker-compose up -d
```

# OTP

## Build OTP graphs

```
cd router-api/docker/otp
./otp-rebuild-all.sh
# OR
./otp-rebuild.sh bordeaux
```

The script will build `bordeaux` graph from `./otp/data/graphs` in `/srv/docker`
