#! /usr/bin/env sh

set -e
set -o pipefail

. common.sh

if [ -z "$TARGET_ACCOUNT_ID" ]; then
    echo "ERROR - You need to set the TARGET_ACCOUNT_ID environment variable."
    exit 1
fi

SNAPSHOT_COPY=$DATABASE_CLUSTER-snapshot-for-copy
echo "INFO - SNAPSHOT_COPY set to $SNAPSHOT_COPY"

echo "INFO - Checking for automated snapshot of $DATABASE_CLUSTER"
LATEST_SNAPSHOT=$(aws rds describe-db-cluster-snapshots \
    --db-cluster-identifier "$DATABASE_CLUSTER" \
    --filter Name=snapshot-type,Values=automated \
    --query="reverse(sort_by(DBClusterSnapshots, &SnapshotCreateTime))[0]|DBClusterSnapshotIdentifier" \
    --output text)

if [ "$LATEST_SNAPSHOT" = "None" ]; then
    echo "ERROR - No automated snapshot's found for $DATABASE_CLUSTER."
    exit 1;
else
    echo "INFO - Latest snapshot found: $LATEST_SNAPSHOT"
fi

check_for_and_delete_snapshot "$SNAPSHOT_COPY"

echo "INFO - Creating snapshot copy $SNAPSHOT_COPY from snapshot $LATEST_SNAPSHOT."
aws rds copy-db-cluster-snapshot \
    --source-db-cluster-snapshot-identifier "$LATEST_SNAPSHOT" \
    --target-db-cluster-snapshot-identifier "$SNAPSHOT_COPY" \
    --kms-key-id alias/rds-snapshot-reencryption-"$ENVIRONMENT_NAME"

wait_for_snapshot_completion "$SNAPSHOT_COPY" 5

echo "INFO - Modifying snapshot to be shared with account $TARGET_ACCOUNT_ID"
aws rds modify-db-cluster-snapshot-attribute \
    --db-cluster-snapshot-identifier "$SNAPSHOT_COPY" \
    --attribute-name restore \
    --values-to-add "$TARGET_ACCOUNT_ID"
echo "INFO - Modification complete."
echo "INFO - Snapshot script complete"
