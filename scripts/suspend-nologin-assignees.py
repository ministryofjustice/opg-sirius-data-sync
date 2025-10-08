
import boto3
import logging
import os
import psycopg

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

def getAllUsers():
    scan_args = {
        'TableName': DYNAMO_TABLE,
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

def suspendNologinAssignees(activeEmails):
    LOGGER.info("Connecting to DB...")
    with psycopg.connect(
        dbname=RDS_DB_NAME,
        user='assignees-access',
        password=ASSIGNEES_ACCESS_PASSWORD,
        host=PG_HOST,
        port=PG_PORT
    ) as connection:
        
        with connection.cursor() as cursor:
            cursor.execute("SELECT email FROM assignees WHERE suspended = TRUE;")
            suspended_assignees = [row[0] for row in cursor.fetchall()]
            
            if suspended_assignees:
                query = "UPDATE assignees SET suspended = FALSE WHERE email = ANY(%s);"
                cursor.execute(query, (suspended_assignees,))
                LOGGER.info(f"unsuspended {len(suspended_assignees)} assignees.")
            else:
                LOGGER.info("No suspended assignees found.")
        
        LOGGER.info('Suspending assignees never logged in...')
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM assignees WHERE suspended = TRUE;")
            count = cursor.fetchone()[0]
            LOGGER.info(f"Suspended assignees: {count}")
        with connection.cursor() as cursor:
            cursor.execute("SELECT email FROM assignees WHERE suspended = FALSE AND email IS NOT NULL;")
            unsuspended_assignees = [row[0] for row in cursor.fetchall()]
            
            nologin_emails = list(set(unsuspended_assignees) - set(activeEmails))
            
            if nologin_emails:
                query = "UPDATE assignees SET suspended = TRUE WHERE email = ANY(%s);"
                cursor.execute(query, (nologin_emails,))
                LOGGER.info(f"Suspended {len(nologin_emails)} missing assignees.")
            else:
                LOGGER.info("No missing assignees found.")
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM assignees WHERE suspended = TRUE;")
            count = cursor.fetchone()[0]
            LOGGER.info(f"Suspended assignees: {count}")

# MAIN FUNCTION
LOGGER.info("Getting all users from DynamoDB...")
allUsers = getAllUsers()

if not allUsers:
    LOGGER.warning("No users found in DynamoDB.")
else:
    activeEmails = [user['email']['S'] for user in allUsers]
    suspendNologinAssignees(activeEmails)
