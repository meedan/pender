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
