#! /usr/bin/env sh

set -e
set -o pipefail

. common.sh

validateEnvironment() {

    validateCommonEnvironment

    if [ -z "$REGION" ]; then
    echo "ERROR - You need to set the REGION environment variable."
    exit 1
    fi
}

checkMaintenanceMode() {
    echo "Checking environment $ENVIRONMENT_NAME is in maintenance mode."
    if [ $(aws ecs describe-services --cluster $ENVIRONMENT_NAME --service maintenance --region $REGION | jq -r '.services[].desiredCount')  != "0" ]; then
        echo "Already in maintenance mode."
        exit 1
    else
        echo "Environment $ENVIRONMENT_NAME is not in maintenance mode."
    fi
}

enableMaintenanceMode() {
    local SERVICES=$(aws ecs list-services --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".serviceArns.[]")
    for SERVICE in $SERVICES;
    do
        aws ecs update-service --cluster $ENVIRONMENT_NAME --region $REGION --service $SERVICE --desired-count 0 --no-cli-pager
    done

    aws ecs update-service --cluster $ENVIRONMENT_NAME --region $REGION --service maintenance --desired-count 1 --no-cli-pager

    waitForServiceStable "maintenance"
}

validateEnvironment
checkMaintenanceMode
enableMaintenanceMode