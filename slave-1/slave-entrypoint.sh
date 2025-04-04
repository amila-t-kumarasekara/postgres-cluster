#!/bin/bash
set -e

# Only initialize if data directory is empty
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Waiting for postgres-master to be up and ready..."
  # First make sure the master server is up
  until pg_isready -h postgres-master -q; do
    echo "Waiting for postgres-master to be up..."
    sleep 2
  done

  echo "Master server is up. Now waiting for replication_user to be available..."
  
  # Wait for replication user to be created on master
  # Try to connect to the master server as postgres admin first
  until PGPASSWORD="${POSTGRES_PASSWORD}" psql -h postgres-master -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c '\q' 2>/dev/null; do
    echo "Cannot connect to master as admin. Waiting for master database to be fully initialized..."
    sleep 5
  done
  
  echo "Connected to master as admin. Checking if replication user exists..."
  
  # Check if replication user exists
  until PGPASSWORD="${POSTGRES_PASSWORD}" psql -h postgres-master -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT 1 FROM pg_roles WHERE rolname='${REPLICATION_USER}'" | grep -q 1; do
    echo "Replication user does not exist yet. Creating replication user..."
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h postgres-master -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE USER ${REPLICATION_USER} WITH REPLICATION PASSWORD '${REPLICATION_PASSWORD}' LOGIN; GRANT pg_monitor TO ${REPLICATION_USER};" || echo "Failed to create user: $?"
    sleep 5
  done
  
  echo "Replication user exists. Trying to connect as replication user..."
  
  # Now try to connect as replication user
  until PGPASSWORD="$REPLICATION_PASSWORD" psql -h postgres-master -U "$REPLICATION_USER" -d "${POSTGRES_DB}" -c '\q' 2>/dev/null; do
    echo "Waiting for replication_user to be ready on master..."
    echo "Attempting connection debug: PGPASSWORD=$REPLICATION_PASSWORD psql -h postgres-master -U $REPLICATION_USER -d ${POSTGRES_DB}"
    PGPASSWORD="$REPLICATION_PASSWORD" psql -h postgres-master -U "$REPLICATION_USER" -d "${POSTGRES_DB}" -c '\l' 2>&1 || echo "Connection failed with error code: $?"
    sleep 5
  done
  
  echo "Replication user is available. Cloning data from master using pg_basebackup..."
  PGPASSWORD="$REPLICATION_PASSWORD" pg_basebackup -h postgres-master -D "$PGDATA" -U "$REPLICATION_USER" -Fp -Xs -P -R
  
  # Create or update recovery configuration for standby mode
  cat > "${PGDATA}/postgresql.auto.conf" << EOF
primary_conninfo = 'host=postgres-master port=5432 user=${REPLICATION_USER} password=${REPLICATION_PASSWORD} application_name=slave1'
primary_slot_name = 'replica_slot_slave1'
EOF

  # Create standby signal file
  touch "${PGDATA}/standby.signal"
  
  # Ensure correct ownership and permissions of PostgreSQL data
  chown -R postgres:postgres "$PGDATA"
  chmod 0700 "$PGDATA"
fi

# Start PostgreSQL as the postgres user
echo "Starting PostgreSQL as a standby server..."
exec gosu postgres postgres -c "config_file=/config/postgresql.conf" 