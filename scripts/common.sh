#! /usr/bin/env bash

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
  DATABASE_VERSION="13.7"
fi

if [ -z "$PARAMETER_GROUP" ]; then
  PARAMETER_GROUP="default.aurora-postgresql13"
fi

echo "INFO - Database Version set to $DATABASE_VERSION"
DATABASE_CLUSTER=$DATABASE-$ENVIRONMENT_NAME
echo "INFO - DATABASE_CLUSTER set to $DATABASE_CLUSTER"

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

check_look_up_exists() {
    LOOKUP=$1
    if [ "$LOOKUP" = "None" ]
    then
        echo "ERROR - Lookup value not found exiting."
        exit 1
    fi
}

check_snapshot_exists() {
    SNAPSHOT=$1
    echo "INFO - Checking source snapshot exists"
    if aws rds describe-db-cluster-snapshots --include-shared --db-cluster-snapshot-identifier "$SNAPSHOT"; then
        echo "INFO - Snapshot $SNAPSHOT found."
    else
        echo "ERROR - Snapshot $SNAPSHOT not found exiting."
        exit 1
    fi
}

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

wait_for_db_cluster_deleted() {
    CLUSTER=$1
    echo "INFO - Waiting for $CLUSTER to be deleted"
    while aws rds describe-db-clusters --db-cluster-identifier $CLUSTER;
    do
        echo "Waiting for Cluster Deletion"
        sleep 60
    done
    echo "INFO - $CLUSTER deleted"
}

wait_for_db_instance_available() {
    INSTANCE=$1
    RETRIES=${2:-1}
    RETRY=0
    echo "INFO - Waiting for $INSTANCE modification to complete..."
    until [ $RETRY -ge $RETRIES ]
    do
        aws rds wait db-instance-available --db-instance-identifier "$INSTANCE" && break
        echo "INFO - Still waiting for $INSTANCE modification to complete..."
        RETRY=$[$RETRY+1]
        sleep 2
    done
    echo "INFO - Modification of $INSTANCE complete"
}

wait_for_db_instance_deleted() {
    INSTANCE=$1
    RETRIES=${2:-1}
    RETRY=0
    echo "INFO - Waiting for $INSTANCE to be deleted..."
    until [ $RETRY -ge $RETRIES ]
    do
        aws rds wait db-instance-deleted --db-instance-identifier "$INSTANCE" && break
        echo "INFO - Still waiting for $INSTANCE to be deleted..."
        RETRY=$[$RETRY+1]
        sleep 2
    done
    echo "INFO - Deletion of $INSTANCE complete"
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
