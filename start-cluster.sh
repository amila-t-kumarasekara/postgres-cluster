#!/bin/bash
set -e

# Default to 2 replicas if not specified
REPLICA_COUNT=${1:-2}

# Validate input
if [ "$REPLICA_COUNT" -lt 1 ]; then
  echo "Error: Number of replicas must be at least 1"
  exit 1
fi

echo "Starting PostgreSQL cluster with $REPLICA_COUNT read replicas..."

# Make scripts executable
chmod +x ./generate-compose.sh

# Generate the docker-compose file
./generate-compose.sh $REPLICA_COUNT

# Make sure .env is sourced
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Start the containers
docker-compose up --build -d

echo "PostgreSQL cluster started with $REPLICA_COUNT read replicas"
echo "Master accessible on localhost:$MASTER_PORT"
for i in $(seq 1 $REPLICA_COUNT); do
  port_var="SLAVE${i}_PORT"
  port=${!port_var}
  echo "Slave $i accessible on localhost:$port"
done
echo "Load balancer accessible on localhost:$PGPOOL_PORT" 