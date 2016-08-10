#!/bin/bash

cd ${DEPLOYDIR}/shared

# these  are runtime volumes, linked to from ${DEPLOYDIR}/current/
chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}/shared/cache
chmod -R 775 ${DEPLOYDIR}/shared/cache

chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}/shared/db
chmod -R 775 ${DEPLOYDIR}/shared/db

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
