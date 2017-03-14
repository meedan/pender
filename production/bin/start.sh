#!/bin/bash

cd ${DEPLOYDIR}/shared

# these  are runtime volumes, linked to from ${DEPLOYDIR}/current/
for DIR in cache db cookies; do
  chown -R ${DEPLOYUSER}:www-data ${DEPLOYDIR}/shared/${DIR}
  chmod -R 775 ${DEPLOYDIR}/shared/${DIR}
done

cd -

# perform db migrations at startup
cd ${DEPLOYDIR}/current
su ${DEPLOYUSER} -c 'bundle exec rake db:migrate'

cd -

echo "--- STARTUP COMPLETE ---"

echo "starting sidekiq"
su ${DEPLOYUSER} -c "bundle exec sidekiq -L log/sidekiq.log -d"

# send log output to the Docker log
tail -f ${DEPLOYDIR}/current/log/production.log &

# normal startup
nginx
