#!/bin/bash

function config_replace() {
    # sed -i "s/ddRAILS_ENVdd/${RAILS_ENV}/g" /etc/nginx/sites-available/${APP}
    VAR=$1
    VAL=$2
    FILE=$3
    #    echo evaluating $VAR $VAL $FILE;
    if grep --quiet "dd${VAR}dd" $FILE; then
        echo "setting $VAR to $VAL in $FILE"
        CMD="s/dd${VAR}dd/${VAL}/g"
        sed -i'.bak' -e ${CMD} ${FILE}
    fi
}
#since GITHUB_TOKEN environment variable is a json object, we need parse the value
#This function is here due to a limitation by "secrets manager"
function getParsedGithubToken(){
    
  echo $GITHUB_TOKEN | jq -r .GITHUB_TOKEN
}

if [[ -z ${GITHUB_TOKEN+x} || -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
	echo "GITHUB_TOKEN, DEPLOY_ENV, and APP must be in the environment. Exiting."
	exit 1
fi

GITHUB_TOKEN_PARSED=$(getParsedGithubToken)

if [ ! -d "configurator" ]; then git clone https://${GITHUB_TOKEN_PARSED}:x-oauth-basic@github.com/meedan/configurator ./configurator; fi
d=configurator/check/${DEPLOY_ENV}/${APP}/; for f in $(find $d -type f); do cp "$f" "${f/$d/}"; done

# sed in environmental variables
for ENV in $( env | cut -d= -f1); do
    config_replace "$ENV" "${!ENV}" /etc/nginx/sites-available/${APP}
done

cd ${DEPLOYDIR}/shared

# these  are runtime volumes, linked to from ${DEPLOYDIR}/current/
#for DIR in cache db cookies screenshots; do
#  chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}/shared/${DIR}
#  chmod -R 775 ${DEPLOYDIR}/shared/${DIR}
#done

cd -

# perform db migrations at startup
cd ${DEPLOYDIR}/current
su ${DEPLOYUSER} -c 'bundle exec rake db:migrate'

cd -

echo "--- STARTUP COMPLETE ---"

# send log output to the Docker log
tail -f ${DEPLOYDIR}/current/log/production.log &

# normal startup
nginx
