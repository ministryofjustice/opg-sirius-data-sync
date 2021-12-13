SHELL = '/bin/bash'
export DOCKER_BUILDKIT ?= 1

all: build test cleanup

build:
	docker build -t data-sync:latest .

.PHONY: test
test:
	docker run --rm -d -i --name data-sync data-sync:latest
	inspec exec test -t docker://data-sync --reporter cli junit:data-sync-inspec.xml

cleanup:
	docker rm --force data-sync
