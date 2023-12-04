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