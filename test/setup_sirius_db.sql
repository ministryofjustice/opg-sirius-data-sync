CREATE DATABASE api;

\c api

CREATE SCHEMA analytics_export;
CREATE SCHEMA poa;
CREATE SCHEMA supervision;
CREATE SCHEMA supervision_finance;

CREATE ROLE rds_superuser WITH NOLOGIN SUPERUSER;
CREATE ROLE rds_replication WITH NOLOGIN REPLICATION;
