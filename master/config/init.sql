-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add timescale extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Add vectorscale extension
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- -- Add pg_pgbouncer extension
-- CREATE EXTENSION IF NOT EXISTS pg_pgbouncer;   

-- Create a replication user
CREATE USER replication_user WITH REPLICATION PASSWORD 'password' LOGIN;

-- Grant pg_monitor to the replication user
GRANT pg_monitor TO replication_user;

-- Create replication slots for slaves
SELECT pg_create_physical_replication_slot('replica_slot_slave1', true);
SELECT pg_create_physical_replication_slot('replica_slot_slave2', true);

-- SELECT * FROM pg_stat_replication;
-- ALTER SYSTEM SET synchronous_standby_names TO  '*';  