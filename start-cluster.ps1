param (
    [int]$ReplicaCount = 2
)

# Validate input
if ($ReplicaCount -lt 1) {
    Write-Error "Number of replicas must be at least 1"
    exit 1
}

Write-Host "Starting PostgreSQL cluster with $ReplicaCount read replicas..."

# Load environment variables from .env file
$envContent = Get-Content -Path ".env" -ErrorAction SilentlyContinue
$envVars = @{}
foreach ($line in $envContent) {
    if ($line -match '^([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$key] = $value
    }
}

# Generate the docker-compose file
./generate-compose.ps1 -ReplicaCount $ReplicaCount

# Start the containers
docker-compose up --build -d

Write-Host "PostgreSQL cluster started with $ReplicaCount read replicas"
Write-Host "Master accessible on localhost:$($envVars['MASTER_PORT'])"
for ($i = 1; $i -le $ReplicaCount; $i++) {
    $portKey = "SLAVE${i}_PORT"
    $port = $envVars[$portKey]
    Write-Host "Slave $i accessible on localhost:$port"
}
Write-Host "Load balancer accessible on localhost:$($envVars['PGPOOL_PORT'])" 