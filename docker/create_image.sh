#!/bin/bash

set -e

`docker-machine env dev | grep -v \# | sed s/\"//g`

./compile.sh

cp ../sql/schema.sql docker-entrypoint-initdb.d/00schema.sql
cp ../sql/plpgsql.sql docker-entrypoint-initdb.d/01plpgsql.sql

docker build -t parsemap .

docker save parsemap > parsemap.tar
gzip parsemap.tar
