# from botocore.config import Config
import boto3
import logging
import os
import psycopg2

logger = logging.getLogger()
logging.basicConfig()
logger.setLevel(logging.INFO)

# account_id = os.environ.get('ACCOUNT_ID')
environment_name = os.environ.get('ENVIRONMENT_NAME')
dynamo_table = os.environ.get('DYNAMO_TABLE')
assignees_access_password = os.environ.get('ASSIGNEES_ACCESS_PASSWORD')
# region_name = os.environ.get('AWS_REGION', 'eu-west-1')

logger.info('Script starting')

dynamo = boto3.client('dynamodb')

response = dynamo.scan(TableName=dynamo_table)
items = response['Items']

logger.info(items)

rds = boto3.client('rds')

instance = rds.describe_db_instances(DBInstanceIdentifier="opgcoreapi-"+environment_name)

logger.info(instance)

# instance.get('DBInstances')[0].get('Endpoint').get('Address')

# instance.get('DBInstances')[0].get('DBName')

# connection = psycopg2.connect(
#     database=PG_DATABASE,
#     user='assignees-access',
#     password=assignees_access_password,
#     host=PG_HOST,
#     port="5432"
# )