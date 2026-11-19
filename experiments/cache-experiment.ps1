$base = "http://localhost:8080"
$rows = @()

function Step($name, [scriptblock]$action) {
    $hora = Get-Date -Format "HH:mm:ss.fff"
    $ms = (Measure-Command { & $action | Out-Null }).TotalMilliseconds
    $script:rows += [pscustomobject]@{ Hora = $hora; Passo = $name; Tempo_ms = [math]::Round($ms, 1) }
}

# aquecimento da JVM (nao entra na tabela)
1..3 | ForEach-Object { Invoke-RestMethod "$base/api/music/top50/sem-cache" | Out-Null }

Invoke-RestMethod -Method Delete "$base/api/cache"
Step "1 - primeira chamada (MISS)"  { Invoke-RestMethod "$base/api/music/top50/com-cache" }
Step "2 - segunda chamada (HIT)"    { Invoke-RestMethod "$base/api/music/top50/com-cache" }
$novo = Get-Random -Minimum 90000000 -Maximum 99999999
Step "3 - PUT musica 10 (invalida)" { Invoke-RestMethod -Method Put -Uri "$base/api/music/10" -ContentType "application/json" -Body (@{ reproductions = $novo } | ConvertTo-Json) }
Step "4 - apos o PUT (MISS)"        { Invoke-RestMethod "$base/api/music/top50/com-cache" }
Step "5 - chamada seguinte (HIT)"   { Invoke-RestMethod "$base/api/music/top50/com-cache" }
$rows | Format-Table -AutoSize

"Estatisticas (esperado: hits 2, misses 2):"
(Invoke-RestMethod "$base/api/cache/stats").'top-musics' | Format-Table

"Aguardando 65 s para o TTL expirar..."
Start-Sleep -Seconds 65
$rows = @()
Step "6 - apos o TTL (MISS)" { Invoke-RestMethod "$base/api/music/top50/com-cache" }
$rows | Format-Table -AutoSize

"Estatisticas (esperado: misses 3):"
(Invoke-RestMethod "$base/api/cache/stats").'top-musics' | Format-Table