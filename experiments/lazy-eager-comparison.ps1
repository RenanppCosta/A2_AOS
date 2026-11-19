# Compara LAZY x EAGER x JOIN FETCH para 10, 100 e 1000 álbuns, e o caso "só álbuns".
#
# ANTES de rodar: reinicie a aplicação com o log do SQL DESLIGADO, para não distorcer os tempos
# (com limit=1000 o LAZY imprimiria mais de 1000 linhas de log por chamada):
#   .\mvnw.cmd spring-boot:run "-Dspring-boot.run.arguments=--logging.level.org.hibernate.SQL=INFO --logging.level.org.hibernate.stat=INFO"
# (se esse comando não funcionar, troque DEBUG por INFO no application.yml e reinicie)
#
# Os contadores do Hibernate são globais: não rode outras chamadas em paralelo.

$base = "http://localhost:8080/api/albums"
$runs = 5

function Run($strategy, $limit) {
    Invoke-RestMethod "$base/${strategy}?limit=$limit" | Out-Null      # aquecimento (não entra na média)
    $times = @()
    $last = $null
    for ($i = 0; $i -lt $runs; $i++) {
        $last = Invoke-RestMethod "$base/${strategy}?limit=$limit"
        $times += $last.timeMs
    }
    [pscustomobject]@{
        Estrategia = $last.strategy
        Limit      = $limit
        Albuns     = $last.albums
        Musicas    = $last.musics
        SQLs       = $last.sqlStatements
        Entidades  = $last.entitiesLoaded
        Media_ms   = [math]::Round(($times | Measure-Object -Average).Average, 1)
        Min_ms     = ($times | Measure-Object -Minimum).Minimum
        Max_ms     = ($times | Measure-Object -Maximum).Maximum
    }
}

$main = @()
foreach ($n in 10, 100, 1000) {
    foreach ($s in "lazy", "eager", "optimized") {
        $main += Run $s $n
    }
}
"=== LAZY x EAGER x JOIN FETCH (media de $runs chamadas apos aquecimento) ==="
$main | Format-Table -AutoSize

$only = @()
foreach ($n in 100, 1000) {
    foreach ($s in "lazy-albums-only", "eager-albums-only") {
        $only += Run $s $n
    }
}
"=== Quando as musicas NAO sao necessarias ==="
$only | Format-Table -AutoSize
