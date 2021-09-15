#! /usr/bin/env sh

set -e
set -o pipefail

. common.sh

if [ "$ENVIRONMENT_NAME" = "production" ]; then
    echo "ERROR - You cannot delete the production database."
    exit 1
fi

. restore-database-methods.sh

echo "INFO - Checking if backup cluster exists"
if aws rds describe-db-clusters --db-cluster-identifier "$BACKUP_CLUSTER"; then
    echo "INFO - Existing backup cluster found - deleting"
    echo "INFO - Removing Deletion Protection"
    aws rds modify-db-cluster \
        --db-cluster-identifier $BACKUP_CLUSTER \
        --no-deletion-protection \
        --apply-immediately
    echo "INFO - Deleting Cluster Instances"
    delete_db_instance $BACKUP_CLUSTER-0
    delete_db_instance $BACKUP_CLUSTER-1
    delete_db_instance $BACKUP_CLUSTER-2
    wait_for_db_instance_deleted $BACKUP_CLUSTER-0
    wait_for_db_instance_deleted $BACKUP_CLUSTER-1
    wait_for_db_instance_deleted $BACKUP_CLUSTER-2
    echo "INFO - Deleting Cluster"
    aws rds delete-db-cluster \
        --db-cluster-identifier "$BACKUP_CLUSTER" \
        --skip-final-snapshot
    wait_for_db_cluster_deleted "$BACKUP_CLUSTER"
else
    echo "INFO - No backup cluster found"
fi
