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
	docker run -it -p=3200:3200 -e SERVER_PORT=3200 -e RAILS_ENV=test -e DEPLOY_ENV=test -e APP=pender pender

run.prod: build.prod
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=production -e DEPLOY_ENV=$DEPLOY_ENV -e APP=pender pender

run:    run.local

test.integration: 	build.test.integration
	docker-compose run -e RAILS_ENV=test -e DEPLOY_ENV=test -e APP=pender pender && \
	wget -q --waitretry=5 --retry-connrefused -t 20 -T 10 -O - http://localhost:3200 && \
	docker-compose exec pender test/setup-parallel && \
	docker-compose exec pender bundle exec rake "parallel:test[3]"

test:	test.integration
