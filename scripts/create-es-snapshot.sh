#! /usr/bin/env sh

set -e
set -o pipefail

. create-es-snapshot-repo.sh

check_elastic_snapshot() {
    COMPLETED=1
    for STATUS in $(curl -s "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot" | jq -r '.snapshots[].state')
    do
        if [ "$STATUS" != "SUCCESS" ];
        then
            COMPLETED=0
            if [ "$STATUS" != "IN_PROGRESS" ];
            then
                echo "ERROR - Snapshot Failed"
                exit 1
            fi
        fi
    done
    return $COMPLETED
}

wait_for_snapshot_to_complete() {
    while check_elastic_snapshot
    do
        echo "INFO - Waiting for Elasticsearch Snapshot to Complete..."
        sleep 60
    done
    echo "INFO - Elasticsearch Snapshot Complete"
}



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
if curl -fsS -XPUT "https://$ES_VPC_ENDPOINT/_snapshot/$ES_SNAPSHOT_REPO/sync-snapshot?pretty";
then
    echo "INFO - Snapshot Started."
else
    echo "ERROR - Snapshot Failed"
    exit 1
fi

wait_for_snapshot_to_complete
