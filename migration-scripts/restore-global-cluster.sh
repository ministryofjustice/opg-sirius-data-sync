#! /usr/bin/env sh

set -e
set -o pipefail

# SNAPSHOT NAME
SNAPSHOT_FOR_RESTORE=pre-migration-snapshot-api-202201260915

# Script Configuration
ACCOUNT_NAME=preproduction
DATABASE=api
ENVIRONMENT_NAME=preprodglobal
PRIMARY_REGION=eu-west-1
DR_REGION=eu-west-2


if [ "$ENVIRONMENT_NAME" = "production" ]; then
    echo "ERROR - You cannot restore the production database."
    exit 1
fi

GLOBAL_CLUSTER=$ENVIRONMENT_NAME-$DATABASE-global
REGIONAL_CLUSTER=$DATABASE-$ENVIRONMENT_NAME

if [ -z "$DATABASE_VERSION" ]; then
  DATABASE_VERSION="10.20"
fi

if [ -z "$PARAMETER_GROUP" ]; then
  PARAMETER_GROUP="default.aurora-postgresql10"
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


# Lookup RDS Password
RDS_PASSWORD=$(aws secretsmanager get-secret-value \
    --region $PRIMARY_REGION \
    --secret-id "rds-$DATABASE-$ACCOUNT_NAME" \
    --query=SecretString \
    --output text)
check_look_up_exists "$RDS_PASSWORD"

# Lookup Primary Region Cluster ARN
PRIMARY_CLUSTER_ARN=$(aws rds describe-db-clusters \
    --region $PRIMARY_REGION \
    --db-cluster-identifier "$REGIONAL_CLUSTER" \
    --query=DBClusters[0].DBClusterArn \
    --output text)
check_look_up_exists "$PRIMARY_CLUSTER_ARN"

# Lookup DR Region Cluster ARN
DR_CLUSTER_ARN=$(aws rds describe-db-clusters \
    --region $DR_REGION \
    --db-cluster-identifier "$REGIONAL_CLUSTER" \
    --query=DBClusters[0].DBClusterArn \
    --output text)
check_look_up_exists "$DR_CLUSTER_ARN"

# Lookup Primary Region DB Security Group
PRIMARY_SECURITY_GROUP=$(aws rds describe-db-clusters \
    --region $PRIMARY_REGION \
    --db-cluster-identifier "$PRIMARY_CLUSTER_ARN" \
    --query=DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId \
    --output text)
check_look_up_exists "$PRIMARY_SECURITY_GROUP"

# Lookup DR Region DB Security Group
DR_SECURITY_GROUP=$(aws rds describe-db-clusters \
    --region $DR_REGION \
    --db-cluster-identifier "$DR_CLUSTER_ARN" \
    --query=DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId \
    --output text)
check_look_up_exists "$DR_SECURITY_GROUP"

# Lookup Primary Region DB Subnet Group
PRIMARY_SUBNET_GROUP=$(aws rds describe-db-clusters \
    --region $PRIMARY_REGION \
    --db-cluster-identifier "$PRIMARY_CLUSTER_ARN" \
    --query=DBClusters[0].DBSubnetGroup \
    --output text
    )
check_look_up_exists "$PRIMARY_SUBNET_GROUP"

# Lookup DR Region DB Subnet Group
DR_SUBNET_GROUP=$(aws rds describe-db-clusters \
    --region $DR_REGION \
    --db-cluster-identifier "$DR_CLUSTER_ARN" \
    --query=DBClusters[0].DBSubnetGroup \
    --output text
    )
check_look_up_exists "$DR_SUBNET_GROUP"

# Lookup Monitoring Role ARN
MONITORING_ROLE=$(aws rds describe-db-instances \
    --region $PRIMARY_REGION \
    --db-instance-identifier "$REGIONAL_CLUSTER-0" \
    --query=DBInstances[0].MonitoringRoleArn \
    --output text)
check_look_up_exists "$MONITORING_ROLE"

# Lookup DB Instance Class
INSTANCE_CLASS=$(aws rds describe-db-instances \
    --region $PRIMARY_REGION \
    --db-instance-identifier "$REGIONAL_CLUSTER-0" \
    --query=DBInstances[0].DBInstanceClass \
    --output text)
check_look_up_exists "$INSTANCE_CLASS"

echo "INFO - DATABASE: $DATABASE"
echo "INFO - ENVIRONMENT_NAME: $ENVIRONMENT_NAME"
echo "INFO - PRIMARY_REGION: $PRIMARY_REGION"
echo "INFO - DR_REGION: $DR_REGION"
echo "INFO - GLOBAL_CLUSTER: $GLOBAL_CLUSTER"
echo "INFO - REGIONAL_CLUSTER: $REGIONAL_CLUSTER"
echo "INFO - SNAPSHOT_FOR_RESTORE: $SNAPSHOT_FOR_RESTORE"
# These are all the derived paramters you need to rerun parts of the script.
echo "INFO - Cluster Config:-"
echo "INFO - PRIMARY_CLUSTER_ARN=$PRIMARY_CLUSTER_ARN"
echo "INFO - DR_CLUSTER_ARN=$DR_CLUSTER_ARN"
echo "INFO - PRIMARY_SECURITY_GROUP=$PRIMARY_SECURITY_GROUP"
echo "INFO - DR_SECURITY_GROUP=$DR_SECURITY_GROUP"
echo "INFO - PRIMARY_SUBNET_GROUP=$PRIMARY_SUBNET_GROUP"
echo "INFO - DR_SUBNET_GROUP=$DR_SUBNET_GROUP"
echo "INFO - MONITORING_ROLE=$MONITORING_ROLE"
echo "INFO - INSTANCE_CLASS=$INSTANCE_CLASS"

# Ensure a valid snapshot exists for restore.
check_snapshot_exists $PRIMARY_REGION $SNAPSHOT_FOR_RESTORE


# Remove $DR_REGION cluster from global cluster
echo "INFO - Removing $DR_REGION cluster from the global cluster"
aws rds remove-from-global-cluster --region $DR_REGION --global-cluster-identifier $GLOBAL_CLUSTER --db-cluster-identifier $DR_CLUSTER_ARN
wait_for_db_cluster_available $DR_REGION $DR_CLUSTER_ARN

# Delete $DR_REGION cluster
echo "INFO - Deleting Cluster instances for $DR_REGION"
aws rds delete-db-instance --region $DR_REGION --db-instance-identifier $REGIONAL_CLUSTER-0
aws rds delete-db-instance --region $DR_REGION --db-instance-identifier $REGIONAL_CLUSTER-1
aws rds delete-db-instance --region $DR_REGION --db-instance-identifier $REGIONAL_CLUSTER-2
wait_for_db_instance_deleted $DR_REGION $REGIONAL_CLUSTER-0
wait_for_db_instance_deleted $DR_REGION $REGIONAL_CLUSTER-1
wait_for_db_instance_deleted $DR_REGION $REGIONAL_CLUSTER-2
echo "INFO - Removing Deletion Protection for $DR_REGION $REGIONAL_CLUSTER"
aws rds modify-db-cluster --region $DR_REGION --db-cluster-identifier $REGIONAL_CLUSTER --no-deletion-protection --apply-immediately
wait_for_db_cluster_available $DR_REGION $REGIONAL_CLUSTER
echo "INFO - Deleting Cluster: $DR_REGION $REGIONAL_CLUSTER"
aws rds delete-db-cluster --region $DR_REGION --db-cluster-identifier $REGIONAL_CLUSTER --skip-final-snapshot
wait_for_db_cluster_deleted $DR_REGION $REGIONAL_CLUSTER

# Remove $PRIMARY_REGION cluster from global cluster
echo "INFO - Removing $PRIMARY_REGION cluster from the global cluster"
aws rds remove-from-global-cluster --region $PRIMARY_REGION --global-cluster-identifier $GLOBAL_CLUSTER --db-cluster-identifier $PRIMARY_CLUSTER_ARN
wait_for_db_cluster_available $PRIMARY_REGION $PRIMARY_CLUSTER_ARN

# Delete global cluster
echo "INFO - Removing Deletion Protection for $GLOBAL_CLUSTER"
aws rds modify-global-cluster --region $PRIMARY_REGION --global-cluster-identifier $GLOBAL_CLUSTER --no-deletion-protection
wait_for_global_cluster_available $PRIMARY_REGION $GLOBAL_CLUSTER
echo "INFO - Deleting Global Cluster $GLOBAL_CLUSTER"
aws rds delete-global-cluster --region $PRIMARY_REGION --global-cluster-identifier $GLOBAL_CLUSTER
wait_for_global_cluster_deleted $PRIMARY_REGION $GLOBAL_CLUSTER

# Delete $PRIMARY_REGION cluster instances
echo "INFO - Deleting Cluster instances for $PRIMARY_REGION"
aws rds delete-db-instance --region $PRIMARY_REGION --db-instance-identifier $REGIONAL_CLUSTER-0
aws rds delete-db-instance --region $PRIMARY_REGION --db-instance-identifier $REGIONAL_CLUSTER-1
aws rds delete-db-instance --region $PRIMARY_REGION --db-instance-identifier $REGIONAL_CLUSTER-2
wait_for_db_instance_deleted $PRIMARY_REGION $REGIONAL_CLUSTER-0
wait_for_db_instance_deleted $PRIMARY_REGION $REGIONAL_CLUSTER-1
wait_for_db_instance_deleted $PRIMARY_REGION $REGIONAL_CLUSTER-2

# Disable $PRIMARY_REGION cluster deletion protection
echo "INFO - Removing Deletion Protection $PRIMARY_REGION $REGIONAL_CLUSTER"
aws rds modify-db-cluster --region $PRIMARY_REGION --db-cluster-identifier $REGIONAL_CLUSTER --no-deletion-protection --apply-immediately
wait_for_db_cluster_available $PRIMARY_REGION $PRIMARY_CLUSTER_ARN

# Delete $PRIMARY_REGION cluster without final-snapshot
check_for_and_delete_snapshot $PRIMARY_REGION $REGIONAL_CLUSTER-final-snapshot
echo "INFO - Deleting Cluster: $PRIMARY_REGION $REGIONAL_CLUSTER"
aws rds delete-db-cluster --region $PRIMARY_REGION \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --skip-final-snapshot
wait_for_db_cluster_deleted $PRIMARY_REGION $PRIMARY_CLUSTER_ARN

# Restore Cluster from Snapshot
echo "INFO - Restoring $PRIMARY_REGION $REGIONAL_CLUSTER from $SNAPSHOT_FOR_RESTORE"
aws rds restore-db-cluster-from-snapshot \
    --region $PRIMARY_REGION \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --snapshot-identifier $SNAPSHOT_FOR_RESTORE \
    --engine aurora-postgresql \
    --engine-version $DATABASE_VERSION \
    --vpc-security-group-ids $PRIMARY_SECURITY_GROUP \
    --db-subnet-group-name $PRIMARY_SUBNET_GROUP \
    --db-cluster-parameter-group-name \
    --deletion-protection \
    --enable-cloudwatch-logs-exports postgresql
wait_for_db_cluster_available $PRIMARY_REGION $REGIONAL_CLUSTER

# Add Instances to $PRIMARY_REGION Cluster
echo "INFO - Creating cluster instances for $PRIMARY_REGION $REGIONAL_CLUSTER"
aws rds create-db-instance \
    --region $PRIMARY_REGION \
    --db-instance-identifier $REGIONAL_CLUSTER-0 \
    --db-instance-class $INSTANCE_CLASS \
    --engine aurora-postgresql \
    --availability-zone $PRIMARY_REGION"a" \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --ca-certificate-identifier rds-ca-rsa2048-g1 \
    --no-auto-minor-version-upgrade \
    --promotion-tier 0 \
    --monitoring-interval 30 \
    --monitoring-role-arn $MONITORING_ROLE \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags \
    Key=account,Value="$ACCOUNT_NAME" \
    Key=application,Value="Sirius" \
    Key=business-unit,Value="OPG" \
    Key=environment-name,Value="$ENVIRONMENT_NAME" \
    Key=infrastructure-support,Value="opgteam@digital.justice.gov.uk" \
    Key=is-production,Value="false" \
    Key=owner,Value="opgteam@digital.justice.gov.uk" \
    Key=source-code,Value="https://github.com/ministryofjustice/opg-sirius-infrastructure"

aws rds create-db-instance \
    --region $PRIMARY_REGION \
    --db-instance-identifier $REGIONAL_CLUSTER-1 \
    --db-instance-class $INSTANCE_CLASS \
    --engine aurora-postgresql \
    --availability-zone $PRIMARY_REGION"b" \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --ca-certificate-identifier rds-ca-rsa2048-g1 \
    --no-auto-minor-version-upgrade \
    --promotion-tier 0 \
    --monitoring-interval 30 \
    --monitoring-role-arn $MONITORING_ROLE \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags \
    Key=account,Value="$ACCOUNT_NAME" \
    Key=application,Value="Sirius" \
    Key=business-unit,Value="OPG" \
    Key=environment-name,Value="$ENVIRONMENT_NAME" \
    Key=infrastructure-support,Value="opgteam@digital.justice.gov.uk" \
    Key=is-production,Value="false" \
    Key=owner,Value="opgteam@digital.justice.gov.uk" \
    Key=source-code,Value="https://github.com/ministryofjustice/opg-sirius-infrastructure"

aws rds create-db-instance \
    --region $PRIMARY_REGION \
    --db-instance-identifier $REGIONAL_CLUSTER-2 \
    --db-instance-class $INSTANCE_CLASS \
    --engine aurora-postgresql \
    --availability-zone $PRIMARY_REGION"c" \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --ca-certificate-identifier rds-ca-rsa2048-g1 \
    --no-auto-minor-version-upgrade \
    --promotion-tier 0 \
    --monitoring-interval 30 \
    --monitoring-role-arn $MONITORING_ROLE \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags \
    Key=account,Value="$ACCOUNT_NAME" \
    Key=application,Value="Sirius" \
    Key=business-unit,Value="OPG" \
    Key=environment-name,Value="$ENVIRONMENT_NAME" \
    Key=infrastructure-support,Value="opgteam@digital.justice.gov.uk" \
    Key=is-production,Value="false" \
    Key=owner,Value="opgteam@digital.justice.gov.uk" \
    Key=source-code,Value="https://github.com/ministryofjustice/opg-sirius-infrastructure"

wait_for_db_instance_available $PRIMARY_REGION $REGIONAL_CLUSTER-0
wait_for_db_instance_available $PRIMARY_REGION $REGIONAL_CLUSTER-1
wait_for_db_instance_available $PRIMARY_REGION $REGIONAL_CLUSTER-2

# Create Global Cluster from $PRIMARY_REGION cluster
echo "INFO - Creating global cluster $GLOBAL_CLUSTER from $PRIMARY_REGION $REGIONAL_CLUSTER"
aws rds create-global-cluster \
    --region $PRIMARY_REGION \
    --global-cluster-identifier $GLOBAL_CLUSTER \
    --source-db-cluster-identifier arn:aws:rds:$PRIMARY_REGION:492687888235:cluster:$REGIONAL_CLUSTER \
    --deletion-protection
wait_for_global_cluster_available $PRIMARY_REGION $GLOBAL_CLUSTER

# Create $DR_REGION cluster
echo "INFO - Create $DR_REGION $REGIONAL_CLUSTER from $GLOBAL_CLUSTER"
aws rds create-db-cluster \
    --region $DR_REGION \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --db-cluster-parameter-group-name \
    --db-subnet-group-name $DR_SUBNET_GROUP \
    --deletion-protection \
    --enable-cloudwatch-logs-exports postgresql \
    --engine aurora-postgresql \
    --engine-version $DATABASE_VERSION \
    --global-cluster-identifier $GLOBAL_CLUSTER \
    --kms-key-id alias/aws/rds \
    --source-region $PRIMARY_REGION \
    --vpc-security-group-ids $DR_SECURITY_GROUP
wait_for_db_cluster_available $DR_REGION $REGIONAL_CLUSTER

# Add Instances to $DR_REGION Cluster
echo "INFO - Creating cluster instances fro $DR_REGION $REGIONAL_CLUSTER"
aws rds create-db-instance \
    --region $DR_REGION \
    --db-instance-identifier $REGIONAL_CLUSTER-0 \
    --db-instance-class $INSTANCE_CLASS \
    --engine aurora-postgresql \
    --availability-zone $DR_REGION"a" \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --ca-certificate-identifier rds-ca-rsa2048-g1 \
    --no-auto-minor-version-upgrade \
    --promotion-tier 0 \
    --monitoring-interval 30 \
    --monitoring-role-arn $MONITORING_ROLE \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags \
    Key=account,Value="$ACCOUNT_NAME" \
    Key=application,Value="Sirius" \
    Key=business-unit,Value="OPG" \
    Key=environment-name,Value="$ENVIRONMENT_NAME" \
    Key=infrastructure-support,Value="opgteam@digital.justice.gov.uk" \
    Key=is-production,Value="false" \
    Key=owner,Value="opgteam@digital.justice.gov.uk" \
    Key=source-code,Value="https://github.com/ministryofjustice/opg-sirius-infrastructure"

aws rds create-db-instance \
    --region $DR_REGION \
    --db-instance-identifier $REGIONAL_CLUSTER-1 \
    --db-instance-class $INSTANCE_CLASS \
    --engine aurora-postgresql \
    --availability-zone $DR_REGION"b" \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --ca-certificate-identifier rds-ca-rsa2048-g1 \
    --no-auto-minor-version-upgrade \
    --promotion-tier 0 \
    --monitoring-interval 30 \
    --monitoring-role-arn $MONITORING_ROLE \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags \
    Key=account,Value="$ACCOUNT_NAME" \
    Key=application,Value="Sirius" \
    Key=business-unit,Value="OPG" \
    Key=environment-name,Value="$ENVIRONMENT_NAME" \
    Key=infrastructure-support,Value="opgteam@digital.justice.gov.uk" \
    Key=is-production,Value="false" \
    Key=owner,Value="opgteam@digital.justice.gov.uk" \
    Key=source-code,Value="https://github.com/ministryofjustice/opg-sirius-infrastructure"

aws rds create-db-instance \
    --region $DR_REGION \
    --db-instance-identifier $REGIONAL_CLUSTER-2 \
    --db-instance-class $INSTANCE_CLASS \
    --engine aurora-postgresql \
    --availability-zone $DR_REGION"c" \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --ca-certificate-identifier rds-ca-rsa2048-g1 \
    --no-auto-minor-version-upgrade \
    --promotion-tier 0 \
    --monitoring-interval 30 \
    --monitoring-role-arn $MONITORING_ROLE \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --tags \
    Key=account,Value="$ACCOUNT_NAME" \
    Key=application,Value="Sirius" \
    Key=business-unit,Value="OPG" \
    Key=environment-name,Value="$ENVIRONMENT_NAME" \
    Key=infrastructure-support,Value="opgteam@digital.justice.gov.uk" \
    Key=is-production,Value="false" \
    Key=owner,Value="opgteam@digital.justice.gov.uk" \
    Key=source-code,Value="https://github.com/ministryofjustice/opg-sirius-infrastructure"

wait_for_db_instance_available $DR_REGION $REGIONAL_CLUSTER-0
wait_for_db_instance_available $DR_REGION $REGIONAL_CLUSTER-1
wait_for_db_instance_available $DR_REGION $REGIONAL_CLUSTER-2

# Update cluster password
echo "INFO - Updating Cluster master password for $PRIMARY_REGION $REGIONAL_CLUSTER"
aws rds modify-db-cluster --db-cluster-identifier $REGIONAL_CLUSTER \
    --region $PRIMARY_REGION \
    --apply-immediately \
    --master-user-password "$RDS_PASSWORD"
wait_for_db_cluster_available $PRIMARY_REGION $REGIONAL_CLUSTER
echo "INFO - Global Cluster $GLOBAL_CLUSTER Restore Complete!"
