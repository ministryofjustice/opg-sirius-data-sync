GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

/* log statement usage for audit */
ALTER ROLE :"user_name" SET log_statement="all";

/* add operator to groups to allow viewing of running query stats and rogue query management */
GRANT pg_read_all_stats TO :"user_name";
GRANT pg_signal_backend TO :"user_name";
