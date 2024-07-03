/* Create the role */
CREATE ROLE :"user_name" LOGIN PASSWORD :'user_password';
/* Update role password to most recent */
ALTER USER :"user_name" WITH PASSWORD :'user_password';
