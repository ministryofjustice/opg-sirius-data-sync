#! /usr/bin/env bash
create_login_role() {
    USER_NAME=$1
    PASSWORD=$2
    DATABASE_NAME=$3
    psql -U $PGUSER --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v user_password=$PASSWORD --file=./create-role.sql 2> /dev/null 
}

create_permissions() {
    USER_NAME=$1
    DATABASE_NAME=$2
    psql -U $PGUSER --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v database_name=$DATABASE_NAME --file=./"$USER_NAME".sql 2> /dev/null
}

create_extension() {
    psql -U $PGUSER --dbname=$DATABASE_NAME --file=./extension.sql 2> /dev/null
}

create_dms_objects() {
    DMSUSER=$1
    DATABASE_NAME=$2
    PGPASSWORD=$DMS_ADMIN_PASSWORD psql -U $DMSUSER --dbname=$DATABASE_NAME --file=./create-dms-objects.sql 2> /dev/null
}

create_dms_triggers() {
    DATABASE_NAME=$1
    TRIGGER_COUNT=$(psql -U $PGUSER --dbname=$DATABASE_NAME --tuples-only --no-align --command "SELECT count(*) FROM pg_event_trigger WHERE evtname='awsdms_intercept_ddl';")
    if [ "$TRIGGER_COUNT" == "0" ]; then
        echo "Creating DMS Triggers"
        psql -U $PGUSER --dbname=$DATABASE_NAME --file=./create-dms-triggers.sql 2> /dev/null
    else
        echo "Trigger already exists, skipping trigger creation"
    fi
}

# Create Assignees Access User
create_login_role dms-admin $DMS_ADMIN_PASSWORD  $DATABASE_NAME

# Grant Operator Role Permissions
create_permissions dms-admin $DATABASE_NAME

# Create pglogical Extension
create_extension

# Create DMS Objects
create_dms_objects dms-admin $DATABASE_NAME

# create DMS Triggers
create_dms_triggers $DATABASE_NAME


