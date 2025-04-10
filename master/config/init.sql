-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add timescale extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Add vectorscale extension
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- Add hypopg extension
CREATE EXTENSION IF NOT EXISTS hypopg;

-- Add index_advisor extension
CREATE EXTENSION IF NOT EXISTS index_advisor CASCADE;

-- Create a replication user
CREATE USER replication_user WITH REPLICATION PASSWORD 'password' LOGIN;

-- Grant pg_monitor to the replication user
GRANT pg_monitor TO replication_user;

-- Create replication slots for slaves
SELECT pg_create_physical_replication_slot('replica_slot_slave1', true);SELECT pg_create_physical_replication_slot('replica_slot_slave2', true);

-- SELECT * FROM pg_stat_replication;
-- ALTER SYSTEM SET synchronous_standby_names TO  '*';  

SELECT * FROM pg_extension WHERE extname IN ('hypopg', 'index_advisor');  
