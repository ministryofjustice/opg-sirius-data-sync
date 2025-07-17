#! /usr/bin/env bash

set -e
set -o pipefail

wait_for_db_cluster_available() {
    CLUSTER=$1
    STATUS=unknown
    echo "INFO - Waiting for $CLUSTER modification to complete..."
    while [ "$STATUS" != "available" ]
    do
        sleep 60
        STATUS=$(aws rds describe-db-clusters --db-cluster-identifier $CLUSTER --query=DBClusters[0].Status --output text)
    done
    echo "INFO - Modification of $CLUSTER complete"
}

if [ -z "$ENVIRONMENT_NAME" ]; then
    echo "ERROR - You need to set the ENVIRONMENT_NAME environment variable."
    exit 1
fi

if [ "$ENVIRONMENT_NAME" = "production" ] || [ "$ENVIRONMENT_NAME" = "preproduction" ] || [ "$ENVIRONMENT_NAME" = "dev" ]; then
    echo "ERROR - You cannot upgrade the $ENVIRONMENT_NAME global database cluster."
    exit 1
fi

if [ -z "$DATABASE" ]; then
    echo "ERROR - You need to set the DATABASE environment variable."
    exit 1
fi

if [ -z "$TARGET_VERSION" ]; then
    echo "ERROR - You need to set the TARGET_VERSION environment variable."
    exit 1
fi


DATABASE_CLUSTER=$DATABASE-$ENVIRONMENT_NAME
echo "INFO - DATABASE_CLUSTER set to $DATABASE_CLUSTER"
echo "INFO - Database Target Version set to $TARGET_VERSION"
echo "INFO - Upgrading Database Cluster $DATABASE_CLUSTER to PostgreSQL $TARGET_VERSION"

aws rds modify-db-cluster --db-cluster-identifier $DATABASE_CLUSTER \
    --allow-major-version-upgrade \
    --engine-version $TARGET_VERSION \
    --db-cluster-parameter-group-name aurora-postgresql$TARGET_VERSION-ssl \
    --db-instance-parameter-group-name default.aurora-postgresql$TARGET_VERSION \
    --apply-immediately

wait_for_db_cluster_available $DATABASE_CLUSTER
echo "INFO - Database Upgrade Complete"
