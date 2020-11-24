SHELL := /bin/sh

build.local:
	docker-compose --log-level ERROR build pender

build.test: build.local
build: build.local


# Note: requires databases
# TODO: setup dockerize
test.unit: build.test
	TEST_TYPE=unit docker-compose --env-file ./.env.test up --abort-on-container-exit

test.integration: build.test
	TEST_TYPE=integration docker-compose --env-file ./.env.test up --abort-on-container-exit

test:	test.integration


run.local: build
	docker-compose --env-file ./.env.local up --abort-on-container-exit pender

# TODO: add ecr, gh token, etc.
run.prod: build
	DEPLOY_ENV=${DEPLOY_ENV} docker-compose --env-file ./.env.prod up --abort-on-container-exit

run: run.local
