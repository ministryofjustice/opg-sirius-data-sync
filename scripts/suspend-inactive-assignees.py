import boto3
import logging
import os
import psycopg
import datetime
import time
from dateutil.relativedelta import relativedelta  

EXPIRE_DATE = (datetime.datetime.now().date() - relativedelta(months=3)).strftime("%Y-%m-%d")

LOGGER = logging.getLogger()
logging.basicConfig()
LOGGER.setLevel(logging.INFO)

ASSIGNEES_ACCESS_PASSWORD = os.environ.get('ASSIGNEES_ACCESS_PASSWORD')
DYNAMO_TABLE = os.environ.get('DYNAMO_TABLE')
RDS_DB_NAME = os.environ.get('RDS_DB_NAME')
PG_HOST = os.environ.get('PG_HOST')
PG_PORT = os.environ.get('PG_PORT')

LOGGER.info('Script starting')
DYNAMO_CLIENT = boto3.client('dynamodb')

def getExpiredUsers():
    scan_args = {
        'TableName': DYNAMO_TABLE,
        'FilterExpression': '#time < :expire',
        'ExpressionAttributeNames': {
            '#time': 'time'
        },
        'ExpressionAttributeValues': {
            ':expire': {'S': EXPIRE_DATE}
        },
        'ProjectionExpression': 'email'
    }

    items = []
    last_evaluated_key = None
    while True:
        if last_evaluated_key:
            scan_args['ExclusiveStartKey'] = last_evaluated_key
        response = DYNAMO_CLIENT.scan(**scan_args)
        items.extend(response.get('Items', []))

        last_evaluated_key = response.get('LastEvaluatedKey')
        if not last_evaluated_key:
            break

    return items


def deleteExpiredUsers(items, batchSize = 25, max_retries=5):

    for i in range(0, len(items), batchSize):
        batch_items = items[i:i + batchSize]
        request_items = {
            DYNAMO_TABLE: [
                {'DeleteRequest': {'Key': item}} for item in batch_items
            ]
        }
        
        retries = 0
        while True:
            response = DYNAMO_CLIENT.batch_write_item(RequestItems=request_items)
            unprocessed = response.get('UnprocessedItems', {})

            if not unprocessed or DYNAMO_TABLE not in unprocessed:
                LOGGER.info(f"Deleted {len(batch_items)} items from DynamoDB.")
                break

            if retries > max_retries:
                LOGGER.error(f"Max retries reached. Unprocessed items: {len(unprocessed)}")
                break

            LOGGER.warning(f"Retrying unprocessed items (attempt {retries})...")
            request_items = unprocessed
            retries += 1
            time.sleep(1)

def supendInactiveAssignees(expiredEmails):
    LOGGER.info("Connecting to DB...")
    with psycopg.connect(
        dbname=RDS_DB_NAME,
        user='assignees-access',
        password=ASSIGNEES_ACCESS_PASSWORD,
        host=PG_HOST,
        port=PG_PORT
    ) as connection:
        
        LOGGER.info('Suspending inactive Assignees...')
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM assignees WHERE suspended = TRUE;")
            count = cursor.fetchone()[0]
            LOGGER.info(f"Suspended assignees: {count}")
        with connection.cursor() as cursor:
            query = "UPDATE assignees SET suspended = TRUE WHERE email = ANY(%s);"
            cursor.execute(query, (expiredEmails,))
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM assignees WHERE suspended = TRUE;")
            count = cursor.fetchone()[0]
            LOGGER.info(f"Suspended assignees: {count}")

# MAIN FUNCTION
LOGGER.info("Getting users last logged in more than 3 months ago...")
expiredUsers = getExpiredUsers()

if not expiredUsers:
    LOGGER.warning("No expired users found. Skipping suspention.")
else:
    expiredEmails = [user['email']['S'] for user in expiredUsers]
    
    supendInactiveAssignees(expiredEmails)

    LOGGER.info(f"Removing {len(expiredUsers)} users last logged in more than 3 months ago (from DynamoDB)...")
    deleteExpiredUsers(expiredUsers)
