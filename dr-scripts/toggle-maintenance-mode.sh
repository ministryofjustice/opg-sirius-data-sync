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
        echo "ERROR - Already in maintenance mode."
        exit 1
    else
        echo "Environment $ENVIRONMENT_NAME is not in maintenance mode."
    fi
}

enableMaintenanceMode() {
    local SERVICES=$(aws ecs list-services --cluster $ENVIRONMENT_NAME --region $REGION | jq -r ".serviceArns.[]")
    for SERVICE in $SERVICES;
    do
        echo "INFO - Stopping Service $SERVICE"
        if aws ecs update-service --cluster $ENVIRONMENT_NAME --region $REGION --service $SERVICE --desired-count 0 --no-cli-pager; then
            echo "INFO - Updated $SERVICE Service."
        else
            echo "ERROR - $SERVICE Service Update Failed!"
            exit 1
        fi
    done

    echo "INFO - Starting Maintenance Service"
    if aws ecs update-service --cluster $ENVIRONMENT_NAME --region $REGION --service maintenance --desired-count 1 --no-cli-pager; then
        echo "INFO - Updated Maintenance Service."
    else
        echo "ERROR - Maintenance Service Update Failed!"
        exit 1
    fi
    waitForServiceStable "maintenance"
    redirectToMaintenance
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
    if aws elbv2 modify-rule --region eu-west-1 --rule-arn $ELB_RULE_ARN --conditions '[{"Field": "path-pattern","PathPatternConfig": { "Values": ["/*"] }}]' --no-cli-pager; then
        echo "INFO - Redirected to Maintenance."
    else
        echo "ERROR - Redirecting to Maintenance failed!"
        exit 1
    fi
}



validateEnvironment
checkMaintenanceMode
enableMaintenanceMode