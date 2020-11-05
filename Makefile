SHELL := /bin/sh

build.local:
	docker build -t pender .

build.prod:
	docker build -t pender -f production/Dockerfile

build:  build.local

run.local:
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=development -e DEPLOY_ENV=local -e APP=pender pender

run.prod:
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=production -e DEPLOY_ENV=$DEPLOY_ENV -e APP=pender pender

run:    run.local

test.all:
	docker-compose build && \
	docker-compose -f docker-compose.yml -f docker-test.yml up -d && \
	docker-compose run -e RAILS_ENV=test -e DEPLOY_ENV=local -e APP=pender pender && \
	wget -q --waitretry=5 --retry-connrefused -t 20 -T 10 -O - http://localhost:3200 && \
	echo 'executing test' && \
	docker-compose exec pender test/setup-parallel && \
	docker-compose exec pender bundle exec rake "parallel:test[3]"
