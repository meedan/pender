#!/bin/bash

echo "starting sidekiq"
su ${DEPLOYUSER} -c "bundle exec sidekiq"
