.PHONY: test
SHELL = '/bin/bash'
export DOCKER_BUILDKIT ?= 1

build default:
	docker build -t data-sync:latest .

test:
	docker run --rm -d -i --name data-sync data-sync:latest
	inspec exec test -t docker://data-sync --reporter cli junit:data-sync-inspec.xml

cleanup:
	docker rm --force data-sync
