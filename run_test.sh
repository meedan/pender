#!/bin/bash

# Expects following environment variables to be populated:
#   DEPLOY_ENV
#   APP

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
    find config/ -iname \*.example | rename -v "s/.example//g"
    source_from_ssm
}

main() {
    until curl --silent -I -f --fail http://localhost:3200 ; do printf .; sleep 1; done

    set -e
    # check that required environment variables are set
    if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
        echo "DEPLOY_ENV and APP environment variables must be set. Exiting."
        exit 1
    fi
    echo "Running test for service [${APP}] in [${DEPLOY_ENV}] environment"

    if [[ "${DEPLOY_ENV}" == "test" ]]; then
        set_config

        test/setup-parallel
        bundle exec rake "parallel:test[3]"
        bundle exec rake parallel:spec
        test/test-coverage
    else
        exit 1
    fi
}

main
echo "$@"
exec "$@"
