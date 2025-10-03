GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

/* log statement usage for audit */
ALTER ROLE :"user_name" SET log_statement="all";

/* Revoke previous permissions */
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL PRIVILEGES ON TABLES FROM :"user_name";
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA poa FROM :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA poa REVOKE ALL PRIVILEGES ON TABLES FROM :"user_name";
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA supervision FROM :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision REVOKE ALL PRIVILEGES ON TABLES FROM :"user_name";
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA supervision_finance FROM :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA supervision_finance REVOKE ALL PRIVILEGES ON TABLES FROM :"user_name";

/* add operator to groups to allow viewing of running query stats and rogue query management */
GRANT pg_read_all_stats TO :"user_name";
GRANT pg_signal_backend TO :"user_name";
