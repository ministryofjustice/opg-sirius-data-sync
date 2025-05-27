#! /usr/bin/env bash

set -e
set -o pipefail

# Script Configuration
ENVIRONMENT_NAME=preprodglobal
DATABASE=api
DATABASE_CLUSTER=$DATABASE-$ENVIRONMENT_NAME
SNAPSHOT_COPY=$DATABASE_CLUSTER-snapshot-for-copy
TARGET_ACCOUNT_ID=492687888235

# SNAPSHOT NAME
SOURCE_SNAPSHOT=pre-migration-snapshot-$DATABASE-$(date +'%Y%m%d%H%M')


check_for_and_delete_snapshot() {
    SNAPSHOT=$1
    echo "INFO - Checking for existing snapshot"
    if aws rds describe-db-cluster-snapshots --db-cluster-snapshot-identifier "$SNAPSHOT"; then
        echo "INFO - Snapshot found, deleting"
        aws rds delete-db-cluster-snapshot \
            --db-cluster-snapshot-identifier "$SNAPSHOT"
        echo "INFO - Waiting for deletion to complete..."
        aws rds wait db-cluster-snapshot-deleted \
            --db-cluster-snapshot-identifier "$SNAPSHOT"
        echo "INFO - Snapshot $SNAPSHOT deleted."
    else
        echo "INFO - No snapshot found"
    fi
}

wait_for_snapshot_completion() {
    SNAPSHOT=$1
    RETRIES=${2:-1}
    echo "INFO - Waiting for snapshot $SNAPSHOT copy to complete..."
    if
        RETRY=0
        until [ $RETRY -ge $RETRIES ]
        do
            aws rds wait db-cluster-snapshot-available --db-cluster-snapshot-identifier "$SNAPSHOT" && break
            echo "INFO - Still waiting for snapshot $SNAPSHOT copy to complete..."
            RETRY=$[$RETRY+1]
            sleep 2
        done
    then
        echo "INFO - Snapshot copy $SNAPSHOT complete"
    else
        echo "ERROR - Snapshot copy $SNAPSHOT failed"
        exit 1
    fi
}


echo "INFO - Creating Snapshot $SOURCE_SNAPSHOT"
aws rds create-db-cluster-snapshot \
    --db-cluster-snapshot-identifier $SOURCE_SNAPSHOT\
    --db-cluster-identifier $DATABASE_CLUSTER

wait_for_snapshot_completion "$SOURCE_SNAPSHOT" 5

check_for_and_delete_snapshot "$SNAPSHOT_COPY"
echo "INFO - SNAPSHOT_COPY set to $SNAPSHOT_COPY"

echo "INFO - Creating snapshot copy $SNAPSHOT_COPY from snapshot $SOURCE_SNAPSHOT."
aws rds copy-db-cluster-snapshot \
    --source-db-cluster-snapshot-identifier "$SOURCE_SNAPSHOT" \
    --target-db-cluster-snapshot-identifier "$SNAPSHOT_COPY" \
    --kms-key-id "arn:aws:kms:eu-west-1:649098267436:alias/rds-snapshot-reencryption-production"

wait_for_snapshot_completion "$SNAPSHOT_COPY" 5

echo "INFO - Modifying snapshot to be shared with account $TARGET_ACCOUNT_ID"
aws rds modify-db-cluster-snapshot-attribute \
    --db-cluster-snapshot-identifier "$SNAPSHOT_COPY" \
    --attribute-name restore \
    --values-to-add "$TARGET_ACCOUNT_ID"
echo "INFO - Modification complete."
echo "INFO - Snapshot script complete"
