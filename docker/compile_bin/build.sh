#!/bin/bash

mkdir /c
cp -r /geohash /c/

cd /c/geohash

make clean
make static

CPATH=/c
GOPATH=/go

export PATH="$GOPATH/bin:$PATH"
export GEOHASH_LIB="$CPATH/geohash"
export CGO_CFLAGS="-I$CPATH -c -O3 -std=c99"
export CGO_LDFLAGS="-L$GEOHASH_LIB -lgeohash"
export LD_LIBRARY_PATH=$GEOHASH_LIB
export DYLD_LIBRARY_PATH=$GEOHASH_LIB

cd /output
go build github.com/vitaminwater/parsemap
