#!/bin/bash
set -e

# Check if we should remove volumes
REMOVE_VOLUMES=0
if [ "$1" == "--remove-volumes" ]; then
  REMOVE_VOLUMES=1
fi

echo "Stopping PostgreSQL cluster..."

if [ $REMOVE_VOLUMES -eq 1 ]; then
  echo "Removing all containers and volumes..."
  docker-compose down -v
  
  # Optional: Remove pgdata directories to start fresh
  find . -type d -name "slave-*" | while read dir; do
    pgdata_path="$dir/pgdata"
    if [ -d "$pgdata_path" ]; then
      echo "Cleaning up $pgdata_path..."
      rm -rf "$pgdata_path"
    fi
  done
  
  master_pgdata="master/pgdata"
  if [ -d "$master_pgdata" ]; then
    echo "Cleaning up $master_pgdata..."
    rm -rf "$master_pgdata"
  fi
else
  echo "Stopping containers (keeping volumes)..."
  docker-compose down
fi

echo "PostgreSQL cluster stopped" 