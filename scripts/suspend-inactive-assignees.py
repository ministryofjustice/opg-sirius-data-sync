# from botocore.config import Config
import boto3
import logging
import os
import psycopg2
import datetime
from dateutil.relativedelta import relativedelta  

expire_date = (datetime.datetime.now().date() - relativedelta(months=3)).strftime("%Y-%m-%d")

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
dynamoClient = boto3.client('dynamodb')

def dynamoScan(client):
    response = client.scan(
    TableName=dynamo_table,
    Limit=3
    # ExpressionAttributeNames={
    #     "#time": "time"
    # },
    # ExpressionAttributeValues={
    #     ':a': {
    #         'S': expire_date,
    #     },
    # },
    # FilterExpression='#time < :a'
    )
    return response


response = dynamoScan(dynamoClient)

logger.info(response)

items = response['Items']

while('LastEvaluatedKey' in response):
    response = dynamoScan(dynamoClient)
    items.append(response['Items'])


logger.info(items)

# connection = psycopg2.connect(
#     database=rds_db_name,
#     user='assignees-access',
#     password=assignees_access_password,
#     host=pg_host,
#     port=pg_port
# )

# cursor = connection.cursor()
# cursor.execute("SELECT * FROM assignees;")

# print(cursor.fetchall())

# cursor.close()
# connection.close()