param (
    [switch]$RemoveVolumes = $false
)

Write-Host "Stopping PostgreSQL cluster..."

if ($RemoveVolumes) {
    Write-Host "Removing all containers and volumes..."
    docker-compose down -v
    
    # Optional: Remove pgdata directories to start fresh
    Get-ChildItem -Path . -Directory -Filter "slave-*" | ForEach-Object {
        $pgdataPath = Join-Path $_.FullName "pgdata"
        if (Test-Path $pgdataPath) {
            Write-Host "Cleaning up $pgdataPath..."
            Remove-Item -Path $pgdataPath -Recurse -Force
        }
    }
    
    $masterPgdataPath = Join-Path "master" "pgdata"
    if (Test-Path $masterPgdataPath) {
        Write-Host "Cleaning up $masterPgdataPath..."
        Remove-Item -Path $masterPgdataPath -Recurse -Force
    }
} else {
    Write-Host "Stopping containers (keeping volumes)..."
    docker-compose down
}

Write-Host "PostgreSQL cluster stopped" 