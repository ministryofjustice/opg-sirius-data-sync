#! /usr/bin/env bash

# Required Environment Variables
# ACCOUNT_NAME=preproduction
# AWS_DEFAULT_REGION=eu-west-1
# DATABASE=api
# ENVIRONMENT_NAME=preproduction

set -e
set -o pipefail

. common.sh

if [ -z "$ACCOUNT_NAME" ]; then
    echo "ERROR - You need to set the ACCOUNT_NAME environment variable."
    exit 1
fi

if [ -z "$SKIP_SNAPSHOT" ]; then
  SKIP_SNAPSHOT="false"
fi

. restore-database-methods.sh
DATABASE_CLUSTER=$DATABASE-$ENVIRONMENT_NAME
echo "INFO - DATABASE_CLUSTER set to $DATABASE_CLUSTER"

# Lookup Current Database Engine Version
DATABASE_VERSION=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].EngineVersion \
    --output text)
check_look_up_exists "$DATABASE_VERSION"

# Lookup Current Cluster Parameter Group
PARAMETER_GROUP=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].DBClusterParameterGroup \
    --output text)
check_look_up_exists "$PARAMETER_GROUP"

# Lookup RDS Password
RDS_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "rds-$DATABASE-$ACCOUNT_NAME" \
    --query=SecretString \
    --output text)
check_look_up_exists "$RDS_PASSWORD"

echo "INFO - Database Version set to $DATABASE_VERSION"

echo "INFO - Restoring $DATABASE_CLUSTER from $LOCAL_SNAPSHOT"
echo "INFO - Removing Deletion Protection"
aws rds modify-db-cluster \
    --db-cluster-identifier $DATABASE_CLUSTER \
    --no-deletion-protection \
    --apply-immediately

INSTANCES=$(aws rds describe-db-clusters --db-cluster-identifier $DATABASE_CLUSTER | jq -r "[.DBClusters[0].DBClusterMembers[].DBInstanceIdentifier]|sort|.[]")
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
    echo "Creating Cluster Instance $INSTANCE in eu-west-1${AZ_ZONES[$POSITION]}"
    create_db_instance $DATABASE_CLUSTER $INSTANCE eu-west-1${AZ_ZONES[$POSITION]} $INSTANCE_CLASS
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
