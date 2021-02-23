SHELL := /bin/sh

build.local:
	docker-compose --log-level ERROR --env-file ./.env.local build pender

build.test:
	docker-compose --log-level ERROR --env-file ./.env.test build pender

build: build.local

# NOTE: no unit tests that do not reach out to other services
test.unit: build.test
	docker-compose --env-file ./.env.test up --abort-on-container-exit

test:	test.unit


run.local: build
	docker-compose --env-file ./.env.local up --abort-on-container-exit pender

run.background: build
	APP=pender_background docker-compose --env-file ./.env.local up pender -d

run.prod: build
	DEPLOY_ENV=${DEPLOY_ENV} docker-compose --env-file ./.env.prod up --abort-on-container-exit

run: run.local


clean:
	docker-compose --log-level ERROR --env-file ./.env.local down && \
	rm -f db/test*.sqlite3* schema.rb config/cookies.txt config/database.yml sidekiq.yml config.yml
