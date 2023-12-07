#! /usr/bin/env bash

set -e
set -o pipefail

. common.sh

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

checkMaintenanceMode() {
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
    local SERVICES=$(aws ecs list-services --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".serviceArns.[]")
    for SERVICE in $SERVICES;
    do
        updateService $SERVICE "0"
    done

    echo "INFO - Starting Maintenance Service"
    updateService "maintenance" "1"
    waitForServiceStable "maintenance"
    redirectToMaintenance
}

disableMaintenanceMode() {
    local SERVICES=$(aws ecs list-services --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".serviceArns.[]")
    for SERVICE in $SERVICES;
    do
        local SERVICE_NAME=$(aws ecs describe-services --service $SERVICE --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".services[].serviceName")
        updateService $SERVICE_NAME ${DESIRED_SERVICE_COUNTS[$SERVICE_NAME]:-"1"}
    done

    waitForServiceStable "frontend"
    redirectFromMaintenance

    echo "INFO - Stopping Maintenance Service"
    updateService "maintenance" "0"
    waitForServiceStable "maintenance"
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

getLoadBalancerRuleArn() {
    local ELB_ARN=$(aws elbv2 describe-load-balancers --names $ENVIRONMENT_NAME --region $REGION | jq -r ".LoadBalancers.[].LoadBalancerArn")
    local LISTERN_ARN=$(aws elbv2 describe-listeners --region $REGION --load-balancer-arn $ELB_ARN | jq -r '.Listeners[] | select(.Protocol == "HTTPS") | .ListenerArn')
    local RULE_ARN=$(aws elbv2 describe-rules --listener-arn $LISTERN_ARN | jq -r '.Rules[] | select(.Priority == "1") | .RuleArn')
    echo $RULE_ARN
}

redirectToMaintenance() {
    local ELB_RULE_ARN=$(getLoadBalancerRuleArn)
    echo "INFO - Redirecting $ENVIRONMENT_NAME to maintenance page."
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
    if aws elbv2 modify-rule --region $REGION --rule-arn $ELB_RULE_ARN --conditions '[{"Field": "path-pattern","PathPatternConfig": { "Values": ["/maintenance/*"] }}]' --no-cli-pager; then
        echo "INFO - Redirected from Maintenance."
    else
        echo "ERROR - Redirecting from Maintenance failed!"
        exit 1
    fi
}

validateEnvironment
checkMaintenanceMode
