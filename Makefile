SHELL := /bin/sh

build.local:
	docker build -t pender .

build.prod:
	docker build -t pender -f production/Dockerfile

build:  build.local

run.local:
	docker run -it --rm -p=3200:3200 -e RAILS_ENV=development -e DEPLOY_ENV=local -e APP=pender pender

run:    run.local

test:
	echo "placeholder test results here"
