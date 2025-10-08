# from botocore.config import Config
import boto3
import logging
import os
import psycopg

logger = logging.getLogger()
logging.basicConfig()
logger.setLevel(logging.INFO)

# account_id = os.environ.get('ACCOUNT_ID')
# environment_name = os.environ.get('ENVIRONMENT_NAME')
# region_name = os.environ.get('AWS_REGION', 'eu-west-1')
assignees_access_password = os.environ.get('ASSIGNEES_ACCESS_PASSWORD')
dynamo_table = os.environ.get('DYNAMO_TABLE')
rds_db_name = os.environ.get('RDS_DB_NAME')
pg_host = os.environ.get('PG_HOST')
pg_port = os.environ.get('PG_PORT')

logger.info('Script starting')

dynamo = boto3.client('dynamodb')

response = dynamo.scan(TableName=dynamo_table)
items = response['Items']

logger.info(items)

connection = psycopg.connect(
    database=rds_db_name,
    user='assignees-access',
    password=assignees_access_password,
    host=pg_host,
    port=pg_port
)

cursor = connection.execute("SELECT * FROM assignees")

print(cursor.fetchall())