import psycopg2
import os
import boto3
from botocore.exceptions import ClientError

SOURCE_ENV = os.environ['SOURCE_ENV']
DESTINATION_ENV = os.environ['DESTINATION_ENV']

credentials = boto3.Session().get_credentials()

DEBUG = True

supervision_query = """
    SELECT
    documents.filename,
    documents.uuid
    FROM documents
    LEFT JOIN caseitem_document cd ON documents.id = cd.document_id
    LEFT JOIN cases ON cd.caseitem_id = cases.id
    LEFT JOIN persons clients ON cases.client_id = clients.id
    LEFT JOIN persons feepayers ON clients.feepayer_id = feepayers.id
    WHERE CAST(publisheddate AS DATE) >= '2024-04-19'
    AND (feepayers.email = '' OR feepayers.email IS NULL)
    AND systemtype = 'af2';
    """


def describe_pg_host(environment):
    rds = boto3.client('rds')
    instance = rds.describe_db_instances(
        DBInstanceIdentifier="opgcoreapi-"+environment)
    return instance.get('DBInstances')[0].get('Endpoint').get('Address')


def describe_pg_user(environment):
    rds = boto3.client('rds')
    instance = rds.describe_db_instances(
        DBInstanceIdentifier="opgcoreapi-"+environment)
    return instance.get('DBInstances')[0].get('MasterUsername')


def describe_pg_database(environment):
    rds = boto3.client('rds')
    instance = rds.describe_db_instances(
        DBInstanceIdentifier="opgcoreapi-"+environment)
    return instance.get('DBInstances')[0].get('DBName')


def get_pg_password():
    secret_name = 'rds-api-'+DESTINATION_ENV

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name="eu-west-1",
    )

    get_secret_value_response = client.get_secret_value(
        SecretId=secret_name
    )

    return get_secret_value_response['SecretString']


def copy_document(src_bucket_name, dest_bucket_name, document_name):
    s3 = boto3.resource('s3')

    copy_source = {
        'Bucket': src_bucket_name,
        'Key': document_name
    }
    try:
        bucket = s3.Bucket(dest_bucket_name)
        bucket.copy(copy_source, document_name, ExtraArgs={
            'ServerSideEncryption': 'AES256'})

    except ClientError as e:
        print(e, " " + document_name)
        return False
    return True


def get_documents(query):
    cursor.execute(query)
    documents = cursor.fetchall()
    for document in documents:
        if DEBUG:
            print(
                "Document Storage Name = {doc_name}".format(
                    doc_name=document[0]
                )
            )
        else:
            copy_document(
                'opg-backoffice-datastore-'+SOURCE_ENV,
                'opg-backoffice-datastore-'+DESTINATION_ENV,
                document[0])
            print('document ' + document[0] + ' copied to destination bucket')


PG_DATABASE = describe_pg_database(DESTINATION_ENV)
PG_HOST = describe_pg_host(DESTINATION_ENV)
PG_USER = describe_pg_user(DESTINATION_ENV)
PG_PASSWORD = get_pg_password()

connection = psycopg2.connect(
    database=PG_DATABASE,
    user=PG_USER,
    password=PG_PASSWORD,
    host=PG_HOST,
    port="5432"
)
print("Database opened successfully")

cursor = connection.cursor()
get_documents(supervision_query)

print("Operation done successfully")
