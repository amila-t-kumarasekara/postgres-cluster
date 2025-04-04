-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add timescale extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Add vectorscale extension
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- ALTER SYSTEM SET default_transaction_read_only TO on;
-- SELECT pg_reload_conf();
-- SHOW default_transaction_read_only;