SHELL := /bin/sh

build.local:
	BUNDLER_WORKERS=2 BUNDLER_RETRIES=5 docker-compose build

build.test:
	BUNDLER_WORKERS=5 BUNDLER_RETRIES=10 docker-compose build

build.prod:
	docker build -t pender -f production/Dockerfile

build:  build.local


# Note: requires databases
# TODO: setup dockerize
test.unit: build.test
	TEST_TYPE=unit docker-compose --env-file ./.env.test up --abort-on-container-exit

test.integration: build.test
	TEST_TYPE=integration docker-compose --env-file ./.env.test up --abort-on-container-exit

test:	test.integration


run.local: build.local
	docker run -it -p=3200:3200 -e RAILS_ENV=development -e DEPLOY_ENV=local -e APP=pender pender

# TODO: add ecr, gh token, etc.
run.prod: build.prod
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=production -e DEPLOY_ENV=$DEPLOY_ENV -e APP=pender pender

run:    run.local
