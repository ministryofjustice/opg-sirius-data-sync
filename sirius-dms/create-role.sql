BEGIN;
SET LOCAL log_statement = 'none';
/* Create the role */
CREATE ROLE :"user_name" WITH LOGIN;
COMMIT;
BEGIN;
SET LOCAL log_statement = 'none';
/* Update role password to most recent */
ALTER USER :"user_name" WITH PASSWORD :'user_password';
COMMIT;
