#! /usr/bin/env bash
create_login_role() {
    USER_NAME=$1
    PASSWORD=$2
    DATABASE_NAME=$3
    psql -U $PGUSER --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v user_password=$PASSWORD --file=./create_role.sql 2> /dev/null 
}

create_permissions() {
    USER_NAME=$1
    DATABASE_NAME=$2
    psql -U $PGUSER --dbname=$DATABASE_NAME -v user_name=$USER_NAME -v database_name=$DATABASE_NAME --file=./"$USER_NAME".sql 2> /dev/null
}

ASSIGNEES_ACCESS_ROLE="assignees-access"
DATA_ACCESS_ROLE="data-access"
SEARCH_APP_USER="search-app"
SIRIUS_APP_USER="sirius-app"
SUPERVISION_FINANCE_ADMIN_APP_USER="supervision-finance-admin-app"
SUPERVISION_FINANCE_APP_USER="supervision-finance-app"
OPERATOR_ROLE="operator"

# Create Assignees Access User
create_login_role $ASSIGNEES_ACCESS_ROLE $ASSIGNEES_ACCESS_PASSWORD  $DATABASE_NAME

# Create Data Access User
create_login_role $DATA_ACCESS_ROLE $DATA_ACCESS_PASSWORD  $DATABASE_NAME

# Create Search App User
create_login_role $SEARCH_APP_USER $SEARCH_APP_USER_PASSWORD $DATABASE_NAME

# Create Sirius App User
create_login_role $SIRIUS_APP_USER $SIRIUS_APP_USER_PASSWORD $DATABASE_NAME

# Create Supervision Finance Admin App User
create_login_role $SUPERVISION_FINANCE_ADMIN_APP_USER $SUPERVISION_FINANCE_ADMIN_APP_USER_PASSWORD $DATABASE_NAME

# Create Supervision Finance App User
create_login_role $SUPERVISION_FINANCE_APP_USER $SUPERVISION_FINANCE_APP_USER_PASSWORD $DATABASE_NAME

# Create Operator Role User
create_login_role $OPERATOR_ROLE $OPERATOR_PASSWORD $DATABASE_NAME

# Revoke Create on Public
psql -U $PGUSER --dbname=$DATABASE_NAME --command='REVOKE CREATE ON SCHEMA public FROM PUBLIC;'

# Grant Data Access Role Permissions
create_permissions $ASSIGNEES_ACCESS_ROLE $DATABASE_NAME

# Grant Data Access Role Permissions
create_permissions $DATA_ACCESS_ROLE $DATABASE_NAME

# Grant Search App User Permissions
create_permissions $SEARCH_APP_USER $DATABASE_NAME

# Grant Sirius App User Permissions
create_permissions $SIRIUS_APP_USER $DATABASE_NAME

# # Grant Supervision Finance App Admin User Permissions
create_permissions $SUPERVISION_FINANCE_ADMIN_APP_USER $DATABASE_NAME

# Grant Supervision Finance App User Permissions
create_permissions $SUPERVISION_FINANCE_APP_USER $DATABASE_NAME

# Grant Operator Role Permissions
create_permissions $OPERATOR_ROLE $DATABASE_NAME
