param (
    [int]$ReplicaCount = 2
)

# Validate input
if ($ReplicaCount -lt 1) {
    Write-Error "Number of replicas must be at least 1"
    exit 1
}

Write-Host "Starting PostgreSQL cluster with $ReplicaCount read replicas..."

# Generate the docker-compose file
./generate-compose.ps1 -ReplicaCount $ReplicaCount

# Start the containers
docker-compose up --build -d

Write-Host "PostgreSQL cluster started with $ReplicaCount read replicas"
Write-Host "Master accessible on localhost:${Env:MASTER_PORT}"
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $portVarName = "SLAVE${i}_PORT"
    $port = (Get-Item env:$portVarName).Value
    Write-Host "Slave $i accessible on localhost:$port"
}
Write-Host "Load balancer accessible on localhost:${Env:PGPOOL_PORT}" 