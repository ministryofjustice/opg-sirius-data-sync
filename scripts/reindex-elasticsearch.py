import boto3
from datetime import datetime
import logging
from math import ceil
import os
import psycopg2
from time import sleep


class ElasticReIndex:
    api_security_group = ""
    batch_start = 0
    loops = int()
    loops_per_task = int()
    max_persons = ""
    private_subnets = list()
    run_data = list()
    person_task_arns = list()

    def __init__(self, environment):
        self.environment = environment
        self.batch_size = os.environ.get("BATCH_SIZE", 40000)
        self.number_of_tasks = os.environ.get("NUMBER_OF_TASKS", 40)
        self.aws_ecs_client = boto3.client(
            'ecs',
            region_name='eu-west-1'
        )
        self.aws_ec2_client = boto3.client(
            'ec2',
            region_name='eu-west-1'
        )
        self.aws_rds_client = boto3.client(
            'rds',
            region_name='eu-west-1'
        )
        self.aws_secrets_client = boto3.client(
            'secretsmanager',
            region_name='eu-west-1'
        )
        self.get_private_subnets()
        self.get_api_security_group()
        self.get_postgresql_environment()
        self.get_pg_password()
        self.get_max_person_id()
        self.generate_parameters()

    def generate_parameters(self):
        logging.info("Batch Size: " + str(self.batch_size))
        logging.info("Number of Tasks: " + str(self.number_of_tasks))
        total_loops = ceil(self.max_persons / self.batch_size)
        loops_per_task = ceil(total_loops / self.number_of_tasks)
        task = 1
        loop_start = 0
        while task < (self.number_of_tasks + 1):
            loop_start = (task - 1) * loops_per_task
            self.run_data.append((loops_per_task, self.batch_size, loop_start))
            task += 1
        logging.info("Run Data: " + str(self.run_data))

    def get_max_person_id(self):
        connection = psycopg2.connect(
            database=self.pg_database,
            user=self.pg_user,
            password=self.pg_password,
            host=self.pg_host,
            port="5432"
        )
        cursor = connection.cursor()
        cursor.execute("select max(id) from persons;")
        self.max_persons = cursor.fetchone()[0]
        logging.info("Max Person ID: " + str(self.max_persons))
        cursor.close()
        connection.close()

    def get_postgresql_environment(self):
        cluster = self.aws_rds_client.describe_db_clusters(
            DBClusterIdentifier='api-' + self.environment
        )
        self.pg_database = cluster.get('DBClusters')[0].get('DatabaseName')
        self.pg_host = cluster.get('DBClusters')[0].get('Endpoint')
        self.pg_user = cluster.get('DBClusters')[0].get('MasterUsername')
        logging.info("PostgreSQL Database: " + str(self.pg_database))
        logging.info("PostgreSQL Host: " + str(self.pg_host))
        logging.info("PostgreSQL User: " + str(self.pg_user))

    def get_pg_password(self):
        if self.environment in ['preproduction', 'production']:
            secret_id = 'rds-api-' + self.environment
        else:
            secret_id = 'rds-api-preproduction'
        self.pg_password = self.aws_secrets_client.get_secret_value(
            SecretId=secret_id
        )['SecretString']

    def get_private_subnets(self):
        private_subnets = self.aws_ec2_client.describe_subnets(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': [
                        'private-*',
                    ]
                },
            ])
        for subnet in private_subnets["Subnets"]:
            self.private_subnets.append(subnet["SubnetId"])
        logging.info("ECS Subnets: " + str(self.private_subnets))

    def get_api_security_group(self):
        self.api_security_group = self.aws_ec2_client.describe_security_groups(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': [
                        'api-ecs-{env}'.format(env=self.environment),
                    ]
                },
            ])["SecurityGroups"][0]["GroupId"]
        logging.info("API Security Group: " + str(self.api_security_group))

    def recreate_index(self, index):
        logging.info("Recreating Index {index}...".format(index=index))
        logging.info("Start Time:"+ str(datetime.now()))
        delete_index = [
            "php",
            "/var/www/public/index.php",
            "searchindex",
            "delete",
            index
            ]
        delete_task_arn = self.run_api_task(delete_index)
        self.wait_for_tasks_to_stop([delete_task_arn])
        self.check_task_exit_code(delete_task_arn)
        create_index = [
            "php",
            "/var/www/public/index.php",
            "searchindex",
            "create",
            index
            ]
        create_task_arn = self.run_api_task(create_index)
        self.wait_for_tasks_to_stop([create_task_arn])
        self.check_task_exit_code(create_task_arn)
        logging.info("Index Recreated: {index}.".format(index=index))
        logging.info("End Time:"+ str(datetime.now()))


    def persons_reindex(self):
        logging.info("Re-indexing persons index...")
        logging.info("Start Time:"+ str(datetime.now()))
        for run in self.run_data:
            loops_per_node=run[0]
            batch_size=run[1]
            loop_start=run[2]
            logging.info(
                "Loop Info - Loops Per Node: {loops_per_node} - Batch Size: {batch_size} - Loop Start: {loop_start}".format(
                    loops_per_node=loops_per_node,
                    batch_size=batch_size,
                    loop_start=loop_start))
            command = [
                        '/var/www/scripts/person_reindex.sh',
                        '-l',
                        str(loops_per_node),
                        '-s',
                        str(batch_size),
                        '-b',
                        str(loop_start)
                        ]
            task_arn = self.run_api_task(command)
            self.person_task_arns.append(task_arn)
            sleep(2)
        self.wait_for_tasks_to_stop(self.person_task_arns)
        logging.info("Checking Person Reindex Exit Codes")
        self.bulk_check_exit_codes(self.person_task_arns)
        logging.info("Re-indexing persons complete.")
        logging.info("End Time:"+ str(datetime.now()))

    def bulk_check_exit_codes(self, task_arns):
        for task_arn in task_arns:
            self.check_task_exit_code(task_arn)

    def run_api_task(self, command):
        task = self.aws_ecs_client.run_task(
            cluster=self.environment,
            count=1,
            launchType='FARGATE',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': self.private_subnets,
                    'securityGroups': [
                        self.api_security_group,
                    ],
                    'assignPublicIp': 'DISABLED'
                }
            },
            overrides={
                'containerOverrides': [
                    {
                        'name': 'api-migration',
                        'command': command,
                    },
                ],
            },
            taskDefinition='api-migration-{env}'.format(env=self.environment)
        )
        try:
            task_arn = task['tasks'][0]['taskArn']
            logging.info("Task ARN: " + str(task_arn))
        except IndexError:
            logging.info("Failed to retrieve task arn")
            logging.info(task)
        return task_arn

    def wait_for_tasks_to_stop(self, task_arns):
        logging.info("ECS Task Running Waiter Task List: " + str(task_arns))
        waiter = self.aws_ecs_client.get_waiter('tasks_stopped')
        logging.info("Waiting for Tasks to Complete...")
        waiter.wait(
            cluster=self.environment,
            tasks=task_arns,
            WaiterConfig={
                'Delay': 60,
                'MaxAttempts': 300
            }
        )
        logging.info("All Tasks Completed.")

    def check_task_exit_code(self, task_arn):
        response = self.aws_ecs_client.describe_tasks(
            cluster=self.environment,
            tasks=[task_arn]
        )
        containers = response["tasks"][0]["containers"]
        exit_code = list(filter(lambda container:  container['name'] == 'api-migration', containers))[0]["exitCode"]
        logging.info("Container Exit Code:" + str(exit_code))
        if exit_code != 0:
            logging.info("Container exited with non-zero status")
            raise SystemExit
        else:
            logging.info("Task exited successfully")

def single_run(reindexer):
    command = [
        'php',
        '/var/www/public/index.php',
        'searchindex',
        'reindex',
        'persons',
        '--start=0',
        '--finish=40000'
        ]
    task_arn = reindexer.run_api_task(command)
    reindexer.wait_for_tasks_to_stop([task_arn])
    reindexer.check_task_exit_code(task_arn)

def main():
    log_level = os.environ.get("LOG_LEVEL", "INFO")
    numeric_level = getattr(logging, log_level)
    logging.basicConfig(level=numeric_level)
    environment = os.environ["ENVIRONMENT_NAME"]
    logging.info("Environment Name: " + str(environment))
    reindexer = ElasticReIndex(environment)
    # reindexer.recreate_index("persons") Reindex in Place.
    reindexer.persons_reindex()

if __name__ == "__main__":
    main()
