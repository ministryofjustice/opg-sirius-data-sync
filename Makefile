SHELL = '/bin/bash'
export DOCKER_BUILDKIT ?= 1

all: build scan test test-role-setup test-database-tuning cleanup

build:
	docker compose build data-sync

scan:
	trivy image 311462405659.dkr.ecr.eu-west-1.amazonaws.com/sirius/data-sync:latest

.PHONY: test
test:
	docker run --rm -d -i --name data-sync 311462405659.dkr.ecr.eu-west-1.amazonaws.com/sirius/data-sync:latest
	inspec exec test -t docker://data-sync --chef-license=accept-silent --reporter cli junit:data-sync-inspec.xml

test-role-setup:
	docker compose up --wait -d postgresql
	docker compose run --rm create-database
	docker compose run --rm create-roles
	docker compose down

test-database-tuning:
	docker compose up --wait -d postgresql
	docker compose run --rm create-database
	docker compose run --rm database-tuning
	docker compose down

cleanup:
	docker rm --force data-sync
