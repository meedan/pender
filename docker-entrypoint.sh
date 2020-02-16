#!/bin/bash
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
