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

-- ALTER SYSTEM SET default_transaction_read_only TO on;
-- SELECT pg_reload_conf();
-- SHOW default_transaction_read_only;