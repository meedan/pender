#!/bin/bash

cd ${DEPLOYDIR}/shared

# these  are runtime volumes, linked to from ${DEPLOYDIR}/current/
for DIR in cache db cookies screenshots; do
  chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}/shared/${DIR}
  chmod -R 775 ${DEPLOYDIR}/shared/${DIR}
done

cd -

# perform db migrations at startup
cd ${DEPLOYDIR}/current
su ${DEPLOYUSER} -c 'bundle exec rake db:migrate'

echo "starting sidekiq"
su ${DEPLOYUSER} -c "bundle exec sidekiq -L log/sidekiq.log -d"

cd -

echo "--- STARTUP COMPLETE ---"

# send log output to the Docker log
tail -f ${DEPLOYDIR}/current/log/production.log &

# normal startup
nginx
