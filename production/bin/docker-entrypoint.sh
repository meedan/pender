#!/bin/bash

if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
	echo "DEPLOY_ENV and APP must be in the environment. Exiting."
	exit 1
fi

# Create configuration files based on SSM and ENV settings.
bash /opt/bin/create_configs.sh

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
