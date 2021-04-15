SHELL := /bin/sh

build.local:
	docker-compose --log-level ERROR build pender

build: build.local


run.local: build
	docker-compose --env-file ./.env.local up -d pender

run.background: build
	docker-compose --env-file ./.env.background_local up -d pender

run.deploy: build
	DEPLOY_ENV=${DEPLOY_ENV} docker-compose --env-file ./.env.${DEPLOY_ENV} up pender -d

run.test: build
	docker-compose --env-file ./.env.test up -d

run: run.local


# NOTE: no unit tests that do not reach out to other services
test.unit: run.test
	docker-compose exec pender ./run_test.sh

test.coverage:
	docker-compose exec pender ./test/test-coverage

test:	test.unit


coverage: test.coverage

clean:
	docker-compose --log-level ERROR --env-file ./.env.local down && \
	rm -f db/test*.sqlite3* schema.rb config/cookies.txt config/database.yml sidekiq.yml config.yml
