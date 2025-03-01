GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

/* supervision_finance schema read/write access */
GRANT USAGE ON SCHEMA supervision_finance TO :"user_name";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA supervision_finance TO :"user_name";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA supervision_finance TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision_finance GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision_finance GRANT USAGE, SELECT ON SEQUENCES TO :"user_name";

/* public schema read access */
GRANT USAGE ON SCHEMA public TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"user_name";
