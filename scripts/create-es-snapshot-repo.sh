#! /usr/bin/env bash

set -e
set -o pipefail

if [ -z "$ENVIRONMENT_NAME" ]; then
    echo "ERROR - You need to set the ENVIRONMENT_NAME environment variable."
    exit 1
fi

if [ -z "$ACCOUNT_ID" ]; then
    echo "ERROR - You need to set the ACCOUNT_ID environment variable."
    exit 1
fi

if [ -z "$ES_SNAPSHOT_BUCKET" ]; then
    echo "ERROR - You need to set the ES_SNAPSHOT_BUCKET environment variable."
    exit 1
fi

if [ -z "$ES_VPC_ENDPOINT" ]; then
    echo "ERROR - You need to set the ES_VPC_ENDPOINT environment variable."
    exit 1
fi

if [ -z "$IAM_ROLE_NAME" ]; then
    echo "ERROR - You need to set the IAM_ROLE_NAME environment variable."
    exit 1
fi

if [ -z "$ES_SNAPSHOT_REPO" ]; then
    echo "ERROR - You need to set the ES_SNAPSHOT_REPO environment variable."
    exit 1
fi

if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "ERROR - You need to set the AWS_REGION environment variable."
    exit 1
fi

echo "INFO - ENVIRONMENT_NAME set to $ENVIRONMENT_NAME"
echo "INFO - ES_SNAPSHOT_BUCKET set to $ES_SNAPSHOT_BUCKET"
echo "INFO - ES_VPC_ENDPOINT set to $ES_VPC_ENDPOINT"
echo "INFO - IAM_ROLE_NAME set to $IAM_ROLE_NAME"
echo "INFO - ES_SNAPSHOT_REPO set to $ES_SNAPSHOT_REPO"
echo "INFO - AWS_DEFAULT_REGION set to $AWS_DEFAULT_REGION"

echo "INFO - Ensure Elasticsearch Snapshot Repository Exists..."
if python3 create-es-snapshot-repo.py; then
    echo "INFO - Elasticsearch Snapshot Repository Exists."
else
    echo "ERROR - Elasticsearch Snapshot Repository Creation Failed."
    exit 1
fi
