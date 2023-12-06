#! /usr/bin/env sh

set -e
set -o pipefail

validateCommonEnvironment() {
    if [ -z "$ENVIRONMENT_NAME" ]; then
    echo "ERROR - You need to set the ENVIRONMENT_NAME environment variable."
    exit 1
    fi
    # if [ -z "$ACCOUNT_ID" ]; then
    # echo "ERROR - You need to set the ACCOUNT_ID environment variable."
    # exit 1
    # fi
}

waitForServiceStable() {
    SERVICE_NAME=$1
    DESIRED_COUNT=$(aws ecs describe-services --cluster $ENVIRONMENT_NAME --service $SERVICE_NAME --region $REGION | jq -r '.services[].desiredCount')
    RUNNING_COUNT=$(aws ecs describe-services --cluster $ENVIRONMENT_NAME --service $SERVICE_NAME --region $REGION | jq -r '.services[].runningCount')

    while [ $RUNNING_COUNT != $DESIRED_COUNT ]
    do
        echo "INFO - Waiting for service $SERVICE_NAME to stabilise..."
        sleep 20
        RUNNING_COUNT=$(aws ecs describe-services --cluster $ENVIRONMENT_NAME --service $SERVICE_NAME --region $REGION | jq -r '.services[].runningCount')
    done
    echo "INFO - Service $SERVICE_NAME stable."
}