SHELL = '/bin/bash'
export DOCKER_BUILDKIT ?= 1

all: build test test-role-setup test-database-tuning cleanup

build:
	docker compose build data-sync

.PHONY: test
test:
	docker compose run -i -d --rm  --name goss goss
	docker compose run --rm --name data-sync -i -d data-sync
	docker compose exec -it data-sync /goss-bin/goss validate

test-role-setup:
	docker compose up --wait -d postgresql
	docker compose run --rm create-database
	docker compose run --rm create-roles
	docker compose down

test-dms-setup:
	docker compose up --wait -d postgresql
	docker compose run --rm create-database
	docker compose run --rm dms-setup
	docker compose down

test-database-tuning:
	docker compose up --wait -d postgresql
	docker compose run --rm create-database
	docker compose run --rm database-tuning
	docker compose down

cleanup:
	docker rm --force data-sync goss
