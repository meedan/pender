#!/bin/bash

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
    cd config/ && find -name '*.example' | while read f; do cp "$f" "${f%%.example}"; done && cd ..
}

env | grep DEPLOY_ENV
if [[ "${DEPLOY_ENV}" == "test" ]]; then
    echo "setting up SSM..."
    set_config
    source_from_ssm
fi

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
