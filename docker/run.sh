#!/bin/bash

dir=$(pwd)
cd $(dirname "${BASH_SOURCE[0]}")
cp Dockerfile ..
cd ..

# Build
docker build -t lapis/pender .

# Run
secret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
docker run -d -p 80:80 --name pender -e SECRET_KEY_BASE=$secret lapis/pender

echo
docker ps | grep 'pender'
echo

echo '-----------------------------------------------------------'
echo 'Now go to your browser and access http://localhost/api'
echo '-----------------------------------------------------------'

rm Dockerfile
cd $dir
