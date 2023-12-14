#! /usr/bin/env bash

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

updateService() {
    local SERVICE=$1
    local DESIRED_COUNT=${2}
    echo "INFO - Updating service $SERVICE"
    echo "INFO - Setting desired count to $DESIRED_COUNT"
    if aws ecs update-service --cluster $ENVIRONMENT_NAME --region $REGION --service $SERVICE --desired-count $DESIRED_COUNT --no-cli-pager; then
        echo "INFO - Updated $SERVICE Service."
    else
        echo "ERROR - $SERVICE Service Update Failed!"
        exit 1
    fi
}

updateEventbridgeRule() {
    local RULE=$1
    local STATE=$2
    local EVENTBUS=$3
    echo "INFO - Updating rule $RULE"
    echo "INFO - Setting state to $STATE"
    if [ $STATE == "ENABLED" ]; then 
        local COMMAND=enable-rule
    else
        local COMMAND=disable-rule
    fi
    echo "INFO - Updating $RULE to $STATE..."
    if aws events $COMMAND --event-bus-name $EVENTBUS --name $RULE --region $REGION --no-cli-pager; then
        echo "INFO - Updated $RULE to $STATE."
    else
        echo "ERROR - EventBridge Rule $RULE Failed to Update!"
        exit 1
    fi
}

updateEventBusRules() {
    local EVENTBUS=$1
    local STATE=$2

    # Lookup all rules on an event bus
    local RULES=$(aws events list-rules --name-prefix $ENVIRONMENT_NAME --event-bus-name $EVENTBUS --region $REGION | jq -r ".Rules[].Name")
    for RULE in $RULES;
    do 
        # Cycle through rules senting to the desired state
        updateEventbridgeRule $RULE $STATE $EVENTBUS
    done
}

updateGlueTrigger() {
    local TRIGGER=$1
    local STATE=$2
    echo "INFO - Updating Glue Trigger $TRIGGER"
    echo "INFO - Setting state to $STATE"
    if [ $STATE == "ENABLED" ]; then 
        local COMMAND=start
    else
        local COMMAND=stop
    fi
    echo "INFO - Updating $TRIGGER to $STATE..."
    if aws glue $COMMAND-trigger --name $TRIGGER --region $REGION --no-cli-pager; then
        echo "INFO - Updated $TRIGGER to $STATE."
    else
        echo "ERROR - Glue Trigger $TRIGGER Failed to Update!"
        exit 1
    fi
}

updateGlueJobTriggers() {
    local STATE=$1
    # Lookup all glue triggers for environment
    echo "INFO - Setting Glue Job Triggers for $ENVIRONMENT_NAME to $STATE"
    local TRIGGERS=$(aws glue list-triggers --max-results 200 --region $REGION | jq -r '.TriggerNames[] | select(.|endswith("'$ENVIRONMENT_NAME'"))')
    for TRIGGER in $TRIGGERS;
    do 
        # Cycle through rules senting to the desired state
        updateGlueTrigger $TRIGGER $STATE
    done
}