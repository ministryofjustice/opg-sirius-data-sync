#! /usr/bin/env sh

# Required Environment Variables
# ACCOUNT_NAME=preproduction
# AWS_DEFAULT_REGION=eu-west-1
# DATABASE=api
# ENVIRONMENT_NAME=preproduction

# Optional Envionment Variables
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

. restore-database-methods.sh

echo "INFO - Restoring $DATABASE_CLUSTER from $LOCAL_SNAPSHOT"
echo "INFO - Removing Deletion Protection"
aws rds modify-db-cluster \
    --db-cluster-identifier $DATABASE_CLUSTER \
    --no-deletion-protection \
    --apply-immediately

INSTANCES=$(aws rds describe-db-clusters --db-cluster-identifier $DATABASE_CLUSTER | jq "[.DBClusters[0].DBClusterMembers[].DBInstanceIdentifier]|sort|.[]")
echo "INFO - Cluster Instances:-"
echo "INFO - $INSTANCES"

echo "INFO - Deleting Cluster Instances"
for INSTANCE in $INSTANCES
do
    delete_db_instance $INSTANCE
done

echo "INFO - Waiting for Deletion to Complete"
for INSTANCE in $INSTANCES
do
    wait_for_db_instance_deleted $INSTANCE
done

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
    --serverless-v2-scaling-configuration MinCapacity=$SERVERLESS_MIN_CAPACITY,MaxCapacity=$SERVERLESS_MAX_CAPACITY
wait_for_db_cluster_available "$DATABASE_CLUSTER"

AZ_ZONES=(a b c)
echo "INFO - Creating Multi AZ Instances for $DATABASE_CLUSTER"
POSITION=0
for INSTANCE in $INSTANCES
do
    echo "Creating Cluster Instance $INSTANCE in eu-west-${AZ_ZONES[$POSITION]}"
    create_db_instance $DATABASE_CLUSTER $INSTANCE eu-west-${AZ_ZONES[$POSITION]}
    POSITION=$[$POSITION+1]
done

echo "INFO - Waiting for Instance Creation to Complete"
for INSTANCE in $INSTANCES
do
    wait_for_db_instance_available $INSTANCE
done

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
