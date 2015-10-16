#!/bin/bash

POSTGRES_IP=$(docker inspect -f {{.NetworkSettings.IPAddress}} parsemap_db)

echo "Connecting to database at $POSTGRES_IP"

echo "DROP DATABASE parsemap" | psql -U postgres -h $POSTGRES_IP
echo "CREATE DATABASE parsemap OWNER parsemap" | psql -U postgres -h $POSTGRES_IP

psql -U parsemap -h $POSTGRES_IP parsemap < migrations/initial.sql
psql -U parsemap -h $POSTGRES_IP parsemap < migrations/initial_data.sql
