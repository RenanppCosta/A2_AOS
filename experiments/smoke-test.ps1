# Teste de fumaca da aplicacao inteira (Itens 1, 2 e 3).
#
# Pre-requisitos: banco no ar (docker compose up -d) e API rodando em http://localhost:8080.
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\experiments\smoke-test.ps1
#   powershell -ExecutionPolicy Bypass -File .\experiments\smoke-test.ps1 -WithTtl -WithK6
#     -WithTtl : tambem testa a expiracao do cache (espera 65 s)
#     -WithK6  : tambem roda um teste curto (5 s, 10 VUs) de cada cenario do k6
#
# Obs.: o teste faz um PUT na musica 10 (muda as reproducoes dela) e nao altera o indice.
param(
    [string]$Base = "http://localhost:8080",
    [switch]$WithTtl,
    [switch]$WithK6
)

$script:pass = 0
$script:fail = 0

function Section([string]$title) {
    Write-Host ""
    Write-Host "=== $title ===" -ForegroundColor Cyan
}

function Check([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) {
        $script:pass++
        Write-Host "[ OK ] $name" -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host "[FALHA] $name  $detail" -ForegroundColor Red
    }
}

function Expect([string]$name, $actual, $expected) {
    Check $name ($actual -eq $expected) "esperado: $expected | obtido: $actual"
}

function Get-Json([string]$path) {
    Invoke-RestMethod "$Base$path"
}

function Sql([string]$query) {
    $out = docker exec streaming-db psql -U streaming -t -A -c $query 2>$null
    return ("$out").Trim()
}

# ------------------------------------------------------------------ 1. banco
Section "1. Banco de dados"
$n = Sql "select count(*) from artist;"
Expect "tabela artist tem 1000 registros" $n "1000"
$n = Sql "select count(*) from album;"
Expect "tabela album tem 10000 registros" $n "10000"
$n = Sql "select count(*) from music;"
Expect "tabela music tem 100000 registros" $n "100000"
$idx = Sql "select count(*) from pg_indexes where indexname = 'idx_music_album_reproductions';"
if ($idx -eq "1") {
    Write-Host "[INFO] O indice idx_music_album_reproductions EXISTE (estado 'com indice')." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] O indice idx_music_album_reproductions NAO existe (estado 'sem indice')." -ForegroundColor Yellow
}

# ------------------------------------------------------------------ 2. API e busca por id
Section "2. API e busca por id"
try {
    $m = Get-Json "/api/music/1/sem-cache"
    Check "GET /api/music/1/sem-cache responde com id = 1" ($m.id -eq 1)
} catch {
    Check "API respondendo em $Base" $false $_.Exception.Message
    Write-Host "Suba a API antes de continuar." -ForegroundColor Red
    exit 1
}
$m2 = Get-Json "/api/music/1/com-cache"
Check "com-cache devolve a mesma musica que sem-cache" (($m.title -eq $m2.title) -and ($m.reproductions -eq $m2.reproductions))
try {
    Invoke-RestMethod "$Base/api/music/99999999/sem-cache" | Out-Null
    Check "404 para musica inexistente" $false "a API respondeu 200"
} catch {
    Check "404 para musica inexistente" ([int]$_.Exception.Response.StatusCode -eq 404)
}

# ------------------------------------------------------------------ 3. cache
Section "3. Cache (Top 50)"
Invoke-RestMethod -Method Delete "$Base/api/cache" | Out-Null
$s0 = Get-Json "/api/cache/stats"
$hits0 = [int]$s0.'top-musics'.hits
$miss0 = [int]$s0.'top-musics'.misses

$sem = Get-Json "/api/music/top50/sem-cache"
$a = Get-Json "/api/music/top50/com-cache"
$b = Get-Json "/api/music/top50/com-cache"
$s1 = Get-Json "/api/cache/stats"
$dh = [int]$s1.'top-musics'.hits - $hits0
$dm = [int]$s1.'top-musics'.misses - $miss0

Expect "Top 50 devolve 50 musicas" $sem.Count 50
Check "Top 50 sem cache e com cache devolvem o mesmo ranking" (($sem.id -join ",") -eq ($a.id -join ","))
Check "1a chamada com cache = miss e 2a = hit" (($dm -eq 1) -and ($dh -eq 1)) "hits +$dh, misses +$dm (esperado +1 e +1)"

$novo = 90000000 + (Get-Random -Minimum 1 -Maximum 9000000)
$body = @{ reproductions = $novo } | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$Base/api/music/10" -ContentType "application/json" -Body $body | Out-Null
$c = Get-Json "/api/music/top50/com-cache"
Check "Apos o PUT, o Top 50 foi recalculado (musica 10 em 1o, valor novo)" (($c[0].id -eq 10) -and ($c[0].reproductions -eq $novo))
$d = Get-Json "/api/music/10/com-cache"
Expect "Busca por id apos o PUT tambem esta atualizada" $d.reproductions $novo
$s2 = Get-Json "/api/cache/stats"
$dm2 = [int]$s2.'top-musics'.misses - $miss0
Check "Apos o PUT houve novo miss (invalidacao)" ($dm2 -ge 2) "misses acumulados +$dm2 (esperado >= 2)"

if ($WithTtl) {
    Section "3b. Expiracao pelo TTL (aguarda 65 s)"
    Invoke-RestMethod -Method Delete "$Base/api/cache" | Out-Null
    $t0s = Get-Json "/api/cache/stats"
    $t0 = [int]$t0s.'top-musics'.misses
    Get-Json "/api/music/top50/com-cache" | Out-Null
    Start-Sleep -Seconds 65
    Get-Json "/api/music/top50/com-cache" | Out-Null
    $t1s = Get-Json "/api/cache/stats"
    $t1 = [int]$t1s.'top-musics'.misses
    Check "Apos 65 s a entrada expirou (2 misses)" (($t1 - $t0) -eq 2) "misses +$($t1 - $t0) (esperado +2)"
}

# ------------------------------------------------------------------ 4. LAZY x EAGER x JOIN FETCH
Section "4. LAZY x EAGER x JOIN FETCH (limit = 5)"
$l = Get-Json "/api/albums/lazy?limit=5"
Expect "LAZY: 6 comandos SQL (1 + 5, N+1)" $l.sqlStatements 6
Expect "LAZY: 55 entidades (5 albuns + 50 musicas)" $l.entitiesLoaded 55
$e = Get-Json "/api/albums/eager?limit=5"
Expect "EAGER: 6 comandos SQL (tambem N+1)" $e.sqlStatements 6
Expect "EAGER: 55 entidades" $e.entitiesLoaded 55
$o = Get-Json "/api/albums/optimized?limit=5"
Expect "JOIN FETCH: 1 comando SQL" $o.sqlStatements 1
Expect "JOIN FETCH: 55 entidades" $o.entitiesLoaded 55
$lo = Get-Json "/api/albums/lazy-albums-only?limit=5"
Expect "LAZY so albuns: 1 comando SQL" $lo.sqlStatements 1
Expect "LAZY so albuns: 5 entidades" $lo.entitiesLoaded 5
$eo = Get-Json "/api/albums/eager-albums-only?limit=5"
Expect "EAGER so albuns: 6 comandos SQL (carrega musicas a toa)" $eo.sqlStatements 6
Expect "EAGER so albuns: 55 entidades" $eo.entitiesLoaded 55

# ------------------------------------------------------------------ 5. consulta do cenario de indice
Section "5. Consulta do cenario de indice"
$ba = Get-Json "/api/music/album/150"
Expect "GET /api/music/album/150 devolve 10 musicas" $ba.Count 10
$ordenado = ($ba.reproductions | Sort-Object -Descending) -join ","
Check "musicas ordenadas por reproductions (decrescente)" (($ba.reproductions -join ",") -eq $ordenado)

# ------------------------------------------------------------------ 6. k6 (opcional)
if ($WithK6) {
    Section "6. k6 (testes curtos: 5 s, 10 VUs)"
    if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
        Check "k6 instalado (comando k6 no PATH)" $false "instale o k6 e abra um novo terminal"
    } else {
        Check "k6 instalado" $true
        $dir = Join-Path $PSScriptRoot "k6"
        $tmp = Join-Path $env:TEMP "k6-smoke"
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $out = Join-Path $tmp "resultado.json"
        $tests = @(
            @{ Nome = "Cenario 1 (sem cache)";     Script = "scenario1-cache.js";       Env = @("-e", "MODE=sem-cache") },
            @{ Nome = "Cenario 1 (cache quente)";  Script = "scenario1-cache.js";       Env = @("-e", "MODE=com-cache-quente") },
            @{ Nome = "Cenario 2 (LAZY)";          Script = "scenario2-persistence.js"; Env = @("-e", "STRATEGY=lazy", "-e", "LIMIT=10") },
            @{ Nome = "Cenario 2 (JOIN FETCH)";    Script = "scenario2-persistence.js"; Env = @("-e", "STRATEGY=optimized", "-e", "LIMIT=10") },
            @{ Nome = "Cenario 3 (indice)";        Script = "scenario3-index.js";       Env = @() }
        )
        foreach ($t in $tests) {
            $envArgs = @($t.Env)
            $scriptPath = Join-Path $dir $t.Script
            & k6 run --quiet --summary-export $out -e "BASE_URL=$Base" -e "VUS=10" -e "DURATION=5s" @envArgs $scriptPath | Out-Null
            $j = Get-Content $out -Raw | ConvertFrom-Json
            $erros = [double]$j.metrics.http_req_failed.value
            $reqs = [int]$j.metrics.http_reqs.count
            Check "$($t.Nome): $reqs requisicoes, 0% de erros" (($reqs -gt 0) -and ($erros -eq 0)) "taxa de erros: $($erros * 100)%"
        }
    }
}

# ------------------------------------------------------------------ resultado
Write-Host ""
$cor = "Green"
if ($script:fail -gt 0) { $cor = "Red" }
Write-Host "Resultado: $($script:pass) verificacoes OK, $($script:fail) falhas." -ForegroundColor $cor
if ($script:fail -gt 0) { exit 1 }
