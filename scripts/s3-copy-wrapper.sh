#! /usr/bin/env bash

set -e
set -o pipefail

if [ -z "$SOURCE_PATH" ]; then
    echo "ERROR - You need to set the SOURCE_PATH environment variable."
    exit 1
fi

if [ -z "$DESTINATION_PATH" ]; then
    echo "ERROR - You need to set the DESTINATION_PATH environment variable."
    exit 1
fi

if [ -z "$COMMAND" ]; then
    echo "ERROR - You need to set the COMMAND environment variable."
    exit 1
fi

if [ "$COMMAND" != "cp" ] && [ "$COMMAND" != "sync" ]; then
    echo "ERROR - COMMAND must be one of 'cp' or 'sync'."
    exit 1
fi

if [ -z "$DRY_RUN" ]; then
    DRY_RUN_FLAG=""
else
    DRY_RUN_FLAG="--dryrun"
    echo "INFO - Dry Run Flag set, no data will be transferred"
fi

echo "INFO - $COMMAND-ing $SOURCE_PATH to $DESTINATION_PATH"
aws s3 $COMMAND $SOURCE_PATH $DESTINATION_PATH --sse --acl bucket-owner-full-control $DRY_RUN_FLAG
echo "INFO - $COMMAND Complete"
