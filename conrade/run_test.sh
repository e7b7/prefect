#!/bin/bash

set -x

m=${1:-"local"}
k=${2:-"x"}
r=${3:-"10"}
d=${4:-"tmp"}

mkdir -p $d

if [ $m == "local" ]; then
    export PREFECT_API_URL="http://127.0.0.1:4200/api"
    export PREFECT_API_DATABASE_CONNECTION_URL="postgresql+asyncpg://postgres:xxxx@localhost:5432/prefect"
elif [ $m == "dev" ]; then
    export PREFECT_API_URL="http://prefect-reseng-dev.chicagotrading.io/api"
else
    echo bad mode setting
    exit
fi

# some docker stuff
# docker network create mynet
#
# this is the setup for postgres
function dpg {
docker run \
    --name postgres \
    --network mynet \
    --cap-add NET_ADMIN \
    -e POSTGRES_PASSWORD=xxxx \
    -p 5432:5432 \
    -v pgdata:/var/lib/postgresql/data \
    -d \
    postgres
}

# control network, add a delay etc, with tc
#
# docker exec -it prefect-dev sh -c 'apt update && apt-get install -y iproute2
# docker exec -it prefect-dev sh -c 'tc qdisc del dev lo root netem'
#
# docker exec -it postgres sh -c 'tc qdisc add dev lo root netem delay 100ms 50ms'
#
# test it...
# docker exec -it postgres sh -c 'psql -h 127.0.0.1 -p 5432 -U postgres postgres -c "\timing" -c "SELECT 1"'
# should give 100+ms, not 5-10ms
#
# psql -h localhost -p 5432 -U postgres -c 'create database prefect;'
#
# also, we can put prefect in a docker container, uv run prefect build-image, then
function dpd {
image=prefecthq/prefect-dev:sha-87e4967-python3.13
#image=prefecthq/prefect-dev:sha-f0d72e5-python3.11
docker run \
    --name prefect-dev \
    --network mynet \
           --network-alias prefect-dev \
           --cap-add NET_ADMIN \
           -e PREFECT_API_DATABASE_CONNECTION_URL="postgresql+asyncpg://postgres:xxxx@postgres:5432/prefect" \
           -p 4200:4200 \
           -d \
           $image \
           prefect server start --log-level DEBUG --host 0.0.0.0 --port 4200
}

# maybe some delay...
# docker exec -it prefect-dev sh -c 'tc qdisc add dev lo root netem delay 100ms 50ms'
#
# or some delay plus loss
# docker exec -it prefect-dev sh -c 'tc qdisc add dev lo root netem loss 1% delay 100ms 50ms'
#
# or add in some buffer/burst
# docker exec -it prefect-dev sh -c 'tc qdisc add dev lo root tbf rate 1mbit burst 32kbit latency 400ms'

#echo starting server...
#uv run prefect server start --host 0.0.0.0 --port $p --log-level DEBUG > $d/s$k.log 2>&1 &
#s=$!
#sleep 5
#tail $d/s$k.log
#sleep 5

echo starting viz...
uv run prefect event stream > $d/1$k.log 2>&1 &
a=$!
sleep 1

uv run prefect event stream > $d/2$k.log 2>&1 &
b=$!
sleep 1

echo testing...
uv run pytest --flake-finder --flake-runs=$r integration-tests/test_concurrent_subflows.py

echo waiting for a bit...
sleep 25

#for x in $a $b $s; do
for x in $a $b; do
    echo killing $x...
    kill -s INT $x
done

echo done
