#!/bin/bash

REFRESHER='refresh_app.sh'
SERVICE='parsemap'

if ps ax | grep -v grep | grep -v $$ | grep '\./'$SERVICE > /dev/null
then
    killall $SERVICE
fi

echo "Building..."
go build

if test ! $? -eq 0
then
    echo "Build failed, exiting"
    exit
fi

echo "Build success"

# TODO revert to docker container waiting, digg in commits
# while ! echo exit | nc 10.1.2.3 5432; do sleep 10; done

# sed -e "s/\[postgres_ip\]/$parsemap_db_ip/g" \
#    -e "s/\[postgres_database\]/parsemap/g" \
#    -e "s/\[postgres_role\]/parsemap/g" \
#    -e "s/\[postgres_password\]/parsemap/g" <dev_config.ini.template >dev_config.ini

# If you get an error saying geohash image not found,
# move the libgeohash.so to you /usr/local/lib/ folder.
./$SERVICE -c dev_config.ini
