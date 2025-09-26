#! /usr/bin/env bash
REGION=eu-west-2
INSTANCES=$(aws rds describe-db-clusters --region $REGION --db-cluster-identifier api-preproduction | jq -r "[.DBClusters[0].DBClusterMembers[].DBInstanceIdentifier]|sort|.[]")
AZ_ZONES=(a b c)
echo "Cluster Instances: -"
echo "$INSTANCES"

for INSTANCE in $INSTANCES
do
    echo "Delete Instance: $INSTANCE"
done

for INSTANCE in $INSTANCES
do
    echo "Wait for Deletion of Instance: $INSTANCE"
done


POSITION=0
for INSTANCE in $INSTANCES
do
    echo "Create Instance: $INSTANCE in $REGION${AZ_ZONES[$POSITION]}"
    echo "Position: $POSITION"
    POSITION=$[$POSITION+1]
done

if [ "$INSTANCES" != "" ]
then
    echo "Instances Exist"
else
    echo "No Instances Exist"
fi


aws rds create-global-cluster \
    --region eu-west-1 \
    --global-cluster-identifier sp-2881-api-global \
    --source-db-cluster-identifier arn:aws:rds:eu-west-1:288342028542:cluster:api-sp-2881 \
    --deletion-protection


aws rds delete-db-cluster --region eu-west-2 \
    --db-cluster-identifier arn:aws:rds:eu-west-2:288342028542:cluster:api-sp-2881 \
    --skip-final-snapshot

aws rds create-db-cluster \
    --region eu-west-2 \
    --db-cluster-identifier api-sp-2881 \
    --db-cluster-parameter-group-name "aurora-postgresql14-ssl" \
    --db-subnet-group-name data-persitance-subnet-dev-vpc \
    --engine aurora-postgresql \
    --engine-version 14 \
    --global-cluster-identifier sp-2881-api-global \
    --kms-key-id alias/aws/rds \
    --source-region eu-west-1 \
    --vpc-security-group-ids sg-06310535b771e5e37 \
    --serverless-v2-scaling-configuration MinCapacity=0,MaxCapacity=4
