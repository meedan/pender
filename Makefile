SHELL := /bin/sh

build.local:
	docker build -t pender .

build.test.integration:
	DEPLOY_ENV=test RAILS_ENV=test APP=pender docker-compose build

build.prod:
	docker build -t pender -f production/Dockerfile

build:  build.local


run.local: build.local
	docker run -it -p=3200:3200 -e RAILS_ENV=development -e DEPLOY_ENV=local -e APP=pender pender

run.test.unit: build.local
	docker run -it -p=3200:3200 -e SERVER_PORT=3200 -e RAILS_ENV=test -e DEPLOY_ENV=test -e APP=pender pender bundle exec rake test:units

run.test.integration: 	build.test.integration
	SERVER_PORT=3200 RAILS_ENV=test DEPLOY_ENV=test APP=pender docker-compose up -d pender

run.prod: build.prod
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=production -e DEPLOY_ENV=$DEPLOY_ENV -e APP=pender pender

run:    run.local

test.unit:		run.test.unit

test.integration: 	build.test.integration
	docker-compose run -e SERVER_PORT=3200 -e RAILS_ENV=test -e DEPLOY_ENV=test -e APP=pender pender && \
	docker-compose exec pender test/setup-parallel && \
	docker-compose exec pender bundle exec rake "parallel:test[3]"

test:	test.integration
