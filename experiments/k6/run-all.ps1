param(
    [string]$K6Path = "k6",
    [string]$Duration = "15s"
)

$ErrorActionPreference = "Stop"
$BaseUrl = "http://localhost:8080"
$VusList = @(10, 50, 100, 200)
$ResultsDir = "$PSScriptRoot\results"
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

function Invoke-K6Test {
    param(
        [string]$Name,
        [string]$Script,
        [hashtable]$EnvVars,
        [int]$Vus
    )

    $outFile = Join-Path $ResultsDir "$Name-vus$Vus.json"
    Write-Host ">>> [$Name] VUs=$Vus Duration=$Duration" -ForegroundColor Cyan

    $envArgs = @(
        "-e", "BASE_URL=$BaseUrl",
        "-e", "VUS=$Vus",
        "-e", "DURATION=$Duration"
    )
    foreach ($k in $EnvVars.Keys) {
        $envArgs += @("-e", "$k=$($EnvVars[$k])")
    }

    & $K6Path run --quiet --summary-export $outFile @envArgs $Script | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "k6 terminou com codigo $LASTEXITCODE para $Name (VUs=$Vus)"
    }
}

Write-Host "=== Aquecimento da aplicacao (5s) ===" -ForegroundColor Yellow
Invoke-RestMethod -Uri "$BaseUrl/api/music/top50/sem-cache" | Out-Null
Invoke-RestMethod -Uri "$BaseUrl/api/albums/optimized?limit=10" | Out-Null
Invoke-RestMethod -Uri "$BaseUrl/api/music/album/150" | Out-Null

Write-Host "`n=== Garantindo banco SEM indice para Cenarios 1, 2 e 3 (sem indice) ===" -ForegroundColor Yellow
docker exec streaming-db psql -U streaming -c "DROP INDEX IF EXISTS idx_music_album_reproductions; ANALYZE music;" | Out-Null

Write-Host "`n=== CENARIO 1: CACHE ===" -ForegroundColor Green
foreach ($vus in $VusList) {
    Invoke-K6Test -Name "c1-sem-cache" -Script "$PSScriptRoot\scenario1-cache.js" -EnvVars @{ MODE = "sem-cache" } -Vus $vus
    Invoke-K6Test -Name "c1-com-cache-quente" -Script "$PSScriptRoot\scenario1-cache.js" -EnvVars @{ MODE = "com-cache-quente" } -Vus $vus
    Invoke-K6Test -Name "c1-com-cache-frio" -Script "$PSScriptRoot\scenario1-cache.js" -EnvVars @{ MODE = "com-cache-frio" } -Vus $vus
}

Write-Host "`n=== CENARIO 2: PERSISTENCIA (limit=10) ===" -ForegroundColor Green
foreach ($vus in $VusList) {
    Invoke-K6Test -Name "c2-lazy" -Script "$PSScriptRoot\scenario2-persistence.js" -EnvVars @{ STRATEGY = "lazy"; LIMIT = "10" } -Vus $vus
    Invoke-K6Test -Name "c2-eager" -Script "$PSScriptRoot\scenario2-persistence.js" -EnvVars @{ STRATEGY = "eager"; LIMIT = "10" } -Vus $vus
    Invoke-K6Test -Name "c2-optimized" -Script "$PSScriptRoot\scenario2-persistence.js" -EnvVars @{ STRATEGY = "optimized"; LIMIT = "10" } -Vus $vus
}

# ==============================================================================
# CENARIO 3: INDICES (Sem indice vs Com indice)
# ==============================================================================
Write-Host "`n=== CENARIO 3: INDICES (SEM INDICE) ===" -ForegroundColor Green
foreach ($vus in $VusList) {
    Invoke-K6Test -Name "c3-sem-indice" -Script "$PSScriptRoot\scenario3-index.js" -EnvVars @{} -Vus $vus
}

Write-Host "`n=== Criando indice idx_music_album_reproductions ===" -ForegroundColor Yellow
docker exec streaming-db psql -U streaming -c "CREATE INDEX IF NOT EXISTS idx_music_album_reproductions ON music (album_id, reproductions DESC); ANALYZE music;" | Out-Null

Write-Host "`n=== CENARIO 3: INDICES (COM INDICE) ===" -ForegroundColor Green
foreach ($vus in $VusList) {
    Invoke-K6Test -Name "c3-com-indice" -Script "$PSScriptRoot\scenario3-index.js" -EnvVars @{} -Vus $vus
}

Write-Host "`n=== Testes concluidos! Resultados em $ResultsDir ===" -ForegroundColor Green
