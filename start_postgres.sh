#!/bin/bash

cp sql/schema.sql docker/docker-entrypoint-initdb.d/00schema.sql
cp sql/plpgsql.sql docker/docker-entrypoint-initdb.d/01plpgsql.sql

docker run -e POSTGRES_USER=parsemap -e POSTGRES_PASSWORD=parsemap --rm -it -p 5432:5432 -v $(pwd)/docker/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d --name parsemap_postgres postgres
