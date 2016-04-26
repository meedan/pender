#!/bin/bash

dir=$(pwd)
cd $(dirname "${BASH_SOURCE[0]}")
cd ..

IMAGE=dreg.meedan.net/meedan/pender

# Build
docker build -t ${IMAGE} .

# Run
secret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
docker run -d -p 3000:80 --name pender -e SECRET_KEY_BASE=$secret ${IMAGE}

echo
docker ps | grep 'pender'
echo

echo '-----------------------------------------------------------'
echo 'Now go to your browser and access http://localhost:3000/api'
echo '-----------------------------------------------------------'

rm Dockerfile
cd $dir
