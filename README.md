# PostgreSQL Cluster with PgPool-II

This repository contains a Docker-based PostgreSQL cluster setup with PgPool-II for load balancing. The cluster consists of:

- 1 PostgreSQL master/primary node
- 2 PostgreSQL slave/standby nodes for high availability
- PgPool-II as a connection pooler and load balancer

## Configuration with Environment Variables

All the configuration values for this cluster are stored in the `.env` file. To customize the deployment, modify the variables in this file before starting the containers.

### Main Environment Variables

```
# PostgreSQL Common Settings
POSTGRES_USER=      # PostgreSQL admin username
POSTGRES_PASSWORD=       # PostgreSQL admin password
POSTGRES_DB=           # Default database name
PGDATA=/data                  # Data directory inside containers

# Replication Settings
REPLICATION_USER=    # User for replication
REPLICATION_PASSWORD=        # Password for replication user

# Port Settings
MASTER_PORT=5000                 # Master PostgreSQL exposed port
SLAVE1_PORT=5001                 # Slave 1 PostgreSQL exposed port
SLAVE2_PORT=5002                 # Slave 2 PostgreSQL exposed port
PGPOOL_PORT=6432                 # PgPool exposed port

# Authentication Settings
PG_HBA_AUTH_METHOD=scram-sha-256   # Authentication method for external connections
LOCAL_AUTH_METHOD=trust            # Authentication method for local connections
```

For additional PgPool configuration options, refer to the `.env` file.

## Dynamic Configuration Generation

The cluster uses dynamic configuration generation to create PostgreSQL configuration files based on the environment variables in the `.env` file. This ensures that all settings are consistent across the cluster.

Two implementations are provided:

1. **TypeScript Generator** (default): Used by the Docker Compose setup

### Running the Configuration Generators Manually

#### TypeScript Generator:
```bash
npm install
npm run generate-configs
```

## Getting Started

1. Ensure Docker and Docker Compose are installed on your system
2. Clone this repository
3. Customize the `.env` file if needed
4. Start the cluster:

```
docker-compose up -d
```

5. Connect to the cluster via PgPool:

```
psql -h localhost -p 6432 -U postgresadmin -d postgresdb
```

## Architecture

- **postgres-master**: Primary database server that handles all write operations
- **postgres-slave1, postgres-slave2**: Replica servers that handle read operations and provide high availability
- **pgpool-loadbalancer**: Connection pooler and load balancer that distributes read queries to available nodes

## Scaling

To add more slaves, add new services to the docker-compose.yml file and adjust the PgPool configuration accordingly.

## Security Notes

For production environments, make sure to:
1. Change all default passwords in the `.env` file
2. Consider enabling TLS/SSL by uncommenting and configuring the TLS options in docker-compose.yml
3. Restrict network access to your database ports 