#!/bin/bash

if ! test -d docker/linux_amd64 ; then
  mkdir docker/linux_amd64
fi;

docker run -v $GOPATH/src:/go/src -v $CPATH/geohash:/geohash -v $(pwd)/compile_bin:/opt/bin -v $(pwd)/linux_amd64:/output -it --rm golang /opt/bin/build.sh
