#! /usr/bin/env sh
create_login_role() {
    USER_NAME=$1
    PASSWORD=$2
    psql -U postgres -v user_name=$USER_NAME -v user_password=$PASSWORD --file=./create_role.sql 2> /dev/null 
}

create_permissions() {
    USER_NAME=$1
    DATABASE_NAME=$2
    psql -U postgres --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v database_name=$DATABASE_NAME --file=./"$USER_NAME".sql 2> /dev/null
}

# Create Migration User
create_login_role $SIRIUS_MIG_USER $SIRUS_MIG_PASSWORD

# Create Api User
create_login_role $SIRUS_API_USER $SIRIUS_API_PASSWORD

# Create Operator User
create_login_role $OPERATOR_USER $OPERATOR_PASSWORD

# Revoke Create on Public
psql -U postgres --dbname=$DATABASE_NAME --command='REVOKE CREATE ON SCHEMA public FROM PUBLIC;'

# Grant Operator Permissions
create_permissions $OPERATOR_USER $SIRIUS_DATABASE_NAME

# Grant Sirius Migration Permissions
create_permissions $SIRIUS_MIG_USER $SIRIUS_DATABASE_NAME

# Grant Sirius API User Permissions
create_permissions $SIRUS_API_USER $SIRIUS_DATABASE_NAME
