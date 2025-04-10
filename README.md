# PostgreSQL Cluster with Dynamic Read Replicas

This project sets up a PostgreSQL database cluster with a single master (primary) node and a configurable number of read-only slave (replica) nodes. The cluster is managed using Docker Compose, with a PgPool-II load balancer that can distribute read queries across replicas.

## Architecture

The cluster consists of the following components:

- **Master Node**: Handles all write operations and replicates data to slave nodes
- **Slave Nodes**: Read-only replicas that can be scaled dynamically
- **PgPool-II**: Load balancer that distributes read queries across available replicas
- **Configuration**: Customizable settings via environment variables

![Architecture Diagram](https://app.eraser.io/workspace/LdfqPTIaYify3nM4I4Ek?origin=share)

## Prerequisites

- Docker and Docker Compose (v2.x or higher)
- Git (to clone the repository)
- PowerShell (for Windows) or Bash (for Linux/macOS)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/postgres-cluster.git
cd postgres-cluster
```

### 2. Configure Environment Variables

The default settings are stored in the `.env` file. You can modify these settings before starting the cluster:

```
# PostgreSQL settings
POSTGRES_USER=postgresadmin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=postgresdb
PGDATA=/data

# Replication settings
REPLICATION_USER=replication_user
REPLICATION_PASSWORD=password

# Port settings
MASTER_PORT=5000
SLAVE1_PORT=5001
SLAVE2_PORT=5002
PGPOOL_PORT=6432
```

> Note: When you add more replicas, the script will automatically add the necessary port settings to the `.env` file.

## Usage

### Starting the Cluster

#### Windows (PowerShell)

```powershell
# Start with default 2 replicas
.\start-cluster.ps1

# Start with a custom number of replicas (e.g., 3)
.\start-cluster.ps1 -ReplicaCount 3
```

#### Linux/macOS (Bash)

```bash
# Make scripts executable (if not already)
chmod +x *.sh

# Start with default 2 replicas
./start-cluster.sh

# Start with a custom number of replicas (e.g., 3)
./start-cluster.sh 3
```

### Stopping the Cluster

#### Windows (PowerShell)

```powershell
# Stop the cluster (keeping volumes for persistence)
.\stop-cluster.ps1

# Stop the cluster and remove all volumes (clean state)
.\stop-cluster.ps1 -RemoveVolumes
```

#### Linux/macOS (Bash)

```bash
# Stop the cluster (keeping volumes for persistence)
./stop-cluster.sh

# Stop the cluster and remove all volumes (clean state)
./stop-cluster.sh --remove-volumes
```

### Manually Generating Docker Compose File

If you want to generate the Docker Compose file without starting the cluster:

#### Windows (PowerShell)

```powershell
.\generate-compose.ps1 -ReplicaCount 4
```

#### Linux/macOS (Bash)

```bash
./generate-compose.sh 4
```

## Connecting to the Cluster

### Direct Connection to Nodes

- **Master Node**: `localhost:5000` (or the port specified in MASTER_PORT)
- **Slave Node 1**: `localhost:5001` (or the port specified in SLAVE1_PORT)
- **Slave Node 2**: `localhost:5002` (or the port specified in SLAVE2_PORT)
- **Additional Slaves**: Ports are automatically assigned in sequence (5003, 5004, etc.)

### Connection via Load Balancer

- **PgPool-II**: `localhost:6432` (or the port specified in PGPOOL_PORT)

The load balancer will distribute read queries to the available slave nodes while directing write queries to the master node.

### Connection Examples

Using `psql`:

```bash
# Connect to master
psql -h localhost -p 5000 -U postgresadmin -d postgresdb

# Connect via load balancer
psql -h localhost -p 6432 -U postgresadmin -d postgresdb
```

## Storage and Data Persistence

Data is stored in the following directories:

- **Master**: `./master/pgdata`
- **Slave 1**: `./slave-1/pgdata`
- **Slave 2**: `./slave-2/pgdata`
- **Additional Slaves**: `./slave-n/pgdata` (where n is the replica number)

These directories are mounted as volumes in the Docker containers, ensuring data persistence between container restarts.

## How It Works

### Dynamic Replica Creation

The system uses a template directory (`slave-template`) to create the necessary files for each replica:

1. When you run `start-cluster.ps1` or `start-cluster.sh`, it calls `generate-compose.ps1` or `generate-compose.sh` with the desired number of replicas.
2. The generate script creates the required directory structure and files for each replica.
3. It then generates a `docker-compose.yml` file with the appropriate service definitions.
4. It adds any missing port definitions to the `.env` file.

### Replica Configuration

Each replica is configured using the following mechanism:

1. The replica receives a unique `REPLICA_ID` environment variable.
2. The custom entrypoint script (`slave-entrypoint.sh`) uses this ID to configure appropriate replication settings.
3. The replica connects to the master node and starts replicating data.

### Load Balancing

PgPool-II is configured to distribute read queries among all available replicas while directing write queries to the master node. The load balancer configuration includes:

- Health checks to ensure only healthy nodes receive traffic
- Connection pooling for better performance
- Query caching for frequently executed queries

## Connection Modes

PgPool-II supports different connection modes that affect how connections are managed and their performance characteristics:

| Mode | Connection Held For | Use Temporary Tables? | Use Session Settings? | Performance | Best For |
|------|---------------------|----------------------|----------------------|-------------|----------|
| session | Entire client session | ✅ Yes | ✅ Yes | ❌ Lowest | Legacy apps, complex session logic |
| transaction | One transaction at a time | ❌ No | ⚠️ Limited | ✅ Balanced | Web apps, ORMs, REST/GraphQL APIs |
| statement | One SQL statement | ❌ No | ❌ No | 🚀 Fastest | Read-heavy, stateless microservices |

Choose the appropriate connection mode based on your application's requirements and performance needs.

## Troubleshooting

### Common Issues

1. **Containers fail to start**:
   - Check Docker logs: `docker-compose logs`
   - Ensure ports are not already in use

2. **Replication not working**:
   - Check master logs: `docker-compose logs postgres-master`
   - Check slave logs: `docker-compose logs postgres-slave1`

3. **Load balancer issues**:
   - Check pgpool logs: `docker-compose logs pgpool-loadbalancer`

### Cleaning Up

If you encounter persistent issues, you can clean up everything and start fresh:

```bash
# Windows (PowerShell)
.\stop-cluster.ps1 -RemoveVolumes

# Linux/macOS (Bash)
./stop-cluster.sh --remove-volumes
```

## Customization

### Adding Extensions

The PostgreSQL configuration includes several pre-installed extensions:
- pgvector for vector similarity search
- TimescaleDB for time-series data
- pgvectorscale for scaling vector operations

If you need additional extensions, you can modify the Dockerfile in the template directory and rebuild the containers.

### Performance Tuning

The PostgreSQL configuration is set with reasonable defaults but can be tuned further:

1. Edit the configuration in `slave-template/config/postgresql.conf`
2. Regenerate the Docker Compose file and restart the cluster

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 