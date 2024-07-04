#! /usr/bin/env sh
create_login_role() {
    USER_NAME=$1
    PASSWORD=$2
    psql -U $PGUSER --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v user_password=$PASSWORD --file=./create_role.sql 2> /dev/null 
}

create_permissions() {
    USER_NAME=$1
    DATABASE_NAME=$2
    psql -U $PGUSER --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v database_name=$DATABASE_NAME --file=./"$USER_NAME".sql 2> /dev/null
}

SEARCH_APP_USER="search-app"
SIRIUS_APP_USER="sirius-app"
SUPERVISION_FINANCE_APP_USER="sirius-app"
OPERATOR_ROLE="operator"


# Create Search App User
create_login_role $SEARCH_APP_USER $SEARCH_APP_USER_PASSWORD

# Create Sirius App User
create_login_role $SIRIUS_APP_USER $SIRIUS_APP_USER_PASSWORD

# Create Supervision Finance App User
create_login_role $SUPERVISION_FINANCE_APP_USER $SUPERVISION_FINANCE_APP_USER_PASSWORD

# Create Operator Role User
create_login_role $OPERATOR_ROLE $OPERATOR_PASSWORD

# Revoke Create on Public
psql -U $PGUSER --dbname=$DATABASE_NAME --command='REVOKE CREATE ON SCHEMA public FROM PUBLIC;'

# Grant Search App User Permissions
create_permissions $SEARCH_APP_USER $DATABASE_NAME

# Grant Sirius App User Permissions
create_permissions $SIRIUS_APP_USER $DATABASE_NAME

# Grant Supervision Finance App User Permissions
create_permissions $SUPERVISION_FINANCE_APP_USER $DATABASE_NAME

# Grant Operator Role Permissions
create_permissions $OPERATOR_ROLE $DATABASE_NAME
