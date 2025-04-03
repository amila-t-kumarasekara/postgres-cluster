#!/bin/bash
set -e

# Run PostgreSQL initialization scripts
/usr/local/bin/docker-entrypoint.sh "$@" &
PG_PID=$!

# Wait for PostgreSQL to start
echo "Waiting for PostgreSQL to start..."
until pg_isready -q; do
  echo "Waiting for PostgreSQL to become ready..."
  sleep 2
done

echo "PostgreSQL started. Checking for replication slots..."

# Check and create replication slots if they don't exist
PGPASSWORD="admin123" psql -U postgresadmin -d postgresdb -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replica_slot_slave1') THEN
    PERFORM pg_create_physical_replication_slot('replica_slot_slave1', true);
    RAISE NOTICE 'Created replication slot replica_slot_slave1';
  ELSE
    RAISE NOTICE 'Replication slot replica_slot_slave1 already exists';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replica_slot_slave2') THEN
    PERFORM pg_create_physical_replication_slot('replica_slot_slave2', true);
    RAISE NOTICE 'Created replication slot replica_slot_slave2';
  ELSE
    RAISE NOTICE 'Replication slot replica_slot_slave2 already exists';
  END IF;
END \$\$;
" || echo "Failed to create replication slots, will retry later."

# Wait for the PostgreSQL process to finish
wait $PG_PID 