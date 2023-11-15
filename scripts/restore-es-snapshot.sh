#! /usr/bin/env sh

set -e
set -o pipefail

. create-es-snapshot-repo.sh

if [ "$ENVIRONMENT_NAME" = "production" ]; then
    echo "ERROR - You cannot restore the production Elasticsearch Indices."
    exit 1
fi

check_elastic_restore() {
    COMPLETED=1
    INDEX_NAME=$(curl -s "https://$ES_VPC_ENDPOINT/_cat/aliases/person?format=json" | jq -r '.[].index')
    for SHARD in $(curl -s "https://$ES_VPC_ENDPOINT/$INDEX_NAME/_recovery?pretty" | jq -r '.'$INDEX_NAME'.shards[].index.files.percent')
    do
        if [ "$SHARD" != "100.0%" ];
        then
            COMPLETED=0
        fi
    done
    return $COMPLETED
}

wait_for_elastic_to_restore() {
    while check_elastic_restore
    do
        echo "INFO - Waiting for Elasticsearch Snapshot Restore to Complete..."
        sleep 60
    done
    echo "INFO - Elasticsearch Snapshot Restore Complete"
}

echo "INFO - Checking if sync-snapshot exists..."
if curl -fsS -XGET "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot?pretty";
then
    echo "INFO - Snapshot found. Continuing..."
else
    echo "ERROR - No snapshot found."
    exit 1
fi

echo "INFO - Deleting Existing Indices..."
if curl -fsS -XDELETE "https://$ES_VPC_ENDPOINT/_all?expand_wildcards=all";
then
    echo "INFO - Indices deleted."
else
    echo "ERROR - Index deletion Failed"
    exit 1
fi

echo "INFO - Restoring Indices from snapshot"
if curl -fsS -XPOST "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot/_restore";
then
    echo "INFO - Restoring Elasticsearch Snapshot"
    sleep 10
else
    echo "ERROR - Restore of snapshot failed."
    exit 1
fi

wait_for_elastic_to_restore

echo "INFO - Restore of Elasticsearch complete."
