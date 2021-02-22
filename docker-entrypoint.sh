#!/bin/bash

# Expects following environment variables to be populated:
#   DEPLOY_ENV
#   APP
#   GITHUB_TOKEN
#   SERVER_PORT

# TODO: remove; keeping this here for sidekiq.yml, database.yml, cookies.txt
configurator() {
    if [ ! -d "configurator" ]; then
        git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/meedan/configurator ./configurator
    fi
    CONFIGURATOR_ENV=${DEPLOY_ENV}
    if [[ $DEPLOY_ENV == "test" ]]; then  # override this One Weird Trick
                                          # remove when files in config/ are saved elsewhere
        CONFIGURATOR_ENV="travis"
        rm configurator/check/${CONFIGURATOR_ENV}/${APP}/config/config.yml  # do not copy when testing
    fi
    d=configurator/check/${CONFIGURATOR_ENV}/${APP}/
    for f in $(find $d -type f); do
        cp "$f" "${f/$d/}"
    done
}

# NOTE no pagination so there better not be >1000 parameters...
source_from_ssm() {
    env | grep AWS | wc -l
    all_ssm_params=$(aws ssm get-parameters-by-path --path /${DEPLOY_ENV}/${APP}/ | jq -rcM .Parameters[])
    IFS=$'\n'
    for ssm_param in $all_ssm_params; do
        param_name=$(echo $ssm_param | jq -r .Name)
        echo "Retrieving value for $param_name"
        param_value=$(aws ssm get-parameter --with-decryption --name "$param_name"| jq -r .Parameter.Value)
        export "${param_name##*/}"="${param_value}"
    unset IFS
    done
}

set_config() {
    if [[ "${PRIVATE_REPO_ACCESS}" == "true" ]]; then
        mv config/config.yml.example config/config.yml  # for fallback
        configurator
        source_from_ssm
    else
        find config/ -iname \*.example | rename -v "s/.example//g"
    fi
}


# check if user has private repo access
PRIVATE_REPO_ACCESS="false"
if [[ -z ${GITHUB_TOKEN} ]]; then
    GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code https://github.com/meedan/configurator.git
else
    GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code https://${GITHUB_TOKEN}:x-oauth-basic@github.com/meedan/configurator.git
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


# run sidekiq
if [[ ${APP} == "pender_background" ]]; then
    bin/sidekiq
fi

# run test environment setup
if [[ "${DEPLOY_ENV}" == "travis" || "${DEPLOY_ENV}" == "test" ]]; then
    if [[ "${DEPLOY_ENV}" == "travis" ]]; then
        if [[ -z "${GITHUB_TOKEN}" ]]; then
            echo "GITHUB_TOKEN environment variable must be set. Exiting."
            exit 1
        fi
        configurator  # always set config with configurator for travis
    elif [[ "${DEPLOY_ENV}" == "test" ]]; then
        set_config
    fi

    echo "running rake tasks..."
    bundle exec rake db:create
    bundle exec rake db:migrate
    export SECRET_KEY_BASE=$(bundle exec rake secret)
    bundle exec rake lapis:api_keys:create_default
    echo "rake tasks complete. starting puma..."

    if [[ "${TEST_TYPE}" == "unit" ]]; then
        bundle exec puma --port ${SERVER_PORT} --environment test &
        bundle exec rake test:units
    elif [[ "${TEST_TYPE}" == "integration" ]]; then
        bundle exec puma --port ${SERVER_PORT} --environment test --workers 3 -t 8:32 &
	test/setup-parallel
	bundle exec rake "parallel:test[3]"
        bundle exec rake parallel:spec
    fi

    ./test/test-coverage

# run deployment environment setup (including local runs)
else
    set_config
    echo "running in deployment env"
    if [[ "${APP}" == "pender" ]]; then
        if [[ "${DEPLOY_ENV}" != "local" ]]; then
            if [[ -z "${GITHUB_TOKEN}" ]]; then
                echo "GITHUB_TOKEN environment variable must be set. Exiting."
                exit 1
            fi
            if [[ "${DEPLOY_ENV}" == "prod" ]]; then
                bundle exec puma --port ${SERVER_PORT} --pidfile tmp/pids/server-${RAILS_ENV}.pid --environment ${DEPLOY_ENV} --workers 3 -t 8:32
            fi
        else
            bundle exec puma --port ${SERVER_PORT} --pidfile tmp/pids/server-${RAILS_ENV}.pid
        fi
    elif [[ "${APP}" == "pender_background" ]]; then
        bundle exec sidekiq
    fi
fi

echo "$@"
exec "$@"
