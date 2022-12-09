# Sample Spring Postgres App

Sample spring boot application connecting to a Postgres DB.

# Features

* HTTP server listens on port 8080
* CRUD API exposed at `/customer`
* Prometheus metrics exposed at `/actuator/prometheus`
* Liveness and readiness information exposed at `/actuator/health/liveness` and `/actuator/health/readiness`

# Local setup

## Prerequisites
- Docker

## Startup

1. Build the docker image locally using 
```shell
    ./gradlew jibDockerBuild
```

1. Start the containers using docker compose 
```shell
    docker-compose up
```

1. Use the provided [Postman collection](./postman) to hit the application endpoints
1. Alternatively, use the following curl commands
- Create / Update customer
```shell
    curl --location --request PUT 'localhost:8080/customer/' \
        --header 'Content-Type: application/json' \
        --data-raw '{
            "name": "John Smith"
        }'
```
- Fetch customer
```shell
    curl --location --request GET 'localhost:8080/customer/1'
```
- Delete customer
```shell
    curl --location --request DELETE 'localhost:8080/customer/1'
```

