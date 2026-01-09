#! /usr/bin/env bash
psql -U $PGUSER --dbname=$DATABASE_NAME --file=./table-deletion.sql
