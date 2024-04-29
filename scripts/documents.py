import psycopg2
import os
import csv
import boto3
import re
from botocore.exceptions import ClientError

SOURCE_ENV = os.environ['SOURCE_ENV']
DESTINATION_ENV = os.environ['DESTINATION_ENV']

credentials = boto3.Session().get_credentials()

DEBUG = False

epa_lpa_query = """
    SELECT
    c.uid,
    c.casetype,
    CASE
        WHEN d.filename IN (
        'CT-bb.pdf',
        'DD-2.pdf',
        'EP-10.pdf',
        'EP-G.pdf',
        'EP-R.pdf',
        'EP-REG.pdf',
        'EP(bb).pdf',
        'EP-IMP.pdf',
        'LP-A.pdf',
        'LP-G1-4.pdf',
        'LP-G2-4.pdf',
        'LP-G2D-4.pdf',
        'LP-INC.pdf',
        'LP-INV-3A.pdf',
        'LP-INV-3B.pdf',
        'LP-J.pdf',
        'LP-NA-3A.pdf',
        'LP-NB-3B.pdf',
        'LP-R.pdf',
        'LP1F.pdf'
        )
        THEN CONCAT(CAST(d.id AS TEXT),'_',d.filename)
        ELSE d.filename
    END as s3_name
    FROM
    cases c
    INNER JOIN persons p
    ON c.donor_id = p.id
    INNER JOIN caseitem_document cid
    ON c.id = cid.caseitem_id
    	INNER JOIN documents d
    	ON cid.document_id = d.id
    WHERE
    c.uid = {case}
    UNION ALL
    SELECT
    c.uid,
    c.casetype,
    d.filename
    FROM
    cases c
    INNER JOIN persons p
    ON c.donor_id = p.id
    INNER JOIN person_note pn
    ON p.id = pn.person_id
    INNER JOIN notes n
    ON pn.note_id = n.id
    INNER JOIN documents d
    ON n.document_id = d.id
    WHERE
    c.uid = {case}
    UNION ALL
    SELECT
    c.uid,
    c.casetype,
    d.filename
    FROM
    cases c
    INNER JOIN persons p
    ON c.donor_id = p.id
    INNER JOIN person_document pd
    ON p.id = pd.person_id
    INNER JOIN documents d
    ON pd.document_id = d.id
    WHERE
    c.uid = {case};
    """

supervision_query = """
    SELECT
    c.uid,
    c.casetype,
    d.filename
    FROM
    cases c
    INNER JOIN persons p
    ON c.client_id = p.id
    INNER JOIN caseitem_document cid
    ON c.id = cid.caseitem_id
    	INNER JOIN documents d
    	ON cid.document_id = d.id
    WHERE
    c.uid = {case}
    AND
    d.content IS NULL
    UNION ALL
    SELECT
    c.uid,
    c.casetype,
    d.filename
    FROM
    cases c
    INNER JOIN persons p
    ON c.client_id = p.id
    	INNER JOIN person_document pd
    	ON p.id = pd.person_id
    		INNER JOIN documents d
    		ON pd.document_id = d.id
    WHERE c.uid = {case}
    AND
    d.content IS NULL;
    """

clients_query = """
SELECT
    p.caserecnumber,
    p.type,
    d.filename
FROM persons p
    INNER JOIN person_document pd ON p.id = pd.person_id
    INNER JOIN documents d ON pd.document_id = d.id
WHERE p.caserecnumber = '{case}';
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


def get_documents(query, case):
    cursor.execute(query.format(case=case))
    documents = cursor.fetchall()
    for document in documents:
        if DEBUG:
            print(
                "Case Reference = {case_ref} Case Type = {case_type}, Document Storage Name = {doc_name}".format(
                    case_ref=document[0],
                    case_type=document[1],
                    doc_name=document[2]
                )
            )
        else:
            copy_document(
                'opg-backoffice-datastore-'+SOURCE_ENV,
                'opg-backoffice-datastore-'+DESTINATION_ENV,
                document[2])
            print('document ' + document[2] + ' copied to destination bucket')


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

# Open CSV of Test Cases
with open('cases.csv', newline='') as file:
    contents = csv.reader(file)
    ids = list(contents)
    cases = []
    clients = []
    for id in ids:
        if re.search(r'\d{4}-\d{4}-\d{4}', str(id)):
            cases.append(id)
            if DEBUG:
                print("Appended to cases: ", id)
        else:
            clients.append(id)
            if DEBUG:
                print("Appended to clients: ", id)

for case in cases:
    case = case[0].replace("-", "")
    cursor = connection.cursor()
    cursor.execute(
        "SELECT uid, casetype FROM cases WHERE uid = {case}".format(case=case))
    case = cursor.fetchall()
    case_ref = str(case[0][0])
    case_type = case[0][1]
    # Check if case is LPA or ORDER
    if (case_type == "LPA") or (case_type == "EPA"):
        print("Getting {case_type} Docs for:".format(
            case_type=case_type), case_ref)
        get_documents(epa_lpa_query, case_ref)
    if case_type == "ORDER":
        print("Getting ORDER Docs for:", case_ref)
        get_documents(supervision_query, case_ref)

for client in clients:
    cursor = connection.cursor()
    get_documents(clients_query, str(client[0]))

print("Operation done successfully")