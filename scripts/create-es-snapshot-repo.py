import boto3
import os
import requests
from requests_aws4auth import AWS4Auth


ES_HOST = os.environ['ES_VPC_ENDPOINT']
REPO_BUCKET = os.environ['ES_SNAPSHOT_BUCKET']
ACCOUNT_ID = os.environ['ACCOUNT_ID']
ENVIRONMENT_NAME = os.environ['ENVIRONMENT_NAME']
IAM_ROLE_NAME = os.environ['IAM_ROLE_NAME']
ES_SNAPSHOT_REPO = os.environ['ES_SNAPSHOT_REPO']
AWS_REGION = os.environ['AWS_DEFAULT_REGION']

credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
  credentials.access_key,
  credentials.secret_key,
  AWS_REGION,
  'es',
  session_token=credentials.token
)

url = f"https://{ES_HOST}/_snapshot/{ES_SNAPSHOT_REPO}"

payload_readonly = {
  "type": "s3",
  "settings": {
    "bucket": f"{REPO_BUCKET}",
    "region": f"{AWS_REGION}",
    "role_arn": f"arn:aws:iam::{ACCOUNT_ID}:role/{IAM_ROLE_NAME}",
    "server_side_encryption": "true",
    "readonly": "true"
  }
}

payload = {
  "type": "s3",
  "settings": {
    "bucket": f"{REPO_BUCKET}",
    "region": "eu-west",
    "role_arn": f"arn:aws:iam::{ACCOUNT_ID}:role/{IAM_ROLE_NAME}",
    "server_side_encryption": "true"
  }
}

headers = {"Content-Type": "application/json"}


if AWS_REGION == "eu-west-2":
  r = requests.put(
    url,
    auth=awsauth,
    json=payload_readonly,
    headers=headers
  )
else:
  r = requests.put(
    url,
    auth=awsauth,
    json=payload,
    headers=headers
  )

print(r.status_code)
