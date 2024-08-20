#!/bin/bash

############
##### run pender

if [ ${RAILS_ENV} = 'development' ] ; then
	# LOCAL
	bundle exec rake db:create
	bundle exec rake db:migrate
	export SECRET_KEY_BASE=$(bundle exec rake secret)
	bundle exec rake lapis:api_keys:create_default

	mkdir -p ${PWD}/tmp/pids
	puma="${PWD}/tmp/pids/puma-${RAILS_ENV}.rb"
	cp config/puma.rb ${puma}
	cat << EOF >> ${puma}
	pidfile '${PWD}/tmp/pids/server-${RAILS_ENV}.pid'
	environment '${RAILS_ENV}'
	port ${SERVER_PORT} 
EOF

	rm -f ${PWD}/tmp/pids/server-${RAILS_ENV}.pid

	bundle exec puma -C ${puma}

else

	# PROD
	if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
		echo "DEPLOY_ENV and APP must be in the environment. Exiting."
		exit 1
	fi

	# Create configuration files based on SSM and ENV settings.
	bash /opt/bin/create_configs.sh

	echo "--- STARTUP COMPLETE ---"

	mkdir -p ${PWD}/tmp/pids
	puma="${PWD}/tmp/puma-${DEPLOY_ENV}.rb"
	cp config/puma.rb ${puma}
	cat << EOF >> ${puma}
	pidfile '${PWD}/tmp/pids/server-${DEPLOY_ENV}.pid'
	environment '${DEPLOY_ENV}'
	port ${SERVER_PORT} 
	workers 3 
EOF

	bundle exec puma -C ${puma} -t 8:32

fi


############
##### run sidekiq

# # LOCAL
# # Wait for API
# until curl --silent -XGET --fail http://pender:${SERVER_PORT}; do printf '.'; sleep 1; done

# # Sidekiq
# bundle exec sidekiq

# ######

# # PROD
# if [[ -z ${DEPLOY_ENV+x} || -z ${APP+x} ]]; then
# 	echo "DEPLOY_ENV and APP must be in the environment. Exiting."
# 	exit 1
# fi

# # Create configuration files based on SSM and ENV settings.
# bash /opt/bin/create_configs.sh

# echo "starting sidekiq"
# bundle exec sidekiq
