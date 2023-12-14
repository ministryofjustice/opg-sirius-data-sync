#! /usr/bin/env bash

set -e
set -o pipefail

. common.sh

# Array of current Production Envirionment Service Scale
declare -A DESIRED_SERVICE_COUNTS

DESIRED_SERVICE_COUNTS["api"]="8"
DESIRED_SERVICE_COUNTS["file-service"]="1"
DESIRED_SERVICE_COUNTS["frontend"]="8"
DESIRED_SERVICE_COUNTS["frontend-ddc"]="4"
DESIRED_SERVICE_COUNTS["lpa"]="1"
DESIRED_SERVICE_COUNTS["lpa-dashboard"]="1"
DESIRED_SERVICE_COUNTS["lpa-frontend"]="2"
DESIRED_SERVICE_COUNTS["notify-poller"]="1"
DESIRED_SERVICE_COUNTS["notify-sender"]="1"
DESIRED_SERVICE_COUNTS["pdf-service"]="3"
DESIRED_SERVICE_COUNTS["queue-consumer"]="4"
DESIRED_SERVICE_COUNTS["search-service"]="1"
DESIRED_SERVICE_COUNTS["supervision"]="1"
DESIRED_SERVICE_COUNTS["supervision-deputy-hub"]="1"
DESIRED_SERVICE_COUNTS["supervision-firm-deputy-hub"]="1"
DESIRED_SERVICE_COUNTS["supervision-workflow"]="1"
DESIRED_SERVICE_COUNTS["sirius-user-management"]="1"

validateEnvironment() {

    validateCommonEnvironment

    if [ -z "$REGION" ]; then
    echo "ERROR - You need to set the REGION environment variable."
    exit 1
    fi
}

toggleMaintenanceMode() {
    echo "Checking environment $ENVIRONMENT_NAME is in maintenance mode."
    if [ $(aws ecs describe-services --cluster $ENVIRONMENT_NAME --service maintenance --region $REGION | jq -r '.services[].desiredCount') != 0 ]; then
        echo "INFO - Environment $ENVIRONMENT_NAME is already in maintenance mode."
        echo "INFO - Toggling maintenance mode off."
        disableMaintenanceMode
    else
        echo "INFO - Environment $ENVIRONMENT_NAME is not in maintenance mode."
        echo "INFO - Toggling maintenance mode on."
        enableMaintenanceMode
    fi
}

enableMaintenanceMode() {
    # Lookup all ECS Services in Cluster
    local SERVICES=$(aws ecs list-services --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".serviceArns.[]")
    # Loop Through ECS Service List and Scale to Zero.
    for SERVICE in $SERVICES;
    do
        updateService $SERVICE "0"
    done

    echo "INFO - Starting Maintenance Service"
    # Scale up the Maintenance Service
    updateService "maintenance" "1"
    # Once Stable Redirect All Traffic to the Maintenance Task
    waitForServiceStable "maintenance"
    redirectToMaintenance

    # Disable All EventBridge Rules for this Environment on the Default Event Bus
    updateEventBusRules "default" "DISABLED"
    # Disable All EventBridge Rules for this Environment on the POAS Event Bus
    updateEventBusRules "$ENVIRONMENT_NAME-poas" "DISABLED"

    # Enable all Glue Job Triggers
    updateGlueJobTriggers "DISABLED"
}

disableMaintenanceMode() {
    # Lookup all ECS Services in Cluster
    local SERVICES=$(aws ecs list-services --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".serviceArns.[]")
    # Loop through ECS Services, look up Production Scale in Service Counts Array and scale up to normal Level
    for SERVICE in $SERVICES;
    do
        local SERVICE_NAME=$(aws ecs describe-services --service $SERVICE --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".services[].serviceName")
        updateService $SERVICE_NAME ${DESIRED_SERVICE_COUNTS[$SERVICE_NAME]:-"1"}
    done

    # Once Frontend Service is stable disable the redirect to the maintenance service
    waitForServiceStable "frontend"
    redirectFromMaintenance

    echo "INFO - Stopping Maintenance Service"
    # Scale down the maintenance service
    updateService "maintenance" "0"
    waitForServiceStable "maintenance"

    # Enable All EventBridge Rules for this Environment on the Default Event Bus
    updateEventBusRules "default" "ENABLED"
    # Enable All EventBridge Rules for this Environment on the POAS Event Bus
    updateEventBusRules "$ENVIRONMENT_NAME-poas" "ENABLED"

    # Enable all Glue Job Triggers
    updateGlueJobTriggers "ENABLED"
}

getLoadBalancerRuleArn() {
    # Lookup Primary ELB for Environment
    local ELB_ARN=$(aws elbv2 describe-load-balancers --names $ENVIRONMENT_NAME --region $REGION | jq -r ".LoadBalancers.[].LoadBalancerArn")
    # Lookup the HTTPS Listener for the ELB
    local LISTERN_ARN=$(aws elbv2 describe-listeners --region $REGION --load-balancer-arn $ELB_ARN | jq -r '.Listeners[] | select(.Protocol == "HTTPS") | .ListenerArn')
    # Lookup the ARN of the highest priority rule on the listener
    local RULE_ARN=$(aws elbv2 describe-rules --listener-arn $LISTERN_ARN | jq -r '.Rules[] | select(.Priority == "1") | .RuleArn')
    echo $RULE_ARN
}

redirectToMaintenance() {
    local ELB_RULE_ARN=$(getLoadBalancerRuleArn)
    echo "INFO - Redirecting $ENVIRONMENT_NAME to maintenance page."
    # Modify ELB Rule to send all traffic to maintenance service
    if aws elbv2 modify-rule --region $REGION --rule-arn $ELB_RULE_ARN --conditions '[{"Field": "path-pattern","PathPatternConfig": { "Values": ["/*"] }}]' --no-cli-pager; then
        echo "INFO - Redirected to Maintenance."
    else
        echo "ERROR - Redirecting to Maintenance failed!"
        exit 1
    fi
}

redirectFromMaintenance() {
    local ELB_RULE_ARN=$(getLoadBalancerRuleArn)
    echo "INFO - Redirecting $ENVIRONMENT_NAME from maintenance page."
    # Modify ELB Rule to no longer intercept all traffic
    if aws elbv2 modify-rule --region $REGION --rule-arn $ELB_RULE_ARN --conditions '[{"Field": "path-pattern","PathPatternConfig": { "Values": ["/maintenance/*"] }}]' --no-cli-pager; then
        echo "INFO - Redirected from Maintenance."
    else
        echo "ERROR - Redirecting from Maintenance failed!"
        exit 1
    fi
}

validateEnvironment
toggleMaintenanceMode