SHELL := /bin/sh

build.local:
	BUNDLER_WORKERS=2 BUNDLER_RETRIES=5 docker-compose build

build.test:
	BUNDLER_WORKERS=5 BUNDLER_RETRIES=10 docker-compose build

build.prod:
	docker build -t pender -f production/Dockerfile

build:  build.local


run.local: build.local
	docker run -it -p=3200:3200 -e RAILS_ENV=development -e DEPLOY_ENV=local -e APP=pender pender

# TODO: add ecr, gh token, etc.
run.prod: build.prod
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=production -e DEPLOY_ENV=$DEPLOY_ENV -e APP=pender pender

run:    run.local


# Note: requires databases
# TODO: setup dockerize
test.unit: build.test
	docker-compose --env-file ./.env.test up -d && \
	wget -q --waitretry=5 --retry-connrefused -t 20 -T 10 -O - http://localhost:3200 && \
	docker-compose exec pender bundle exec rake test:units

test.integration: build.test
	docker-compose --env-file ./.env.test up -d && \
	wget -q --waitretry=5 --retry-connrefused -t 20 -T 10 -O - http://localhost:3200 && \
	docker-compose exec pender test/setup-parallel && \
	docker-compose exec pender bundle exec rake "parallel:test[3]" && \
	docker-compose exec pender bundle exec rake parallel:spec

test:	test.integration
