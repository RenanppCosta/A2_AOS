# Compara sem cache x com cache (MISS e HIT) para o Top 50 e para a busca por id.
# Reinicie a aplicação antes de rodar e deixe o terminal dela visível.
$base = "http://localhost:8080"
$n = 10
$id = 30

function Measure-Calls($url, $times) {
    $t = @()
    for ($i = 0; $i -lt $times; $i++) {
        $t += (Measure-Command { Invoke-RestMethod $url | Out-Null }).TotalMilliseconds
    }
    return $t
}

function Summary($name, $t) {
    [pscustomobject]@{
        Operacao = $name
        Chamadas = $t.Count
        Media_ms = [math]::Round(($t | Measure-Object -Average).Average, 1)
        Min_ms   = [math]::Round(($t | Measure-Object -Minimum).Minimum, 1)
        Max_ms   = [math]::Round(($t | Measure-Object -Maximum).Maximum, 1)
    }
}

function Measure-Misses($url, $times) {
    $t = @()
    for ($i = 0; $i -lt $times; $i++) {
        Invoke-RestMethod -Method Delete "$base/api/cache" | Out-Null   # força o miss
        $t += (Measure-Command { Invoke-RestMethod $url | Out-Null }).TotalMilliseconds
    }
    return $t
}

# aquecimento da JVM (não entra na tabela)
1..3 | ForEach-Object {
    Invoke-RestMethod "$base/api/music/top50/sem-cache" | Out-Null
    Invoke-RestMethod "$base/api/music/$id/sem-cache" | Out-Null
}

$rows = @()

# ---- Top 50 ----
$rows += Summary "Top 50 - sem cache"        (Measure-Calls "$base/api/music/top50/sem-cache" $n)
$rows += Summary "Top 50 - com cache (MISS)" (Measure-Calls "$base/api/music/top50/com-cache" 1)
$rows += Summary "Top 50 - com cache (HIT)"  (Measure-Calls "$base/api/music/top50/com-cache" $n)

# ---- Busca por id (contraste: consulta barata) ----
$rows += Summary "Por id - sem cache"        (Measure-Calls "$base/api/music/$id/sem-cache" $n)
$rows += Summary "Por id - com cache (MISS)" (Measure-Calls "$base/api/music/$id/com-cache" 1)
$rows += Summary "Por id - com cache (HIT)"  (Measure-Calls "$base/api/music/$id/com-cache" $n)

$rows | Format-Table -AutoSize

"Estatisticas dos caches:"
$stats = Invoke-RestMethod "$base/api/cache/stats"
"top-musics:"; $stats.'top-musics' | Format-Table
"musics:";     $stats.'musics'     | Format-Table