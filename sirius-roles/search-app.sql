GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";

# public schema read acces
GRANT USAGE ON SCHEMA public TO :"user_name";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"user_name";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"user_name";
