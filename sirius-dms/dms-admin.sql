GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

/* public schema read access */
GRANT USAGE ON SCHEMA public TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"user_name";

/* poa schema read access */
GRANT USAGE ON SCHEMA poa TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA poa TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA poa GRANT SELECT ON TABLES TO :"user_name";

/* supervision schema read access */
GRANT USAGE ON SCHEMA supervision TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA supervision TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision GRANT SELECT ON TABLES TO :"user_name";

/* supervision_finance schema read access */
GRANT USAGE ON SCHEMA supervision_finance TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA supervision_finance TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision_finance GRANT SELECT ON TABLES TO :"user_name";

/* analytics_export schema read access */
GRANT USAGE ON SCHEMA analytics_export TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA analytics_export TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics_export GRANT SELECT ON TABLES TO :"user_name";

GRANT rds_superuser TO :"user_name";
GRANT rds_replication TO :"user_name";