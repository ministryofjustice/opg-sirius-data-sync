#! /usr/bin/env sh
psql -U $PGUSER --dbname=$DATABASE_NAME --command='VACUUM VERBOSE ANALYSE;'
