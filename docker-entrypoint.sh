#!/bin/bash

set -e


# TODO: replace with AWS SSM script when ready
configurator() {
    if [ ! -d "configurator" ]; then
        git clone https://github.com/meedan/configurator ./configurator
    fi
    d=configurator/check/${DEPLOY_ENV}/${APP}/
    for f in $(find $d -type f); do
        cp "$f" "${f/$d/}"
    done
}

set_config() {
    INTERNAL=$1
    if [[ "${INTERNAL}" == "true" ]]; then
        configurator
    else
        find config/ -iname \*.example | rename -v "s/.example//g"
    fi
}


# check if user has configurator access
PRIVATE_REPO_ACCESS="false"
git clone -q https://github.com/meedan/configurator.git
if [[ $? -eq 0 ]]; then
    PRIVATE_REPO_ACCESS="true"
fi

# check that required environment variables are set
if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
    echo "DEPLOY_ENV and APP environment variables must be set. Exiting."
    exit 1
fi

# run test environment setup
if [[ "${DEPLOY_ENV}" == "travis" || "${DEPLOY_ENV}" == "test" ]]; then
    if [[ "${DEPLOY_ENV}" == "travis" ]]; then
        if [[ -z "${GITHUB_TOKEN}" ]]; then
            echo "GITHUB_TOKEN environment variable must be set. Exiting."
            exit 1
        fi
        configurator()  # always set config with configurator for travis
    elif [[ "${DEPLOY_ENV}" == "test" ]]; then
        set_config "${PRIVATE_REPO_ACCESS}"
    fi

    # TODO: containerize these test tasks
    bundle exec rake db:create
    bundle exec rake db:migrate
    export SECRET_KEY_BASE=$(bundle exec rake secret)
    bundle exec rake lapis:api_keys:create_default

    PIDS=${PWD}/tmp/pids
    mkdir -p ${PIDS}
    rm -f ${PIDS}/server-$RAILS_ENV.pid
    puma="${PIDS}/puma-$RAILS_ENV.rb"
    cp config/puma.rb $puma
    echo "pidfile '${PIDS}/server-$RAILS_ENV.pid'" >> $puma
    echo "port $SERVER_PORT" >> $puma
    bundle exec puma -C $puma

# run deployment environment setup (including local runs)
else
    if [[ "${DEPLOY_ENV}" != "local"  ]]; then
        if [[ -z "${GITHUB_TOKEN}" ]]; then
            echo "GITHUB_TOKEN environment variable must be set. Exiting."
            exit 1
        fi
        # TODO: add from production start script
    fi
    set_config "${PRIVATE_REPO_ACCESS}"
fi

exec "$@"
