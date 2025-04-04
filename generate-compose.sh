#!/bin/bash
set -e

# Default to 2 replicas if not specified
REPLICA_COUNT=${1:-2}

# Validate input
if [ "$REPLICA_COUNT" -lt 1 ]; then
  echo "Error: Number of replicas must be at least 1"
  exit 1
fi

# Create necessary directories for each replica
for i in $(seq 1 $REPLICA_COUNT); do
  replica_dir="slave-$i"
  
  # Create directory if it doesn't exist
  if [ ! -d "$replica_dir" ]; then
    echo "Creating directory structure for $replica_dir"
    mkdir -p "$replica_dir/pgdata"
    mkdir -p "$replica_dir/config"
    mkdir -p "$replica_dir/archive"
    
    # Copy template files
    cp slave-template/Dockerfile "$replica_dir/"
    cp slave-template/slave-entrypoint.sh "$replica_dir/"
    cp -r slave-template/config/* "$replica_dir/config/"
    
    # Ensure entrypoint script is executable
    chmod +x "$replica_dir/slave-entrypoint.sh"
  fi
done

# Start building docker-compose.yml
cat > docker-compose.yml << EOF
networks:
  postgres-cluster-network:
    driver: bridge

services:
  postgres-master:
    build:
      context: ./master
    container_name: postgres-master
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
      PGDATA: \${PGDATA}
    ports:
      - "\${MASTER_PORT}:5432"
    volumes:
      - ./master/pgdata:/data
      - ./master/config:/config
      - ./master/archive:/mnt/server/archive
    networks:
      - postgres-cluster-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF

# Add slave replicas
for i in $(seq 1 $REPLICA_COUNT); do
  cat >> docker-compose.yml << EOF

  postgres-slave$i:
    build:
      context: ./slave-$i
    container_name: postgres-slave$i
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
      PGDATA: \${PGDATA}
      REPLICATION_USER: \${REPLICATION_USER}
      REPLICATION_PASSWORD: \${REPLICATION_PASSWORD}
      REPLICA_ID: "$i"
    ports:
      - "\${SLAVE${i}_PORT}:5432"
    volumes:
      - ./slave-$i/pgdata:/data
      - ./slave-$i/config:/config
      - ./slave-$i/archive:/mnt/server/archive
    networks:
      - postgres-cluster-network
    depends_on:
      postgres-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
done

# Build pgpool backend nodes configuration
backend_nodes="0:postgres-master:5432:0"
for i in $(seq 1 $REPLICA_COUNT); do
  backend_nodes="$backend_nodes,$i:postgres-slave$i:5432:2"
done

# Add pgpool loadbalancer
cat >> docker-compose.yml << EOF

  pgpool-loadbalancer:
    image: bitnami/pgpool:latest
    container_name: pgpool-loadbalancer
    ports:
      - "\${PGPOOL_PORT}:5432"
    environment:
      PGPOOL_BACKEND_NODES: "$backend_nodes"
      PGPOOL_SR_CHECK_USER: \${REPLICATION_USER}
      PGPOOL_SR_CHECK_PASSWORD: \${REPLICATION_PASSWORD}
      PGPOOL_HEALTH_CHECK_USER: \${REPLICATION_USER}
      PGPOOL_HEALTH_CHECK_PASSWORD: \${REPLICATION_PASSWORD}
      PGPOOL_HEALTH_CHECK_PERIOD: \${PGPOOL_HEALTH_CHECK_PERIOD}
      PGPOOL_HEALTH_CHECK_TIMEOUT: \${PGPOOL_HEALTH_CHECK_TIMEOUT}
      PGPOOL_HEALTH_CHECK_MAX_RETRIES: \${PGPOOL_HEALTH_CHECK_MAX_RETRIES}
      PGPOOL_ADMIN_USERNAME: \${PGPOOL_ADMIN_USERNAME}
      PGPOOL_ADMIN_PASSWORD: \${PGPOOL_ADMIN_PASSWORD}
      PGPOOL_POSTGRES_USERNAME: \${POSTGRES_USER}
      PGPOOL_POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      PGPOOL_ENABLE_LOAD_BALANCING: "\${PGPOOL_ENABLE_LOAD_BALANCING}"
      PGPOOL_ENABLE_LOG_PER_NODE_STATEMENT: "\${PGPOOL_ENABLE_LOG_PER_NODE_STATEMENT}"
      PGPOOL_ENABLE_LOG_CONNECTIONS: "\${PGPOOL_ENABLE_LOG_CONNECTIONS}"
      PGPOOL_BACKEND_APPLICATION_NAME: "\${PGPOOL_BACKEND_APPLICATION_NAME}"
      PGPOOL_BACKEND_FLOW_CONTROL: "\${PGPOOL_BACKEND_FLOW_CONTROL}"
      PGPOOL_BACKEND_KEEPALIVE: "\${PGPOOL_BACKEND_KEEPALIVE}"
      PGPOOL_BACKEND_KEEPALIVE_COUNT: \${PGPOOL_BACKEND_KEEPALIVE_COUNT}
      PGPOOL_BACKEND_KEEPALIVE_INTERVAL: \${PGPOOL_BACKEND_KEEPALIVE_INTERVAL}
      PGPOOL_BACKEND_KEEPALIVE_MODE: "\${PGPOOL_BACKEND_KEEPALIVE_MODE}"
      PGPOOL_CONNECT_TIMEOUT: \${PGPOOL_CONNECT_TIMEOUT}
      PGPOOL_SOCKET_TIMEOUT: \${PGPOOL_SOCKET_TIMEOUT}
      PGPOOL_POOL_MODE: "\${PGPOOL_POOL_MODE}"
      PGPOOL_MAX_POOL: \${PGPOOL_MAX_POOL}
      PGPOOL_NUM_INIT_CHILDREN: \${PGPOOL_NUM_INIT_CHILDREN}
      PGPOOL_CHILD_LIFE_TIME: \${PGPOOL_CHILD_LIFE_TIME}
      PGPOOL_CHILD_MAX_CONNECTIONS: \${PGPOOL_CHILD_MAX_CONNECTIONS}
      PGPOOL_MEMORY_CACHE_ENABLED: "\${PGPOOL_MEMORY_CACHE_ENABLED}"
      PGPOOL_MEMQCACHE_METHOD: "\${PGPOOL_MEMQCACHE_METHOD}"
      PGPOOL_MEMQCACHE_TOTAL_SIZE: "\${PGPOOL_MEMQCACHE_TOTAL_SIZE}"
      PGPOOL_MEMQCACHE_MAX_NUM_CACHE: "\${PGPOOL_MEMQCACHE_MAX_NUM_CACHE}"
      PGPOOL_MEMQCACHE_EXPIRE: "\${PGPOOL_MEMQCACHE_EXPIRE}"
      PGPOOL_MEMQCACHE_AUTO_CACHE_INVALIDATION: "\${PGPOOL_MEMQCACHE_AUTO_CACHE_INVALIDATION}"
      PGPOOL_MEMQCACHE_MAXCACHE: "\${PGPOOL_MEMQCACHE_MAXCACHE}"
      PGPOOL_MEMQCACHE_CACHE_BLOCK_SIZE: "\${PGPOOL_MEMQCACHE_CACHE_BLOCK_SIZE}"
      PGPOOL_WHITE_MEMQCACHE_TABLE_LIST: ""
      PGPOOL_BLACK_MEMQCACHE_TABLE_LIST: ""
    volumes:
      - ./pgpool/certs:/opt/bitnami/pgpool/certs
      - ./pgpool/pgpool.conf:/opt/bitnami/pgpool/conf/pgpool.conf
      - ./pgpool/oiddir:/var/log/pgpool/oiddir
    networks:
      - postgres-cluster-network
    depends_on:
      postgres-master:
        condition: service_healthy
EOF

# Add pgpool slave dependencies
for i in $(seq 1 $REPLICA_COUNT); do
  cat >> docker-compose.yml << EOF
      postgres-slave$i:
        condition: service_healthy
EOF
done

# Add SLAVE port entries to .env file if they don't exist
for i in $(seq 1 $REPLICA_COUNT); do
  if ! grep -q "SLAVE${i}_PORT=" .env; then
    port=$((5000 + i))
    echo "SLAVE${i}_PORT=$port" >> .env
    echo "Added SLAVE${i}_PORT=$port to .env file"
  fi
done

echo "Generated docker-compose.yml with $REPLICA_COUNT slave replicas"
echo "Run 'docker-compose up --build -d' to start the cluster" 