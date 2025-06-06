GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

/* log statement usage for audit */
ALTER ROLE :"user_name" SET log_statement="all";

/* public schema read acces */
GRANT USAGE ON SCHEMA public TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"user_name";

/* poa schema read acces */
GRANT USAGE ON SCHEMA poa TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA poa TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA poa GRANT SELECT ON TABLES TO :"user_name";

/* supervision schema read acces */
GRANT USAGE ON SCHEMA supervision TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA supervision TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision GRANT SELECT ON TABLES TO :"user_name";

/* supervision_finance schema read acces */
GRANT USAGE ON SCHEMA supervision_finance TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA supervision_finance TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision_finance GRANT SELECT ON TABLES TO :"user_name";

/* add operator to groups to allow viewing of running query stats and rogue query management */
GRANT pg_read_all_stats TO :"user_name";
GRANT pg_signal_backend TO :"user_name";
