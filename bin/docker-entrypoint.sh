#!/bin/bash
if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
  echo "DEPLOY_ENV and APP must be in the environment. Exiting."
  exit 1
fi

# pender
if [ "${APP}" = 'pender' ] ; then
  if [ "${DEPLOY_ENV}" = 'local' ] ; then
    bundle exec rake db:create
    bundle exec rake db:migrate
    SECRET_KEY_BASE=$(bundle exec rake secret)
    export SECRET_KEY_BASE
    bundle exec rake lapis:api_keys:create_default
  else # qa, live etc
    bash /opt/bin/create_configs.sh
    echo "--- STARTUP COMPLETE ---"
  fi

  DIRPATH=${PWD}/tmp
  PUMA="${DIRPATH}/puma-${DEPLOY_ENV}.rb"
  mkdir -p "${DIRPATH}/pids"
  cp config/puma.rb "${PUMA}"
  cat << EOF >> "${PUMA}"
  pidfile '${DIRPATH}/pids/server-${DEPLOY_ENV}.pid'
  environment '${DEPLOY_ENV}'
  port ${SERVER_PORT}
EOF

  if [ "${DEPLOY_ENV}" = 'local' ||  "${RAILS_ENV}" = 'test' ] ; then
    rm -f "${DIRPATH}/pids/server-${DEPLOY_ENV}.pid"
    bundle exec puma -C "${PUMA}"
  else # qa, live etc
    echo "workers 3" >> "${PUMA}"
    bundle exec puma -C "${PUMA}" -t 8:32
  fi
# pender-background (sidekiq)
elif [ "${APP}" = 'pender-background' ] ; then
  if [ "${DEPLOY_ENV}" = 'local' ] ; then
    until curl --silent -XGET --fail "http://pender:${SERVER_PORT}"; do printf '.'; sleep 1; done
  else # qa, live etc
    bash /opt/bin/create_configs.sh
    echo "starting sidekiq"
  fi
  bundle exec sidekiq
fi
