delete_db_instance() {
    INSTANCE=$1
    echo "INFO - Deleting DB Instance $INSTANCE"
    aws rds delete-db-instance \
        --db-instance-identifier $INSTANCE \
        --skip-final-snapshot
}

create_db_instance() {
    CLUSTER=$1
    INSTANCE=$2
    AZ=$3
    echo "INFO - Creating DB Cluster Instance $INSTANCE"
    aws rds create-db-instance \
        --db-instance-identifier $INSTANCE \
        --db-instance-class db.r5.2xlarge \
        --engine aurora-postgresql \
        --availability-zone $AZ \
        --db-cluster-identifier $CLUSTER \
        --no-auto-minor-version-upgrade \
        --promotion-tier 0 \
        --monitoring-interval 30 \
        --monitoring-role-arn "$MONITORING_ROLE" \
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
}

LOCAL_SNAPSHOT=$DATABASE_CLUSTER-snapshot-for-restore
echo "INFO - LOCAL_SNAPSHOT set to $LOCAL_SNAPSHOT"

CLUSTER_ARN=$(aws rds describe-db-clusters --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].DBClusterArn \
    --output text)
check_look_up_exists "$CLUSTER_ARN"
echo "INFO - DB Cluster ARN set to $CLUSTER_ARN"

SECURITY_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId \
    --output text)
check_look_up_exists "$SECURITY_GROUP"
echo "INFO - Database Security Group set to $SECURITY_GROUP"

SUBNET_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].DBSubnetGroup \
    --output text)
check_look_up_exists "$SUBNET_GROUP"
echo "INFO - RDS Subnet Group set to $SUBNET_GROUP"

MONITORING_ROLE=$(aws rds describe-db-instances --db-instance-identifier "$DATABASE-$ENVIRONMENT_NAME-0" \
    --query=DBInstances[0].MonitoringRoleArn \
    --output text)
check_look_up_exists "$MONITORING_ROLE"
echo "INFO - RDS Monitoring Role ARN set to $MONITORING_ROLE"

RDS_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "rds-$DATABASE-$ACCOUNT_NAME" \
    --query=SecretString \
    --output text)
check_look_up_exists "RDS_PASSWORD"
echo "INFO - RDS Password retrieved"

check_snapshot_exists "$LOCAL_SNAPSHOT"
