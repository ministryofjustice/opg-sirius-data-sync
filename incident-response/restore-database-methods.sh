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
    CLASS=$4
    echo "INFO - Creating DB Cluster Instance $INSTANCE"
    aws rds create-db-instance \
        --db-instance-identifier $INSTANCE \
        --db-instance-class $CLASS \
        --engine aurora-postgresql \
        --availability-zone $AZ \
        --db-cluster-identifier $CLUSTER \
        --no-auto-minor-version-upgrade \
        --ca-certificate-identifier rds-ca-rsa2048-g1 \
        --promotion-tier 0 \
        --monitoring-interval 30 \
        --monitoring-role-arn "$MONITORING_ROLE" \
        --enable-performance-insights \
        --performance-insights-retention-period 7
}

LOCAL_SNAPSHOT="response-${ENVIRONMENT_NAME}-pre-mig-20240507"
echo "INFO - LOCAL_SNAPSHOT set to $LOCAL_SNAPSHOT"

CLUSTER_ARN=$(aws rds describe-db-clusters --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].DBClusterArn \
    --output text)
check_look_up_exists "$CLUSTER_ARN"
echo "INFO - DB Cluster ARN set to $CLUSTER_ARN"

WRITER_INSTANCE_CLASS="db.t3.medium"
# WRITER_INSTANCE_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$DATABASE-$ENVIRONMENT_NAME-0" \
#     --query=DBInstances[0].DBInstanceClass \
#     --output text)
check_look_up_exists "$WRITER_INSTANCE_CLASS"
echo "INFO - Database Writer Instance Class set to $WRITER_INSTANCE_CLASS"
if [ "$CLUSTER_NODES" != "1" ]; then
    READER_INSTANCE_CLASS="db.t3.medium"
    # READER_INSTANCE_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$DATABASE-$ENVIRONMENT_NAME-1" \
    #     --query=DBInstances[0].DBInstanceClass \
    #     --output text)
    check_look_up_exists "$READER_INSTANCE_CLASS"
    echo "INFO - Database Reader Instance Class set to $READER_INSTANCE_CLASS"
fi

# SECURITY_GROUP="sg-0f1519d2c28c2ceef"
SECURITY_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId \
    --output text)
check_look_up_exists "$SECURITY_GROUP"
echo "INFO - Database Security Group set to $SECURITY_GROUP"

# SUBNET_GROUP="data-persitance-subnet-production"
SUBNET_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "$DATABASE_CLUSTER" \
    --query=DBClusters[0].DBSubnetGroup \
    --output text)
check_look_up_exists "$SUBNET_GROUP"
echo "INFO - RDS Subnet Group set to $SUBNET_GROUP"

# MONITORING_ROLE="arn:aws:iam::997462338508:role/rds-monitoring-role-production"
MONITORING_ROLE=$(aws rds describe-db-instances --db-instance-identifier "$DATABASE-$ENVIRONMENT_NAME-0" \
    --query=DBInstances[0].MonitoringRoleArn \
    --output text)
check_look_up_exists "$MONITORING_ROLE"
echo "INFO - RDS Monitoring Role ARN set to $MONITORING_ROLE"

RDS_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "response/${ENVIRONMENT_NAME}/rds-password" \
    --query=SecretString \
    --output text)
check_look_up_exists "RDS_PASSWORD"
echo "INFO - RDS Password retrieved"

check_snapshot_exists "$LOCAL_SNAPSHOT"

SERVERLESS_MAX_CAPACITY="4"
# SERVERLESS_MAX_CAPACITY=$(aws rds describe-db-clusters \
#     --db-cluster-identifier "$DATABASE_CLUSTER" \
#     --query=DBClusters[0].ServerlessV2ScalingConfiguration.MaxCapacity \
#     --output text)
check_look_up_exists "$SERVERLESS_MAX_CAPACITY"

SERVERLESS_MIN_CAPACITY="0.5"
# SERVERLESS_MIN_CAPACITY=$(aws rds describe-db-clusters \
#     --db-cluster-identifier "$DATABASE_CLUSTER" \
#     --query=DBClusters[0].ServerlessV2ScalingConfiguration.MinCapacity \
#     --output text)
check_look_up_exists "$SERVERLESS_MIN_CAPACITY"
