# from botocore.config import Config
import boto3
import logging
import os

logger = logging.getLogger()
logging.basicConfig()
logger.setLevel(logging.INFO)

# account_id = os.environ.get('ACCOUNT_ID')
table_name = os.environ.get('TABLE_NAME')
# environment_name = os.environ.get('ENVIRONMENT_NAME')
region_name = os.environ.get('AWS_REGION', 'eu-west-1')

logger.info('Script starting')

dynamo = boto3.client('dynamodb')

response = dynamo.scan(TableName=table_name)

logger.info(response)