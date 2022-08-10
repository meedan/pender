#!/bin/bash

if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
	echo "GITHUB_TOKEN, DEPLOY_ENV, and APP must be in the environment. Exiting."
	exit 1
fi

# Create configuration files based on SSM and ENV settings.
bash /opt/bin/create_configs.sh

echo "starting sidekiq"
bundle exec sidekiq
