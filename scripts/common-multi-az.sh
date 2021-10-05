#! /usr/bin/env sh

set -e
set -o pipefail

if [ -z "$ENVIRONMENT_NAME" ]; then
    echo "ERROR - You need to set the ENVIRONMENT_NAME environment variable."
    exit 1
fi

if [ -z "$DATABASE" ]; then
    echo "ERROR - You need to set the DATABASE environment variable."
    exit 1
fi

if [ -z "$DATABASE_VERSION" ]; then
  DATABASE_VERSION="10.14"
fi

check_for_and_delete_snapshot() {
    REGION=$1
    SNAPSHOT=$2
    echo "INFO - Checking for existing snapshot"
    if aws rds describe-db-cluster-snapshots --region $REGION --db-cluster-snapshot-identifier "$SNAPSHOT"; then
        echo "INFO - Snapshot found, deleting"
        aws rds delete-db-cluster-snapshot \
            --region $REGION \
            --db-cluster-snapshot-identifier "$SNAPSHOT"
        echo "INFO - Waiting for deletion to complete..."
        aws rds wait db-cluster-snapshot-deleted \
            --region $REGION \
            --db-cluster-snapshot-identifier "$SNAPSHOT"
        echo "INFO - Snapshot $SNAPSHOT deleted."
    else
        echo "INFO - No snapshot found"
    fi
}

check_look_up_exists() {
    LOOKUP=$1
    if [ "$LOOKUP" = "None" ]
    then
        echo "ERROR - Lookup value not found exiting."
        exit 1
    fi
}

check_snapshot_exists() {
    REGION=$1
    SNAPSHOT=$2
    echo "INFO - Checking source snapshot exists"
    if aws rds describe-db-cluster-snapshots --region $REGION --include-shared --db-cluster-snapshot-identifier "$SNAPSHOT"; then
        echo "INFO - Snapshot $SNAPSHOT found."
    else
        echo "ERROR - Snapshot $SNAPSHOT not found exiting."
        exit 1
    fi
}

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

wait_for_db_cluster_deleted() {
    REGION=$1
    CLUSTER=$2
    echo "INFO - Waiting for $CLUSTER to be deleted"
    while aws rds describe-db-clusters --region $REGION --db-cluster-identifier $CLUSTER;
    do
        echo "Waiting for Cluster Deletion"
        sleep 60
    done
    echo "INFO - $CLUSTER deleted"
}

wait_for_global_cluster_deleted() {
    REGION=$1
    CLUSTER=$2
    echo "INFO - Waiting for $CLUSTER to be deleted"
    while aws rds describe-global-clusters --region $REGION --global-cluster-identifier $CLUSTER;
    do
        echo "Waiting for Cluster Deletion"
        sleep 60
    done
    echo "INFO - $CLUSTER deleted"
}

wait_for_db_instance_available() {
    REGION=$1
    INSTANCE=$2
    RETRIES=${3:-1}
    RETRY=0
    echo "INFO - Waiting for $INSTANCE modification to complete..."
    until [ $RETRY -ge $RETRIES ]
    do
        aws rds wait db-instance-available --region $REGION --db-instance-identifier "$INSTANCE" && break
        echo "INFO - Still waiting for $INSTANCE modification to complete..."
        RETRY=$[$RETRY+1]
        sleep 2
    done
    echo "INFO - Modification of $INSTANCE complete"
}

wait_for_db_instance_deleted() {
    REGION=$1
    INSTANCE=$2
    RETRIES=${3:-1}
    RETRY=0
    echo "INFO - Waiting for $INSTANCE to be deleted..."
    until [ $RETRY -ge $RETRIES ]
    do
        aws rds wait db-instance-deleted --region $REGION --db-instance-identifier "$INSTANCE" && break
        echo "INFO - Still waiting for $INSTANCE to be deleted..."
        RETRY=$[$RETRY+1]
        sleep 2
    done
    echo "INFO - Deletion of $INSTANCE complete"
}

wait_for_snapshot_completion() {
    REGION=$1
    SNAPSHOT=$2
    RETRIES=${3:-1}
    echo "INFO - Waiting for snapshot $SNAPSHOT copy to complete..."
    if
        RETRY=0
        until [ $RETRY -ge $RETRIES ]
        do
            aws rds wait db-cluster-snapshot-available --region $REGION --db-cluster-snapshot-identifier "$SNAPSHOT" && break
            echo "INFO - Still waiting for snapshot $SNAPSHOT copy to complete..."
            RETRY=$[$RETRY+1]
            sleep 2
        done
    then
        echo "INFO - Snapshot $SNAPSHOT complete"
    else
        echo "ERROR - Snapshot $SNAPSHOT failed"
        exit 1
    fi
}
