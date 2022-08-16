#!/bin/bash

# generate configurartion files with group and world read permissions.
umask 022

echo "Starting application configuration. Processing ENV settings."

# Move default configs into place.
# For most environments, these settings are overridden in ENV set from SSM.
(
  cd config
  if [ ! -f config.yml ]; then
    cp config.yml.example config.yml
  fi
  if [ ! -f database.yml ]; then
    cp database.yml.example database.yml
  fi
  if [ ! -f sidekiq.yml ]; then
    cp sidekiq.yml.example sidekiq.yml
  fi
  if [ ! -f cookies.txt ]; then
    # Copy a default cookie file into place, even if using S3 storage for cookies.
    cp cookies.txt.example config/cookies.txt
  fi

  # Generate sidekiq config from SSM:
  WORKTMP=$(mktemp)
  if [[ -z ${sidekiq_config+x} ]]; then
    echo "Error: missing sidekiq_config ENV setting. Using defaults."
  else
    echo ${sidekiq_config} | base64 -d > $WORKTMP
    if (( $? != 0 )); then
      echo "Error: could not decode ENV var: ${sidekiq_config} . Using defaults."
      rm $WORKTMP
    else
      echo "Using decoded sidekiq config from ENV var: ${sidekiq_config} ."
      mv $WORKTMP sidekiq.yml
      sha1sum sidekiq.yml
    fi
  fi

  # Generate database configuration from SSM:
  WORKTMP=$(mktemp)
  if [[ -z ${database_config+x} ]]; then
    echo "Error: missing database_config ENV setting. Using defaults."
  else
    echo ${database_config} | base64 -d > $WORKTMP
    if (( $? != 0 )); then
      echo "Error: could not decode ENV var: ${database_config} . Using defaults."
      rm $WORKTMP
    else
      echo "Using decoded database config from ENV var: ${database_config} ."
      mv $WORKTMP database.yml
      sha1sum database.yml
    fi
  fi

  # Populate production environment config from SSM:
  WORKTMP=$(mktemp)
  if [[ -z ${environments_production+x} ]]; then
    echo "Error: missing environments_production ENV setting. Using defaults."
  else
    echo ${environments_production} | base64 -d > $WORKTMP
    if (( $? != 0 )); then
      echo "Error: could not decode ENV var: ${environments_production} . Using defaults."
      rm $WORKTMP
    else
      echo "Using decoded database config from ENV var: ${environments_production} ."
      mv $WORKTMP environments/production.rb
      sha1sum environments/production.rb
    fi
  fi
)

echo "Configuration complete."
exit 0
