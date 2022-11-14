#! /usr/bin/env sh

# Required Environment Variables
# ACCOUNT_NAME=preproduction
# AWS_DEFAULT_REGION=eu-west-1
# DATABASE=api
# ENVIRONMENT_NAME=preproduction

# Optional Envionment Variables
# CLUSTER_NODES=3
# SKIP_SNAPSHOT=false
# DATABASE_VERSION=13.6

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

if [ -z "$SKIP_SNAPSHOT" ]; then
  SKIP_SNAPSHOT="false"
fi

if [ -z "$CLUSTER_NODES" ]; then
  CLUSTER_NODES="3"
fi

. restore-database-methods.sh

echo "INFO - Restoring $DATABASE_CLUSTER from $LOCAL_SNAPSHOT"
echo "INFO - Removing Deletion Protection"
aws rds modify-db-cluster \
    --db-cluster-identifier $DATABASE_CLUSTER \
    --no-deletion-protection \
    --apply-immediately

if [ "$CLUSTER_NODES" == "1" ]; then
    echo "INFO - Deleting Single AZ Instance"
    delete_db_instance $DATABASE_CLUSTER-0
    wait_for_db_instance_deleted $DATABASE_CLUSTER-0
else
    echo "INFO - Deleting Multi AZ Instances"
    delete_db_instance $DATABASE_CLUSTER-0
    delete_db_instance $DATABASE_CLUSTER-1
    delete_db_instance $DATABASE_CLUSTER-2
    wait_for_db_instance_deleted $DATABASE_CLUSTER-0
    wait_for_db_instance_deleted $DATABASE_CLUSTER-1
    wait_for_db_instance_deleted $DATABASE_CLUSTER-2
fi

echo "INFO - Deleting Cluster"
if [ "$SKIP_SNAPSHOT" == "true" ]; then
    echo "INFO - Deleting Cluster without final snapshot"
    aws rds delete-db-cluster \
        --db-cluster-identifier "$DATABASE_CLUSTER" \
        --skip-final-snapshot
    wait_for_db_cluster_deleted "$DATABASE_CLUSTER"
else
    echo "INFO - Deleting Cluster with final snapshot"
    check_for_and_delete_snapshot $DATABASE_CLUSTER-final-snapshot
    aws rds delete-db-cluster \
        --db-cluster-identifier $DATABASE_CLUSTER \
        --no-skip-final-snapshot \
        --final-db-snapshot-identifier $DATABASE_CLUSTER-final-snapshot
    wait_for_snapshot_completion $DATABASE_CLUSTER-final-snapshot
    wait_for_db_cluster_deleted $DATABASE_CLUSTER
fi

echo "INFO - Restoring $DATABASE_CLUSTER from $LOCAL_SNAPSHOT"
aws rds restore-db-cluster-from-snapshot \
    --db-cluster-identifier "$DATABASE_CLUSTER" \
    --snapshot-identifier "$LOCAL_SNAPSHOT" \
    --engine aurora-postgresql \
    --engine-version "$DATABASE_VERSION" \
    --vpc-security-group-ids "$SECURITY_GROUP" \
    --db-subnet-group-name "$SUBNET_GROUP" \
    --db-cluster-parameter-group-name "$PARAMETER_GROUP" \
    --deletion-protection \
    --enable-cloudwatch-logs-exports postgresql \
    --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=$SERVERLESS_MAX_CAPACITY
wait_for_db_cluster_available "$DATABASE_CLUSTER"

if [ "$CLUSTER_NODES" == "1" ]; then
    echo "INFO - Creating Single AZ Instance for $DATABASE_CLUSTER"
    create_db_instance $DATABASE_CLUSTER $DATABASE_CLUSTER-0 eu-west-1a
    wait_for_db_instance_available $DATABASE_CLUSTER-0
else
    echo "INFO - Creating Multi AZ Instances for $DATABASE_CLUSTER"
    create_db_instance $DATABASE_CLUSTER $DATABASE_CLUSTER-0 eu-west-1a $WRITER_INSTANCE_CLASS
    create_db_instance $DATABASE_CLUSTER $DATABASE_CLUSTER-1 eu-west-1b $READER_INSTANCE_CLASS
    create_db_instance $DATABASE_CLUSTER $DATABASE_CLUSTER-2 eu-west-1c $READER_INSTANCE_CLASS
    wait_for_db_instance_available $DATABASE_CLUSTER-0
    wait_for_db_instance_available $DATABASE_CLUSTER-1
    wait_for_db_instance_available $DATABASE_CLUSTER-2
fi

echo "INFO - Reset Database Password"
aws rds modify-db-cluster --db-cluster-identifier "$DATABASE_CLUSTER" \
    --apply-immediately \
    --master-user-password "$RDS_PASSWORD"
wait_for_db_cluster_available "$DATABASE_CLUSTER"

echo "INFO - Update cluster tags"
aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
    --tags Key=account,Value="$ACCOUNT_NAME"
aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
    --tags Key=environment-name,Value="$ENVIRONMENT_NAME"
aws rds add-tags-to-resource --resource-name "$CLUSTER_ARN" \
    --tags Key=is-production,Value="false"

echo "INFO - Database restore Complete!"
