#! /usr/bin/env sh

set -e
set -o pipefail

# Expected Environment Variables
ACCOUNT_NAME=production
DATABASE=api
ENVIRONMENT_NAME=production
PRIMARY_REGION=eu-west-1
DR_REGION=eu-west-2

. ./common-multi-az.sh

GLOBAL_CLUSTER=$ENVIRONMENT_NAME-$DATABASE-global
REGIONAL_CLUSTER=$DATABASE-$ENVIRONMENT_NAME

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

# Lookup Primary DB Instance Class
PRIMARY_INSTANCE_CLASS=$(aws rds describe-db-instances \
    --region $PRIMARY_REGION \
    --db-instance-identifier "$REGIONAL_CLUSTER-0" \
    --query=DBInstances[0].DBInstanceClass \
    --output text)
check_look_up_exists "$PRIMARY_INSTANCE_CLASS"

# Lookup Secondary DB Instance Class
if [ "$DR_REGION_NO_COMPUTE" != "true" ]
then
    DR_INSTANCE_CLASS=$(aws rds describe-db-instances \
        --region $DR_REGION \
        --db-instance-identifier "$REGIONAL_CLUSTER-0" \
        --query=DBInstances[0].DBInstanceClass \
        --output text)
    check_look_up_exists "$DR_INSTANCE_CLASS"
else
    DR_INSTANCE_CLASS="db.serverless"
fi


# Lookup Serverless Max Capacity
SERVERLESS_MAX_CAPACITY=$(aws rds describe-db-clusters \
    --region $PRIMARY_REGION \
    --db-cluster-identifier "$PRIMARY_CLUSTER_ARN" \
    --query=DBClusters[0].ServerlessV2ScalingConfiguration.MaxCapacity \
    --output text)
check_look_up_exists "$SERVERLESS_MAX_CAPACITY"

# Lookup Serverless Min Capacity
SERVERLESS_MIN_CAPACITY=$(aws rds describe-db-clusters \
    --region $PRIMARY_REGION \
    --db-cluster-identifier "$PRIMARY_CLUSTER_ARN" \
    --query=DBClusters[0].ServerlessV2ScalingConfiguration.MinCapacity \
    --output text)
check_look_up_exists "$SERVERLESS_MIN_CAPACITY"

echo "INFO - DATABASE: $DATABASE"
echo "INFO - ENVIRONMENT_NAME: $ENVIRONMENT_NAME"
echo "INFO - PRIMARY_REGION: $PRIMARY_REGION"
echo "INFO - DR_REGION: $DR_REGION"
echo "INFO - GLOBAL_CLUSTER: $GLOBAL_CLUSTER"
echo "INFO - REGIONAL_CLUSTER: $REGIONAL_CLUSTER"
echo "INFO - Cluster Config:-"
echo "INFO - PRIMARY_CLUSTER_ARN=$PRIMARY_CLUSTER_ARN"
echo "INFO - DR_CLUSTER_ARN=$DR_CLUSTER_ARN"
echo "INFO - PRIMARY_SECURITY_GROUP=$PRIMARY_SECURITY_GROUP"
echo "INFO - DR_SECURITY_GROUP=$DR_SECURITY_GROUP"
echo "INFO - PRIMARY_SUBNET_GROUP=$PRIMARY_SUBNET_GROUP"
echo "INFO - DR_SUBNET_GROUP=$DR_SUBNET_GROUP"
echo "INFO - MONITORING_ROLE=$MONITORING_ROLE"
echo "INFO - PRIMARY_INSTANCE_CLASS=$PRIMARY_INSTANCE_CLASS"
echo "INFO - DR_INSTANCE_CLASS=$DR_INSTANCE_CLASS"
echo "INFO - SERVERLESS_MAX_CAPACITY=$SERVERLESS_MAX_CAPACITY"
echo "INFO - SERVERLESS_MIN_CAPACITY=$SERVERLESS_MIN_CAPACITY"

# # Remove $DR_REGION cluster from global cluster
# echo "INFO - Removing $DR_REGION cluster from the global cluster"
# aws rds remove-from-global-cluster --region $DR_REGION --global-cluster-identifier $GLOBAL_CLUSTER --db-cluster-identifier $DR_CLUSTER_ARN
# wait_for_db_cluster_available $DR_REGION $DR_CLUSTER_ARN

# Delete $DR_REGION cluster
if [ "$DR_REGION_NO_COMPUTE" != "true" ]
then
    echo "INFO - Deleting Cluster instances for $DR_REGION"
    aws rds delete-db-instance --region $DR_REGION --db-instance-identifier $REGIONAL_CLUSTER-0
    wait_for_db_instance_deleted $DR_REGION $REGIONAL_CLUSTER-0
fi

echo "INFO - Removing Deletion Protection for $DR_REGION $REGIONAL_CLUSTER"
aws rds modify-db-cluster --region $DR_REGION --db-cluster-identifier $REGIONAL_CLUSTER --no-deletion-protection --apply-immediately
wait_for_db_cluster_available $DR_REGION $REGIONAL_CLUSTER

echo "INFO - Deleting Cluster: $DR_REGION $REGIONAL_CLUSTER"
aws rds delete-db-cluster --region $DR_REGION --db-cluster-identifier $REGIONAL_CLUSTER --skip-final-snapshot
wait_for_db_cluster_deleted $DR_REGION $REGIONAL_CLUSTER

# Create $DR_REGION cluster
echo "INFO - Create $DR_REGION $REGIONAL_CLUSTER from $GLOBAL_CLUSTER"
aws rds create-db-cluster \
    --region $DR_REGION \
    --db-cluster-identifier $REGIONAL_CLUSTER \
    --db-cluster-parameter-group-name "$PARAMETER_GROUP" \
    --db-subnet-group-name $DR_SUBNET_GROUP \
    --deletion-protection \
    --enable-cloudwatch-logs-exports postgresql \
    --engine aurora-postgresql \
    --engine-version $DATABASE_VERSION \
    --global-cluster-identifier $GLOBAL_CLUSTER \
    --kms-key-id alias/aws/rds \
    --source-region $PRIMARY_REGION \
    --vpc-security-group-ids $DR_SECURITY_GROUP \
    --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=$SERVERLESS_MAX_CAPACITY

wait_for_db_cluster_available $DR_REGION $REGIONAL_CLUSTER

# Add Instances to $DR_REGION Cluster
if [ "$DR_REGION_NO_COMPUTE" != "true" ]
then
    echo "INFO - Creating cluster instances from $DR_REGION $REGIONAL_CLUSTER"
    aws rds create-db-instance \
        --region $DR_REGION \
        --db-instance-identifier $REGIONAL_CLUSTER-0 \
        --db-instance-class $DR_INSTANCE_CLASS \
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

    wait_for_db_instance_available $DR_REGION $REGIONAL_CLUSTER-0
fi
