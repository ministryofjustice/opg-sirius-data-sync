#CasRec Data Migration Backup & Rollback Scripts

There are two scripts for the CasRec Migration; the first is a script to create a pre-migration snapshot of the production database and then create a re-encrypted copy of that snapshot so that it can be copied into the preproduction environment for testing.

The second script is for a rollback of the production database to the snapshot point created by the first script.  Due to production API being a global Aurora Cluster the rollback is rather complex.

##Executing the Scripts

Both scripts should be executed from a Cloud9 instance created with the `breakglass` role in the production account.  Details of how to setup, install required tooling, and point at the production database are detailed [here](https://github.com/ministryofjustice/opg-sirius/tree/master/scripts/cloud9).  **Make sure when creating the instance to set the cost saving auto shutdown to Never**

Once you instance is setup and configured. You can copy the scripts in this folder over to the instance and ensure they have executable permissions `chmod +x {filename}`.

Both scripts have some default configuration at the top of each file so ensure they are set correctly.

The snapshot script will by default create a snapshot in the format `pre-migration-snapshot-api-YYYYYMMDDHHMM` so it can be re-run without needing to tidy up any existing snapshots, the re-encrypted copy that it creates will be deleted and recreated by the script as appropriate and it will always called `api-snpshot-for-copy`. This is to allow it to be picked up by the existing data sync scripts in preproduction.

## Restoring into one of the Preproduction Environments

To restore into preproduction you will need to execute some of the existing data sync task for the environment that you want to restore into.  Documentation on running adhoc ECS Tasks is [here](https://docs.sirius.opg.service.justice.gov.uk/documentation/infrastructure/run_aws_task/#run-tasks-in-aws).

The tasks that need to be executed for a given environment are, in order:
- `copy-shared-snapshot-api` This will create a copy of the encrypted snapshot in the preproduction account with the correct KMS keys to allow it to be restored.
- `restore-database-snapshot-api` This will delete the existing cluster and restore the snapshot in it's place.
- `restore-elasticsearch7-snapshot` (Optional) Restore that morning's production Elasticsearch snapshot.

Restoring membrane shouldn't be necessary but if it is run the `copy-shared-snapshot-membrane` & `restore-database-snapshot-membrane` tasks in order.

## Restoring Production

Should the worst case scenario happen and the migration has catastrophically failed, cannot be fixed forward and needs restoring, then ensure the `SNAPSHOT_FOR_RESTORE` configuration is set to the correct snapshot that you want to restore, ensure the rest of the setup configuration is correct and execute the script. You can expect a full restore to take about 2 hours in total, progress can be tracked via the script output and the WS RDS Console.

Should the script fail at any point and you need to manually set the derived parameters they will all have been printed out in the initial run of the script. Paste them in at the top, hash out everything that was successful and run the script again.
