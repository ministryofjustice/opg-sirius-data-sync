#! /usr/bin/env sh

set -e
set -o pipefail

. create-es-snapshot-repo.sh

if [ "$ENVIRONMENT_NAME" = "production" ]; then
    echo "ERROR - You cannot restore the production Elasticsearch Indices."
    exit 1
fi

echo "INFO - Checking if sync-snapshot exists..."
if curl -fsS -XGET "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot?pretty";
then
    echo "INFO - Snapshot found. Continuing..."
else
    echo "ERROR - No snapshot found."
    exit 1
fi

echo "INFO - Deleting Existing Indices..."
if curl -fsS -XDELETE "https://$ES_VPC_ENDPOINT/_all";
then
    echo "INFO - Indices deleted."
else
    echo "ERROR - Index deletion Failed"
    exit 1
fi

echo "INFO - Restoring Indices from snapshot"
if curl -fsS -XPOST "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot/_restore?wait_for_completion=true&pretty";
then
    echo "INFO - Restore of snapshot complete."
else
    echo "ERROR - Restore of snapshot failed."
    exit 1
fi

echo "INFO - Restore of Elasticsearch complete."
