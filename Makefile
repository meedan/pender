SHELL := /bin/sh

build.local:
	docker-compose --log-level ERROR --env-file ./.env.local build pender

build.test:
	docker-compose --log-level ERROR --env-file ./.env.test build pender

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


clean:
	docker-compose --log-level ERROR --env-file ./.env.local down && \
	rm -f db/test*.sqlite3* schema.rb config/cookies.txt config/database.yml sidekiq.yml config.yml
