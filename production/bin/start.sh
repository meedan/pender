#!/bin/bash

if [[ -z ${GITHUB_TOKEN+x} || -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
	echo "GITHUB_TOKEN, DEPLOY_ENV, and APP must be in the environment. Exiting."
	exit 1
fi

if [ ! -d "configurator" ]; then git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/meedan/configurator ./configurator; fi
d=configurator/check/${DEPLOY_ENV}/${APP}/; for f in $(find $d -type f); do cp "$f" "${f/$d/}"; done

echo "--- STARTUP COMPLETE ---"

mkdir -p ${PWD}/tmp/pids
puma="${PWD}/tmp/puma-${DEPLOY_ENV}.rb"
cp config/puma.rb ${puma}
cat << EOF >> ${puma}
pidfile '${PWD}/tmp/pids/server-${DEPLOY_ENV}.pid'
environment '${DEPLOY_ENV}'
port ${SERVER_PORT} 
workers 3 
EOF

bundle exec puma -C ${puma} -t 8:32