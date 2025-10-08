from botocore.config import Config
import boto3
import logging
import os

logger = logging.getLogger()
logging.basicConfig()
logger.setLevel(logging.INFO)

# account_id = os.environ.get('ACCOUNT_ID')
# database_name = os.environ.get('DATABASE_NAME')
# environment_name = os.environ.get('ENVIRONMENT_NAME')
region_name = os.environ.get('AWS_REGION', 'eu-west-1')
remote_role_arn = os.environ.get('REMOTE_ROLE_ARN')

sts_client = boto3.client('sts')

response = sts_client.assume_role(RoleArn=remote_role_arn, RoleSessionName='suspend_assignees')

session = boto3.Session(aws_access_key_id=response['Credentials']['AccessKeyId'],
            aws_secret_access_key=response['Credentials']['SecretAccessKey'],
            aws_session_token=response['Credentials']['SessionToken'])


logger.info('Script starting')

dynamo_config = Config(
        region_name = region_name,
    )

dynamo = session.client('dynamodb', config=dynamo_config)

response = dynamo.list_tables(
    Limit=15
)

logger.info(response)