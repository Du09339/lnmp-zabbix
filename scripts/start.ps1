$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $projectRoot
try {
    if (-not (Test-Path '.env')) {
        throw 'Missing .env. Copy .env.example to .env, set unique passwords, then run this script again.'
    }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI is not installed or not on PATH. Install Docker Desktop with the WSL 2 engine, then open a new PowerShell window.'
    }

    docker info --format '{{.ServerVersion}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker CLI is present but the engine is unavailable. Start Docker Desktop and wait for the engine to become ready.'
    }

    docker compose --env-file .env config --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Compose configuration validation failed. Review the reported setting names; do not share secret values in screenshots.'
    }

    docker compose --env-file .env up -d --build
    if ($LASTEXITCODE -ne 0) {
        throw 'Compose could not start the stack. Collect `docker compose ps` and the relevant service logs before retrying.'
    }

    Write-Host 'Stack startup requested. Run .\scripts\verify.ps1 after the containers finish initializing.'
}
finally {
    Pop-Location
}
