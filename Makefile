SHELL := /bin/sh

build:
	docker build -t pender .

run:
	docker run -it --rm -p=3200:3200 pender

test:
	echo "placeholder test results here"
