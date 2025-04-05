param (
    [int]$ReplicaCount = 2
)

# Validate input
if ($ReplicaCount -lt 1) {
    Write-Error "Number of replicas must be at least 1"
    exit 1
}

# Create necessary directories for each replica
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $replicaDir = "slave-$i"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $replicaDir)) {
        Write-Host "Creating directory structure for $replicaDir"
        New-Item -Path "$replicaDir" -ItemType Directory -Force | Out-Null
        New-Item -Path "$replicaDir/pgdata" -ItemType Directory -Force | Out-Null
        New-Item -Path "$replicaDir/config" -ItemType Directory -Force | Out-Null
        New-Item -Path "$replicaDir/archive" -ItemType Directory -Force | Out-Null
        
        # Copy template files
        Copy-Item -Path "slave-template/Dockerfile" -Destination "$replicaDir/" -Force
        Copy-Item -Path "slave-template/slave-entrypoint.sh" -Destination "$replicaDir/" -Force
        Copy-Item -Path "slave-template/config/*" -Destination "$replicaDir/config/" -Force
    }
}

# Base docker-compose file with master and network
$composeYaml = @"
networks:
  postgres-cluster-network:
    driver: bridge

services:
  postgres-master:
    build:
      context: ./master
    container_name: postgres-master
    environment:
      POSTGRES_USER: `${POSTGRES_USER}
      POSTGRES_PASSWORD: `${POSTGRES_PASSWORD}
      POSTGRES_DB: `${POSTGRES_DB}
      PGDATA: `${PGDATA}
    ports:
      - "`${MASTER_PORT}:5432"
    volumes:
      - ./master/pgdata:/data
      - ./master/config:/config
      - ./master/archive:/mnt/server/archive
    networks:
      - postgres-cluster-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U `${POSTGRES_USER} -d `${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

"@

# Add slave replicas
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $slaveYaml = @"
  postgres-slave$($i):
    build:
      context: ./slave-$i
    container_name: postgres-slave$($i)
    environment:
      POSTGRES_USER: `${POSTGRES_USER}
      POSTGRES_PASSWORD: `${POSTGRES_PASSWORD}
      POSTGRES_DB: `${POSTGRES_DB}
      PGDATA: `${PGDATA}
      REPLICATION_USER: `${REPLICATION_USER}
      REPLICATION_PASSWORD: `${REPLICATION_PASSWORD}
      REPLICA_ID: "$i"
    ports:
      - "${SLAVE$($i)_PORT}:5432"
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
      test: ["CMD-SHELL", "pg_isready -U `${POSTGRES_USER} -d `${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

"@
    $composeYaml += $slaveYaml
}

# Build pgpool backend nodes configuration
$backendNodes = "0:postgres-master:5432:0"
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $backendNodes += ",$i:postgres-slave$($i):5432:$i"
}

# Build the dependencies section for pgpool
$pgpoolDependsOn = "      postgres-master:`n        condition: service_healthy`n"
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $pgpoolDependsOn += "      postgres-slave$($i):`n        condition: service_healthy`n"
}

# Add pgpool loadbalancer with all dependencies
$pgpoolYaml = @"
  pgpool-loadbalancer:
    image: bitnami/pgpool:latest
    container_name: pgpool-loadbalancer
    ports:
      - "`${PGPOOL_PORT}:5432"
    environment:
      PGPOOL_BACKEND_NODES: "$backendNodes"
      PGPOOL_SR_CHECK_USER: `${REPLICATION_USER}
      PGPOOL_SR_CHECK_PASSWORD: `${REPLICATION_PASSWORD}
      PGPOOL_HEALTH_CHECK_USER: `${REPLICATION_USER}
      PGPOOL_HEALTH_CHECK_PASSWORD: `${REPLICATION_PASSWORD}
      PGPOOL_HEALTH_CHECK_PERIOD: `${PGPOOL_HEALTH_CHECK_PERIOD}
      PGPOOL_HEALTH_CHECK_TIMEOUT: `${PGPOOL_HEALTH_CHECK_TIMEOUT}
      PGPOOL_HEALTH_CHECK_MAX_RETRIES: `${PGPOOL_HEALTH_CHECK_MAX_RETRIES}
      PGPOOL_ADMIN_USERNAME: `${PGPOOL_ADMIN_USERNAME}
      PGPOOL_ADMIN_PASSWORD: `${PGPOOL_ADMIN_PASSWORD}
      PGPOOL_POSTGRES_USERNAME: `${POSTGRES_USER}
      PGPOOL_POSTGRES_PASSWORD: `${POSTGRES_PASSWORD}
      PGPOOL_ENABLE_LOAD_BALANCING: "`${PGPOOL_ENABLE_LOAD_BALANCING}"
      PGPOOL_ENABLE_LOG_PER_NODE_STATEMENT: "`${PGPOOL_ENABLE_LOG_PER_NODE_STATEMENT}"
      PGPOOL_ENABLE_LOG_CONNECTIONS: "`${PGPOOL_ENABLE_LOG_CONNECTIONS}"
      PGPOOL_BACKEND_APPLICATION_NAME: "`${PGPOOL_BACKEND_APPLICATION_NAME}"
      PGPOOL_BACKEND_FLOW_CONTROL: "`${PGPOOL_BACKEND_FLOW_CONTROL}"
      PGPOOL_BACKEND_KEEPALIVE: "`${PGPOOL_BACKEND_KEEPALIVE}"
      PGPOOL_BACKEND_KEEPALIVE_COUNT: `${PGPOOL_BACKEND_KEEPALIVE_COUNT}
      PGPOOL_BACKEND_KEEPALIVE_INTERVAL: `${PGPOOL_BACKEND_KEEPALIVE_INTERVAL}
      PGPOOL_BACKEND_KEEPALIVE_MODE: "`${PGPOOL_BACKEND_KEEPALIVE_MODE}"
      PGPOOL_CONNECT_TIMEOUT: `${PGPOOL_CONNECT_TIMEOUT}
      PGPOOL_SOCKET_TIMEOUT: `${PGPOOL_SOCKET_TIMEOUT}
      PGPOOL_POOL_MODE: "`${PGPOOL_POOL_MODE}"
      PGPOOL_MAX_POOL: `${PGPOOL_MAX_POOL}
      PGPOOL_NUM_INIT_CHILDREN: `${PGPOOL_NUM_INIT_CHILDREN}
      PGPOOL_CHILD_LIFE_TIME: `${PGPOOL_CHILD_LIFE_TIME}
      PGPOOL_CHILD_MAX_CONNECTIONS: `${PGPOOL_CHILD_MAX_CONNECTIONS}
      PGPOOL_MEMORY_CACHE_ENABLED: "`${PGPOOL_MEMORY_CACHE_ENABLED}"
      PGPOOL_MEMQCACHE_METHOD: "`${PGPOOL_MEMQCACHE_METHOD}"
      PGPOOL_MEMQCACHE_TOTAL_SIZE: "`${PGPOOL_MEMQCACHE_TOTAL_SIZE}"
      PGPOOL_MEMQCACHE_MAX_NUM_CACHE: "`${PGPOOL_MEMQCACHE_MAX_NUM_CACHE}"
      PGPOOL_MEMQCACHE_EXPIRE: "`${PGPOOL_MEMQCACHE_EXPIRE}"
      PGPOOL_MEMQCACHE_AUTO_CACHE_INVALIDATION: "`${PGPOOL_MEMQCACHE_AUTO_CACHE_INVALIDATION}"
      PGPOOL_MEMQCACHE_MAXCACHE: "`${PGPOOL_MEMQCACHE_MAXCACHE}"
      PGPOOL_MEMQCACHE_CACHE_BLOCK_SIZE: "`${PGPOOL_MEMQCACHE_CACHE_BLOCK_SIZE}"
      PGPOOL_WHITE_MEMQCACHE_TABLE_LIST: ""
      PGPOOL_BLACK_MEMQCACHE_TABLE_LIST: ""
    volumes:
      - ./pgpool/certs:/opt/bitnami/pgpool/certs
      - ./pgpool/pgpool.conf:/opt/bitnami/pgpool/conf/pgpool.conf
      - ./pgpool/oiddir:/var/log/pgpool/oiddir
    networks:
      - postgres-cluster-network
    depends_on:
$pgpoolDependsOn
"@

$composeYaml += $pgpoolYaml

# Add SLAVE port entries to .env file if they don't exist
$envFile = Get-Content .env -Raw
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $portEntry = "SLAVE$($i)_PORT="
    if (-not $envFile.Contains($portEntry)) {
        $port = 5000 + $i
        Add-Content -Path .env -Value "SLAVE$($i)_PORT=$port"
        Write-Host "Added SLAVE$($i)_PORT=$port to .env file"
    }
}

# Write the final compose file
$composeYaml | Out-File -FilePath "docker-compose.yml" -Encoding UTF8
Write-Host "Generated docker-compose.yml with $ReplicaCount slave replicas"
Write-Host "Run 'docker-compose up --build -d' to start the cluster" 