#! /usr/bin/env bash

set -e
set -o pipefail

if [ -z "$ENVIRONMENT" ]; then
    echo "ERROR - You need to set the ENVIRONMENT environment variable."
    exit 1
fi

if [ -z "$RESTORE_FROM_TRAINING_DATA" ]; then
    echo "ERROR - You need to set the ENVIRONMENT environment variable."
    exit 1
fi

if [ "$RESTORE_FROM_TRAINING_DATA" == "true" ]; then
    echo "INFO - Restoring from training-data seeding env"
    export SOURCE_ENVIRONMENT=training-data
elif [ -n "$CUSTOM_ENV_TO_RESTORE_FROM" ]; then
    export SOURCE_ENVIRONMENT=$CUSTOM_ENV_TO_RESTORE_FROM
else 
    export SOURCE_ENVIRONMENT=$ENVIRONMENT
fi
echo "INFO - Restoring from $SOURCE_ENVIRONMENT"

export AWS_DEFAULT_REGION=eu-west-1
export BUCKET=db-backups.development.eu-west-1.sirius.opg.justice.gov.uk

function  restore_database_from_s3() {
    local db_name=$1
    local target_env=${ENVIRONMENT}
    local source_env=${SOURCE_ENVIRONMENT}
    echo "INFO - Downloading from s3://${BUCKET}/database/${source_env}-${db_name}-backup.sql"
    aws s3 cp s3://${BUCKET}/database/${source_env}-${db_name}-backup.sql ${target_env}-${db_name}-backup.sql
    echo "INFO - Download Complete"

    local db_info=$(aws rds describe-db-clusters --db-cluster-identifier ${db_name}-${target_env})
    export PGDATABASE=$(echo $db_info | jq -r '.DBClusters[].DatabaseName')
    export PGUSER=$(echo $db_info | jq -r '.DBClusters[].MasterUsername')
    export PGHOST=$(echo $db_info | jq -r '.DBClusters[].Endpoint')
    export PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id rds-${db_name}-development | jq -r '.SecretString')
    echo "INFO - Restoring local file ${target_env}-${db_name}-backup.sql to ${db_name}"
    echo "INFO - Dropping & Recreating poa Schema"
    psql -c 'DROP SCHEMA poa CASCADE;'
    psql -c 'CREATE SCHEMA poa;'
    echo "INFO - Dropping & Recreating public Schema"
    psql -c 'DROP SCHEMA public CASCADE;'
    psql -c 'CREATE SCHEMA public;'
    echo "INFO - Dropping & Recreating supervision Schema"
    psql -c 'DROP SCHEMA supervision CASCADE;'
    psql -c 'CREATE SCHEMA supervision;'
    echo "INFO - Dropping & Recreating supervision_finance Schema"
    psql -c 'DROP SCHEMA supervision_finance CASCADE;'
    psql -c 'CREATE SCHEMA supervision_finance;'
    psql -f ${target_env}-${db_name}-backup.sql
    echo "INFO - Restore complete."
}

function restore_documents_from_s3 {
    echo "INFO - Syncing s3://${BUCKET}/documents/${SOURCE_ENVIRONMENT}/ to s3://opg-backoffice-datastore-${ENVIRONMENT}/"
    aws s3 sync --sse AES256 s3://${BUCKET}/documents/${SOURCE_ENVIRONMENT}/ s3://opg-backoffice-datastore-${ENVIRONMENT}/
    echo "INFO - Sync Complete"
}

restore_database_from_s3 api
restore_documents_from_s3
