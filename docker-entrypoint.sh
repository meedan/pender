#!/bin/bash

# Expects following environment variables to be populated:
#   DEPLOY_ENV
#   APP

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
    find config/ -iname \*.example | rename -v "s/.example//g"
}

main() {
    set -e
    # check that required environment variables are set
    if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
        echo "DEPLOY_ENV and APP environment variables must be set. Exiting."
        exit 1
    fi
    echo "Running application [${APP}] in [${DEPLOY_ENV}] environment"


    # run sidekiq
    if [[ ${APP} == "pender_background" ]]; then
        mkdir tmp
        touch tmp/restart.txt
        until curl --silent -XGET --fail http://pender:${SERVER_PORT}; do printf '.'; sleep 1; done
        bin/sidekiq
    fi

    # run test environment setup
    if [[ "${DEPLOY_ENV}" == "test" ]]; then
        set_config

        echo "running rake tasks..."
        bundle exec rake db:create
        bundle exec rake db:migrate
        export SECRET_KEY_BASE=$(bundle exec rake secret)
        bundle exec rake lapis:api_keys:create_default
        echo "rake tasks complete. starting puma..."

        bundle exec puma --port ${SERVER_PORT} --environment test --workers 2 -t 8:32
        echo "puma running..."

    # run deployment environment setup (including local runs)
    else
        set_config
        source_from_ssm
        echo "running in deployment env"
        if [[ "${APP}" == "pender" ]]; then
            if [[ "${DEPLOY_ENV}" != "local" ]]; then
                if [[ -z "${GITHUB_TOKEN}" ]]; then
                    echo "GITHUB_TOKEN environment variable must be set. Exiting."
                    exit 1
                fi
                if [[ "${DEPLOY_ENV}" == "live" || "${DEPLOY_ENV}" == "qa" ]]; then
                    bundle exec puma --port ${SERVER_PORT} --environment ${DEPLOY_ENV} --workers 3 -t 8:32
                fi
            else
                bundle exec puma --port ${SERVER_PORT}
            fi
        fi
    fi
}

main
echo "$@"
exec "$@"
