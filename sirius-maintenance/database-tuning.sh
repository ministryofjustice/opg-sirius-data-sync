#! /usr/bin/env bash
psql -U $PGUSER --dbname=$DATABASE_NAME --command='VACUUM VERBOSE ANALYSE;'
