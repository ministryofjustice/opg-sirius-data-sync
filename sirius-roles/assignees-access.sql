GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

/* log statement usage for audit */
ALTER ROLE :"user_name" SET log_statement="all";

/* assignees schema read/update access */
GRANT USAGE ON SCHEMA public TO :"user_name";
GRANT SELECT, UPDATE ON assignees IN SCHEMA public TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, UPDATE ON TABLES TO :"user_name";
