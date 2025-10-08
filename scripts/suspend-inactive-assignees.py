# from botocore.config import Config
import boto3
import logging
import os
import psycopg2
import datetime
import time
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

def getExpiredUsers(client, dynamo_table, expire_date):
    scan_args = {
        'TableName': dynamo_table,
        'ExpressionAttributeNames': {
            "#email": "email",
            "#time": "time"
        },
        'ExpressionAttributeValues': {
            ':a': {'S': expire_date}
        },
        'FilterExpression': '#time < :a',
        'ProjectionExpression': '#email'
    }
    items = []
    last_evaluated_key = None

    while True:
        if last_evaluated_key:
            scan_args['ExclusiveStartKey'] = last_evaluated_key
        
        response = client.scan(**scan_args)
        items.extend(response.get('Items', []))

        last_evaluated_key = response.get('LastEvaluatedKey')

        if not last_evaluated_key:
            break

    return items

def deleteExpiredUsers(client, dynamo_table, items, batchSize = 2, max_retries=5):

    for i in range(0, len(items), batchSize):
        batch_items = items[i:i + batchSize]
        request_items = {
            dynamo_table: [
                {'DeleteRequest': {'Key': item}} for item in batch_items
            ]
        }

        logger.info(request_items)
        
        retries = 0
        while True:
            response = client.batch_write_item(RequestItems=request_items)
            unprocessed = response.get('UnprocessedItems', {})

            if not unprocessed or dynamo_table not in unprocessed:
                logger.info(f"Deleted {len(batch_items)} items from DynamoDB.")
                break

            if retries > max_retries:
                logger.error(f"Max retries reached. Unprocessed items: {len(unprocessed)}")
                break

            logger.warning(f"Retrying unprocessed items (attempt {retries})...")
            request_items = unprocessed
            retries += 1
            time.sleep(1)


# def getAllUsers(client):
#     response = client.scan(
#         TableName=dynamo_table,
#     )
#     items = response['Items']

#     while('LastEvaluatedKey' in response):
#         response = client.scan(
#             TableName=dynamo_table,
#             ExclusiveStartKey=response['LastEvaluatedKey']
#         )
#         items.append(response['Items'])
    
#     return items


expiredUsers = getExpiredUsers(dynamoClient, dynamo_table, expire_date)

logger.info(expiredUsers)

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