.PHONY: test
SHELL = '/bin/bash'
export DOCKER_BUILDKIT ?= 1
export BUILD_TAG ?= latest

build default:
	docker build -t 311462405659.dkr.ecr.eu-west-1.amazonaws.com/sirius/database-sync:${BUILD_TAG} .

test:
	docker run --rm -d -i --name data-sync 311462405659.dkr.ecr.eu-west-1.amazonaws.com/sirius/database-sync:${BUILD_TAG}
	inspec exec test -t docker://data-sync --reporter cli junit:data-sync-inspec.xml

cleanup:
	docker rm --force data-sync
