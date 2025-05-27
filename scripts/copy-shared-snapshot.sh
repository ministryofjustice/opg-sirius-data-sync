#! /usr/bin/env bash

set -e
set -o pipefail

. common.sh

if [ -z "$SOURCE_ENVIRONMENT_NAME" ]; then
    echo "ERROR - You need to set the SOURCE_ENVIRONMENT_NAME environment variable."
    exit 1
fi

if [ -z "$SOURCE_ACCOUNT_ID" ]; then
    echo "ERROR - You need to set the SOURCE_ACCOUNT_ID environment variable."
    exit 1
fi

LOCAL_SNAPSHOT=$DATABASE_CLUSTER-snapshot-for-restore
echo "INFO - LOCAL_SNAPSHOT set to $LOCAL_SNAPSHOT"

REMOTE_SNAPSHOT=arn:aws:rds:eu-west-1:$SOURCE_ACCOUNT_ID:cluster-snapshot:$DATABASE-$SOURCE_ENVIRONMENT_NAME-snapshot-for-copy
echo "INFO - REMOTE_SNAPSHOT set to $REMOTE_SNAPSHOT"

check_snapshot_exists "$REMOTE_SNAPSHOT"

check_for_and_delete_snapshot "$LOCAL_SNAPSHOT"

echo "INFO - Creating local snapshot copy"
aws rds copy-db-cluster-snapshot \
    --source-db-cluster-snapshot-identifier "$REMOTE_SNAPSHOT" \
    --target-db-cluster-snapshot-identifier "$LOCAL_SNAPSHOT" \
    --kms-key-id alias/aws/rds

wait_for_snapshot_completion "$LOCAL_SNAPSHOT" 5
