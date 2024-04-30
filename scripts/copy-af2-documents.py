import psycopg2
import os
import boto3
import requests
from botocore.exceptions import ClientError

ENVIRONMENT = os.environ['ENVIRONMENT']

credentials = boto3.Session().get_credentials()

DEBUG = True

supervision_query = """
    SELECT
    documents.uuid,
    documents.content
    FROM documents
    LEFT JOIN caseitem_document cd ON documents.id = cd.document_id
    LEFT JOIN cases ON cd.caseitem_id = cases.id
    LEFT JOIN persons clients ON cases.client_id = clients.id
    LEFT JOIN persons feepayers ON clients.feepayer_id = feepayers.id
    WHERE CAST(publisheddate AS DATE) >= '2024-04-19'
    AND (feepayers.email = '' OR feepayers.email IS NULL)
    AND systemtype = 'af2'
    LIMIT 1;
    """

def generate_pdf(content):
    headers = {"Content-Type": "text/html"}

    url = 'http://pdf-service.adhoc.ecs/generate-pdf'

    r = requests.post(
        url,
        data=content,
        headers=headers
    )
    
    print(r.content)
    
def zip_batch(batch):
    print('test')


def get_documents(query):
    cursor.execute(query)
    documents = cursor.fetchall()
    pdfs = []
    batch = [];
    batches = [];
    for document in documents:
        pdf = generate_pdf(document[1])
        # batch.push(pdf)

        # if (batch.len() == 10) :
        #     # Zip batch, give it a nice name
        #     batches.push(zip_batch(batch))
        
        
        # if DEBUG:
        #     print(
        #         "Document Storage Uuid = {uuid}".format(
        #             uuid=document[0],
        #             content=document[1]
        #         )
        #     )
        # else:
        #     copy_document(
        #         'opg-backoffice-datastore-'+SOURCE_ENV,
        #         'opg-backoffice-datastore-'+DESTINATION_ENV,
        #         document[0])
        #     print('document ' + document[0] + ' copied to destination bucket')


PG_DATABASE = os.environ['PGDATABASE']
PG_HOST = os.environ['PGHOST']
PG_USER = os.environ['PGUSER']
PG_PASSWORD = os.environ['PGPASSWORD']

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
