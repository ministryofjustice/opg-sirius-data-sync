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
    local SERVICES=$(aws ecs list-services --cluster dr-test --region eu-west-1 | jq -r ".serviceArns.[]")
    for SERVICE in $SERVICES;
    do
        echo $SERVICE
    done
}

validateEnvironment
checkMaintenanceMode
enableMaintenanceMode