SHELL := /bin/sh

build.local:
	docker-compose --log-level ERROR build pender

build: build.local


run.local: build
	docker-compose --env-file ./.env.local up -d pender

run.background: build
	docker-compose --env-file ./.env.background_local up -d pender-background

run.deploy: build
	DEPLOY_ENV=${DEPLOY_ENV} docker-compose --env-file ./.env.${DEPLOY_ENV} up -d pender

run.test: build
	docker-compose --env-file .env.test up --abort-on-container-exit pender &

run: run.local


# NOTE: test commands assume a container is running (ie. with make run.test)
test.unit:
	docker-compose exec pender ./run_test.sh

test.coverage:
	docker-compose exec pender ./test/test-coverage

test:	test.unit


coverage: test.coverage


clean:
	docker-compose down && \
	rm -f db/test*.sqlite3* schema.rb config/cookies.txt config/database.yml sidekiq.yml config.yml
