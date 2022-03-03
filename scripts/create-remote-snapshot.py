from botocore.config import Config
import boto3
import botocore
import os
import sys

sts_client = boto3.client('sts')

account_id = os.environ.get('ACCOUNT_ID')
database_name = os.environ.get('DATABASE_NAME')
environment_name = os.environ.get('ENVIRONMENT_NAME')
region_name = os.environ.get('AWS_REGION', 'eu-west-1')
remote_role_arn = os.environ.get('REMOTE_ROLE_ARN')

source_snapshot = (f'arn:aws:rds:{region_name}:{account_id}:cluster-snapshot:{database_name}-{environment_name}-snapshot-for-backup')
remote_snapshot = (f'{database_name}-{environment_name}-snapshot')

response = sts_client.assume_role(RoleArn=remote_role_arn, RoleSessionName='cross_account_backup')

session = boto3.Session(aws_access_key_id=response['Credentials']['AccessKeyId'],
            aws_secret_access_key=response['Credentials']['SecretAccessKey'],
            aws_session_token=response['Credentials']['SessionToken'])

my_config = Config(
        region_name = region_name,
    )

remote_rds = session.client('rds', config=my_config)


try:
    remote_rds.describe_db_cluster_snapshots(
        DBClusterSnapshotIdentifier=source_snapshot,
        IncludeShared=True
    )
except remote_rds.exceptions.DBClusterSnapshotNotFoundFault:
    sys.exit('Source snapshot not found.')
else:
    try:
        print('Deleting remote snapshot')
        
        remote_rds.describe_db_cluster_snapshots(
            DBClusterSnapshotIdentifier=remote_snapshot,
            IncludeShared=True
        )
    except remote_rds.exceptions.DBClusterSnapshotNotFoundFault:
        print('Remote snapshot not found.')
    else:
        response = remote_rds.delete_db_cluster_snapshot(
            DBClusterSnapshotIdentifier=remote_snapshot
        )
        
        waiter = remote_rds.get_waiter('db_cluster_snapshot_deleted')
        
        waiter.wait(
            DBClusterSnapshotIdentifier=remote_snapshot,
        )
    
    print('Creating remote snapshot copy')
    
    response = remote_rds.copy_db_cluster_snapshot(
    SourceDBClusterSnapshotIdentifier=source_snapshot,
    TargetDBClusterSnapshotIdentifier=remote_snapshot,
    KmsKeyId='alias/aws/rds',
    CopyTags=False,
    )
    
    waiter = remote_rds.get_waiter('db_cluster_snapshot_available')
    
    waiter.wait(
        DBClusterSnapshotIdentifier=response['DBClusterSnapshot']['DBClusterSnapshotArn'],
        )

    print('Snapshot copied successfully')