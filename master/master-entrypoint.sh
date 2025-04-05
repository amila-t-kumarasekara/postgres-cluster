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

# Get the replication count from environment variable, default to 2 if not set
REPLICATION_COUNT=${REPLICATION_COUNT:-2}
echo "Creating replication slots for $REPLICATION_COUNT slaves..."

# Dynamically generate replication slot creation SQL
SQL_COMMAND="DO \$\$ BEGIN"
for i in $(seq 1 $REPLICATION_COUNT); do
  SQL_COMMAND+="
  IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replica_slot_slave$i') THEN
    PERFORM pg_create_physical_replication_slot('replica_slot_slave$i', true);
    RAISE NOTICE 'Created replication slot replica_slot_slave$i';
  ELSE
    RAISE NOTICE 'Replication slot replica_slot_slave$i already exists';
  END IF;"
done
SQL_COMMAND+="
END \$\$;"

# Execute the SQL command to create replication slots
PGPASSWORD="${POSTGRES_PASSWORD}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "$SQL_COMMAND" || echo "Failed to create replication slots, will retry later."

# Wait for the PostgreSQL process to finish
wait $PG_PID