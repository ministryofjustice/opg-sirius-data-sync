#! /usr/bin/env bash

set -e
set -o pipefail

. common.sh

validateEnvironment() {

    validateCommonEnvironment();

    if [ -z "$REGION" ]; then
    echo "ERROR - You need to set the REGION environment variable."
    exit 1
    fi
}
