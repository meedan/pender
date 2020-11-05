#!/bin/bash


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
    PRIVATE_REPO_ACCESS=$1
    if [[ "${PRIVATE_REPO_ACCESS}" == "true" ]]; then
        configurator
    else
        find config/ -iname \*.example | rename -v "s/.example//g"
    fi
}


# check if user has private repo access
PRIVATE_REPO_ACCESS="false"
if [[ -z ${GITHUB_TOKEN} ]]; then
    GIT_TERMINAL_PROMPT=0 git clone -q https://github.com/meedan/configurator.git
else
    GIT_TERMINAL_PROMPT=0 git clone -q https://${GITHUB_TOKEN}:x-oauth-basic@github.com/meedan/configurator.git
fi
if [[ $? -eq 0 ]]; then
    PRIVATE_REPO_ACCESS="true"
fi
echo "Private Repo Access? ${PRIVATE_REPO_ACCESS}"

set -e
# check that required environment variables are set
if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
    echo "DEPLOY_ENV and APP environment variables must be set. Exiting."
    exit 1
fi
echo "Running application [${APP}] in [${DEPLOY_ENV}] environment"

# run test environment setup
if [[ "${DEPLOY_ENV}" == "travis" || "${DEPLOY_ENV}" == "test" ]]; then
    if [[ "${DEPLOY_ENV}" == "travis" ]]; then
        if [[ -z "${GITHUB_TOKEN}" ]]; then
            echo "GITHUB_TOKEN environment variable must be set. Exiting."
            exit 1
        fi
        configurator  # always set config with configurator for travis
    elif [[ "${DEPLOY_ENV}" == "test" ]]; then
        set_config "${PRIVATE_REPO_ACCESS}"
    fi

    # TODO: containerize these test tasks
    echo "running rake tasks"
    bundle exec rake db:create
    bundle exec rake db:migrate
    export SECRET_KEY_BASE=$(bundle exec rake secret)
    bundle exec rake lapis:api_keys:create_default

    echo "rake tasks complete running puma"
    bundle exec puma --port ${SERVER_PORT} --pidfile tmp/pids/server-${RAILS_ENV}.pid &
    test/setup-parallel
    bundle exec rake "parallel:test[3]"

# run deployment environment setup (including local runs)
else
    set_config "${PRIVATE_REPO_ACCESS}"
    if [[ "${DEPLOY_ENV}" != "local"  ]]; then
        if [[ -z "${GITHUB_TOKEN}" ]]; then
            echo "GITHUB_TOKEN environment variable must be set. Exiting."
            exit 1
        fi
        # TODO: add from production start script

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
    fi
fi

exec "$@"
