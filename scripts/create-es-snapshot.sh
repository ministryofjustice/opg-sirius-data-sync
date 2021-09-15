#! /usr/bin/env sh

set -e
set -o pipefail

. create-es-snapshot-repo.sh

echo "INFO - Checking if sync-snapshot exists..."
if curl -fsS -XGET "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot?pretty";
then
    echo "INFO - Snapshot found. Deleting..."
    curl -fsS -XDELETE "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot?pretty"
    echo "INFO - Snapshot Deleted"
else
    echo "INFO - No snapshot found."
fi

echo "INFO - Creating Snapshot"
if curl -fsS -XPUT "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot?wait_for_completion=true&pretty";
then
    echo "INFO - Snapshot Complete."
else
    echo "ERROR - Snapshot Failed"
    exit 1
fi
