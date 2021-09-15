#! /usr/bin/env sh

set -e
set -o pipefail

if [ -z "$ENVIRONMENT" ]; then
    echo "ERROR - You need to set the ENVIRONMENT environment variable."
    exit 1
fi

export AWS_DEFAULT_REGION=eu-west-1
export BUCKET=db-backups.development.eu-west-1.sirius.opg.justice.gov.uk

function  backup_database_to_s3() {
    local db_name=$1
    local env=${ENVIRONMENT}
    local db_info=$(aws rds describe-db-clusters --db-cluster-identifier ${db_name}-${env})
    export PGDATABASE=$(echo $db_info | jq -r '.DBClusters[].DatabaseName')
    export PGUSER=$(echo $db_info | jq -r '.DBClusters[].MasterUsername')
    export PGHOST=$(echo $db_info | jq -r '.DBClusters[].Endpoint')
    export PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id rds-${db_name}-development | jq -r '.SecretString')
    echo "INFO - Backing up ${db_name} to local file ${env}-${db_name}-backup.sql"
    pg_dump --clean --if-exists > ${env}-${db_name}-backup.sql
    echo "INFO - Backup complete."
    echo "INFO - Uploading to s3://${BUCKET}/database/${env}-${db_name}-backup.sql"
    aws s3 cp --sse AES256 ${env}-${db_name}-backup.sql s3://${BUCKET}/database/${env}-${db_name}-backup.sql
    echo "INFO - Upload Complete"
}

function backup_documents_to_s3 {
    echo "INFO - Syncing s3://opg-backoffice-datastore-${ENVIRONMENT}/ to s3://${BUCKET}/documents/${ENVIRONMENT}/"
    aws s3 sync --sse AES256 s3://opg-backoffice-datastore-${ENVIRONMENT}/ s3://${BUCKET}/documents/${ENVIRONMENT}/
    echo "INFO - Sync Complete"
}

backup_database_to_s3 api
backup_database_to_s3 membrane
backup_documents_to_s3
