#!/bin/bash

# Wait for API
until curl --silent -XGET --fail http://pender:${SERVER_PORT}; do printf '.'; sleep 1; done

# Sidekiq
bundle exec sidekiq
