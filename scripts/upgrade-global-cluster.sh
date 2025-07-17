#! /usr/bin/env bash

set -e
set -o pipefail

wait_for_db_cluster_available() {
    REGION=$1
    CLUSTER=$2
    STATUS=unknown
    echo "INFO - Waiting for $CLUSTER modification to complete..."
    while [ "$STATUS" != "available" ]
    do
        sleep 60
        STATUS=$(aws rds describe-db-clusters --region $REGION --db-cluster-identifier $CLUSTER --query=DBClusters[0].Status --output text)
    done
    echo "INFO - Modification of $CLUSTER complete"
}

wait_for_global_cluster_available() {
    REGION=$1
    CLUSTER=$2
    STATUS=unknown
    echo "INFO - Waiting for $CLUSTER modification to complete..."
    while [ "$STATUS" != "available" ]
    do
        sleep 60
        STATUS=$(aws rds describe-global-clusters --region $REGION --global-cluster-identifier $CLUSTER --query=GlobalClusters[0].Status --output text)
    done
    echo "INFO - Modification of $CLUSTER complete"
}

if [ -z "$ENVIRONMENT_NAME" ]; then
    echo "ERROR - You need to set the ENVIRONMENT_NAME environment variable."
    exit 1
fi

if [ "$ENVIRONMENT_NAME" = "production" ]; then
    echo "ERROR - You cannot upgrade the Production global database cluster."
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


GLOBAL_CLUSTER=$ENVIRONMENT_NAME-$DATABASE-global
echo "INFO - GLOBAL_CLUSTER set to $GLOBAL_CLUSTER"
echo "INFO - Database Target Version set to $TARGET_VERSION"
echo "INFO - Upgrading Database Cluster $GLOBAL_CLUSTER to PostgreSQL $TARGET_VERSION"

# aws rds modify-global-cluster --global-cluster-identifier $GLOBAL_CLUSTER \
#     --allow-major-version-upgrade \
#     --engine-version $TARGET_VERSION

REGIONAL_CLUSTER=$DATABASE-$ENVIRONMENT_NAME
wait_for_global_cluster_available "eu-west-1" $GLOBAL_CLUSTER 
echo "INFO - Global Cluster Available"
echo "INFO - Wait for Regional Clusters to Upgrade"
wait_for_db_cluster_available "eu-west-1" $REGIONAL_CLUSTER 
wait_for_db_cluster_available "eu-west-2" $REGIONAL_CLUSTER 

echo "INFO - Updating eu-west-1 Cluster Parameter Groups"
aws rds modify-db-cluster --db-cluster-identifier $REGIONAL_CLUSTER \
    --db-cluster-parameter-group-name aurora-postgresql$TARGET_VERSION-ssl \
    --db-instance-parameter-group-name default.aurora-postgresql$TARGET_VERSION \
    --region "eu-west-1" \
    --apply-immediately
wait_for_db_cluster_available "eu-west-1" $REGIONAL_CLUSTER 
echo "INFO - eu-west-1 Cluster Update Complete"

echo "INFO - Updating eu-west-2 Cluster Parameter Groups"
aws rds modify-db-cluster --db-cluster-identifier $REGIONAL_CLUSTER \
    --db-cluster-parameter-group-name aurora-postgresql$TARGET_VERSION-ssl \
    --db-instance-parameter-group-name default.aurora-postgresql$TARGET_VERSION \
    --region "eu-west-2" \
    --apply-immediately
wait_for_db_cluster_available "eu-west-2" $REGIONAL_CLUSTER 
echo "INFO - eu-west-2 Cluster Update Complete"

echo "INFO - Global Database Cluster Upgrade Complete"
