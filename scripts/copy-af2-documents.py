import shutil
import time
import psycopg2
import os
import boto3
import botocore
import logging
import zipfile

# Copy this script to the root of a Clou9 Environment where the source S3 bucket
# is readable and the target S3 bucket is writeable
# 
# Create a source file af2_user_ids.txt in the same directory as this script,
# with a separate client id (DB: persons.id) on each newline
# (in this way we can easily paste the client Ids from the source spreadsheet)
#
# install python modules (first run only)
# pip install boto3 psycopg2-binary requests
#
# Set up env vars for DB (first run only)
# . ./setup.sh [environment]
#
# run
# python3 copy-af2-documents.py
#
# Each successive run will create a new working directory, inside which will be 
# a log files and a data directory holding the zip files
#
# TODO: The contents of this working directory to be sent to target S3 bucket

credentials = boto3.Session().get_credentials()

PG_DATABASE = os.environ['PGDATABASE']
PG_HOST = os.environ['PGHOST']
PG_USER = os.environ['PGUSER']
PG_PASSWORD = os.environ['PGPASSWORD']

run_timestamp = int(time.time())
run_output_dir = 'run_' + str(run_timestamp)

clients_source_file = 'af2_user_ids.txt'
logfile_path = os.path.join(run_output_dir, 'adhoc_run.log')
zip_batch_size = 10
bucket_source = 'opg-backoffice-datastore-production'
bucket_destination = 's3-downloads.adhoc.eu-west-1.sirius.opg.justice.gov.uk'

os.makedirs(run_output_dir)

# Makes sense to log exactly what happened here today
with open(logfile_path, 'w'):
    pass
logging.basicConfig(filename=logfile_path, level=logging.INFO)

# Pretty quick this way as we keep WHERE clause away from whole documents table
base_query: str = """
    WITH clients AS (
        SELECT id, caserecnumber
        FROM persons WHERE id IN ({client_ids_string})
    ),
    case_doc_ids AS (
        SELECT DISTINCT 
        c.id case_id,
        clients.id client_id,
        clients.caserecnumber,
        cd.document_id
        FROM clients
        INNER JOIN cases c
            ON c.client_id = clients.id
        INNER JOIN caseitem_document cd
            ON cd.caseitem_id = c.id
    ),
    case_docs AS (
        SELECT
        d.id,
        d.systemtype,
        d.filename,
        d.publisheddate
        FROM case_doc_ids cdi
        INNER JOIN documents d
            ON d.id = cdi.document_id
    )
    SELECT
        cdi.client_id,
        cdi.caserecnumber,
        cdi.case_id,
        cd.id document_id,
        cd.systemtype,
        cd.filename,
        cd.publisheddate,
        CONCAT(cd.id, '_', cd.filename) s3_key
    FROM case_doc_ids cdi
    INNER JOIN case_docs cd
        ON cd.id = cdi.document_id
    WHERE cd.systemtype = 'af2'
    AND cd.publisheddate >= '2024-04-19'
    ORDER BY cdi.client_id ASC
    """


def read_client_ids_from_file(file_path):
    with open(file_path, 'r') as file:
        ids = [line.strip() for line in file]
    return ids


def get_s3_object_keys(dbcursor, bucket):
    s3 = boto3.resource('s3')
    object_keys = []
    object_missing = []
    for row in dbcursor:
        client_id = row[0]
        caseref = row[1]
        s3key = row[7]
        try:
            s3.Object(bucket_source, s3key).load()
        except botocore.exceptions.ClientError as e:
            if e.response['Error']['Code'] == "404":
                logging.error(f"{s3key}: NOT FOUND in s3. client id: {client_id}, case ref: {caseref}")
                object_missing.append(s3key)
            else:
                logging.error(f"Error when searching for {s3key}. client id: {client_id}, case ref: {caseref}")
                object_missing.append(s3key)
                raise
        else:
            object_keys.append(s3key)
            logging.info(f"{s3key}: FOUND OK in s3. client id: {client_id}, case number: {caseref}")

    logging.info(f"Found in S3: {len(object_keys)} of {dbcursor.rowcount}, Failed: {len(object_missing)}")
    return object_keys, object_missing


def save_in_batches(bucket, keys, output_dir, batchsize):
    s3client = boto3.client('s3')
    for i in range(0, len(keys), batchsize):
        batch_keys = keys[i:i + batchsize]

        batch_dirname = os.path.join(f'{output_dir}', 'data', f'batch_{i // batchsize}')

        if not os.path.exists(batch_dirname):
            logging.info(f"Creating batch directory {batch_dirname}")
            os.makedirs(batch_dirname)

        # Download resources in the batch
        for key in batch_keys:
            filepath = os.path.join(batch_dirname, key)
            s3client.download_file(bucket, key, filepath)
            # logging.info(f"Downloaded S3 resource {key} to {filepath}")

        zip_directory(batch_dirname)

        # Delete dir again
        shutil.rmtree(batch_dirname)


def zip_directory(directory):
    zip_path = f'{directory}.zip'
    with zipfile.ZipFile(zip_path, 'w') as zipf:
        # Walk through the directory and add files to the zip file
        for root, _, files in os.walk(directory):
            for file in files:
                file_path = os.path.join(root, file)
                zipf.write(file_path, os.path.relpath(file_path, directory))
                logging.info(f"Added {file_path} to {zip_path}")


connection = psycopg2.connect(
    database=PG_DATABASE,
    user=PG_USER,
    password=PG_PASSWORD,
    host=PG_HOST,
    port="5432"
)

cursor = connection.cursor()
logging.info("Database opened successfully")

source_client_ids = read_client_ids_from_file(clients_source_file)
logging.info(f"{len(source_client_ids)} client ids found in source file")

clients_list = ', '.join(source_client_ids)
sql_query = base_query.format(client_ids_string=clients_list)
logging.info(f"SQL query used: {sql_query}")

cursor.execute(sql_query)
logging.info(f"Matched {cursor.rowcount} rows in DB")

s3_object_keys, errors = get_s3_object_keys(cursor, bucket_source)

cursor.close()
connection.close()

save_in_batches(bucket_source, s3_object_keys, run_output_dir, zip_batch_size)
