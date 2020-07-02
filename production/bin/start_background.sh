#!/bin/bash

if [[ -z ${GITHUB_TOKEN+x} || -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
	echo "GITHUB_TOKEN, DEPLOY_ENV, and APP must be in the environment. Exiting."
	exit 1
fi


if [ ! -d "configurator" ]; then git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/meedan/configurator ./configurator; fi
d=configurator/check/${DEPLOY_ENV}/${APP}/; for f in $(find $d -type f); do cp "$f" "${f/$d/}"; done


echo "starting sidekiq"
bundle exec sidekiq -C config/sidekiq.yml &
[[ -s config/sidekiq-videos.yml ]] && bundle exec sidekiq -C config/sidekiq-videos.yml &
