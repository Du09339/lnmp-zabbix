$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $projectRoot
try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI is not installed or not on PATH. Install Docker Desktop with the WSL 2 engine, then open a new PowerShell window.'
    }

    docker info --format '{{.ServerVersion}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker CLI is present but the engine is unavailable. Start Docker Desktop and wait for the engine to become ready.'
    }

    docker compose --env-file .env ps
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not read Compose service status.'
    }

    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8081/healthz' -TimeoutSec 5
    if ($health.status -ne 'ok') {
        throw 'The app health endpoint did not report ok. Inspect PHP, MySQL, and Redis logs.'
    }

    $page = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/' -TimeoutSec 5
    if ($page.StatusCode -ne 200 -or $page.Content -notmatch 'LNMP Operations Lab') {
        throw 'The application page did not return the expected content.'
    }

    Write-Host 'Verified: web page returned HTTP 200; MySQL and Redis health checks passed.'
    Write-Host 'Open http://127.0.0.1:8081/ and http://127.0.0.1:8080/ in a browser.'
}
finally {
    Pop-Location
}
