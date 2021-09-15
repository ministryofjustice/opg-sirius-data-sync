#! /usr/bin/env sh

set -e
set -o pipefail

. common.sh

if [ "$ENVIRONMENT_NAME" = "production" ]; then
    echo "ERROR - You cannot restore the production database."
    exit 1
fi

if [ -z "$ACCOUNT_NAME" ]; then
    echo "ERROR - You need to set the ACCOUNT_NAME environment variable."
    exit 1
fi

. restore-database-methods.sh

echo "INFO - Backing up existing database cluster"
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
    wait_for_db_instance_deleted $BACKUP_CLUSTER-0
    echo "INFO - Deleting Cluster"
    aws rds delete-db-cluster \
        --db-cluster-identifier "$BACKUP_CLUSTER" \
        --skip-final-snapshot
    wait_for_db_cluster_deleted "$BACKUP_CLUSTER"
else
    echo "INFO - No backup instance found"
fi

echo "INFO - Renaming $DATABASE_CLUSTER to $BACKUP_CLUSTER"
aws rds modify-db-cluster \
    --db-cluster-identifier "$DATABASE_CLUSTER" \
    --new-db-cluster-identifier "$BACKUP_CLUSTER" \
    --apply-immediately
rename_db_instance "$DATABASE_CLUSTER-0" "$BACKUP_CLUSTER-0"
wait_for_db_instance_deleted "$DATABASE_CLUSTER-0"
wait_for_db_instance_available "$BACKUP_CLUSTER-0"
wait_for_db_cluster_available "$BACKUP_CLUSTER"
echo "INFO - Backup of Cluster $DATABASE_CLUSTER to $BACKUP_CLUSTER Complete"

echo "INFO - Restoring $DATABASE_CLUSTER from $LOCAL_SNAPSHOT"
aws rds restore-db-cluster-from-snapshot \
    --db-cluster-identifier "$DATABASE_CLUSTER" \
    --snapshot-identifier "$LOCAL_SNAPSHOT" \
    --engine aurora-postgresql \
    --engine-version "$DATABASE_VERSION" \
    --vpc-security-group-ids "$SECURITY_GROUP" \
    --db-subnet-group-name "$SUBNET_GROUP" \
    --deletion-protection \
    --enable-cloudwatch-logs-exports postgresql
wait_for_db_cluster_available "$DATABASE_CLUSTER"

echo "INFO - Creating Cluster Instances for $DATABASE_CLUSTER"
create_db_instance $DATABASE_CLUSTER $DATABASE_CLUSTER-0 eu-west-1a
wait_for_db_instance_available $DATABASE_CLUSTER-0

echo "INFO - Reset Database Password"
aws rds modify-db-cluster --db-cluster-identifier "$DATABASE_CLUSTER" \
    --apply-immediately \
    --master-user-password "$RDS_PASSWORD"
wait_for_db_cluster_available "$DATABASE_CLUSTER"


echo "INFO - Update cluster tags"
aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
    --tags Key=account,Value="$ENVIRONMENT_NAME"
aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
    --tags Key=environment-name,Value="$ENVIRONMENT_NAME"
aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
    --tags Key=is-production,Value="false"
# We don't Tag Aurora Resources with Name Yet
# aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
#     --tags Key=Name,Value="$DATABASE-$ENVIRONMENT_NAME"

echo "INFO - Database restore Complete!"
