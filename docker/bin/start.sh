#!/bin/bash

cd ${DEPLOYDIR}/shared

# these  are runtime volumes, linked to ${BDIR}/current/
chown -R ${DEPLOYUSER}:www-data cache
chmod -R 775 cache

chown -R ${DEPLOYUSER}:www-data db
chmod -R 775 screenshots

cd -

# perform db migrations at startup
cd ${DEPLOYDIR}/current
su ${DEPLOYUSER} -c 'bundle exec rake db:migrate'

cd -

# normal startup
nginx
