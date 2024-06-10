GRANT CONNECT ON DATABASE :"database_name" TO :"user_name";
GRANT USAGE, CREATE ON SCHEMA public TO :"user_name";
GRANT SELECT, INSERT, UPDATE, DELETE ON public.opgcore_doctrine_migrations TO :"user_name";
GRANT USAGE, CREATE ON SCHEMA poa TO :"user_name";
GRANT USAGE, CREATE ON SCHEMA supervision TO :"user_name";
GRANT USAGE, CREATE ON SCHEMA supervision_finance TO :"user_name";
