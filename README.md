# Otimização de Web Services — Streaming de Música

Trabalho Prático A2 — Análise e Otimização de Sistemas (UVA) — Prof. André Lucio

## 1. Introdução

_(TODO: apresentar a aplicação e os objetivos. Sugestão: API REST de um serviço de streaming
(artistas, álbuns e músicas) usada para medir o efeito de cache, estratégias de carregamento
(LAZY/EAGER), JOIN FETCH, índices e testes de carga.)_

## 2. Arquitetura e tecnologias

| Camada | Tecnologia |
|---|---|
| API | Spring Boot 4 (Spring Web MVC), Java 21 |
| Persistência | Spring Data JPA + Hibernate |
| Banco | PostgreSQL 16 (Docker) |
| Cache | Caffeine (cache local em memória) |
| Testes de carga | k6 _(TODO: confirmar a ferramenta)_ |

**Entidades:** `Artist` (1:N) `Album` (1:N) `Music`

**Volume de dados:** 1.000 artistas, 10.000 álbuns, 100.000 músicas (`scripts/02-data.sql`).

### Como executar

```powershell
docker compose up -d            # sobe o PostgreSQL (porta 5433) e popula o banco na 1ª vez
.\mvnw.cmd spring-boot:run      # sobe a API em http://localhost:8080
# recriar o banco do zero:  docker compose down -v ; docker compose up -d
```

> O banco usa a porta **5433** no host porque a 5432 pode estar ocupada por um PostgreSQL local.

### Endpoints

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/music/top50/sem-cache` | Ranking das 50 músicas mais tocadas, sempre no banco |
| GET | `/api/music/top50/com-cache` | Ranking Top 50 usando cache (Caffeine) |
| GET | `/api/music/{id}/sem-cache` | Busca a música sempre no banco |
| GET | `/api/music/{id}/com-cache` | Busca a música usando cache (Caffeine) |
| PUT | `/api/music/{id}` | Atualiza `title`/`reproductions` e invalida os caches afetados |
| GET | `/api/cache/stats` | Hits, misses, hitRate e tamanho de cada cache |
| DELETE | `/api/cache` | Limpa os caches (cache frio) |
| GET | `/api/albums/lazy?limit=N` | Álbuns + músicas com LAZY (N+1) |
| GET | `/api/albums/eager?limit=N` | Álbuns + músicas com EAGER |
| GET | `/api/albums/optimized?limit=N` | Álbuns + músicas com JOIN FETCH |
| GET | `/api/albums/lazy-albums-only?limit=N` | Só álbuns (LAZY) |
| GET | `/api/albums/eager-albums-only?limit=N` | Só álbuns (EAGER carrega músicas à toa) |

Os endpoints `/api/albums/*` devolvem um relatório (`QueryReport`): quantidade de SQLs
executados, entidades carregadas e tempo. Os contadores do Hibernate são globais, então
use esses endpoints **uma requisição por vez** (evidência), e não dentro do teste de carga.

## 3. Implementação de cache

### 3.1 Identificação de informações cacheáveis

Foram avaliadas duas operações de consulta. O **Top 50** é o dado principal do experimento; a
**busca por id** entra como contraste, para mostrar que o cache nem sempre compensa.

| Critério (seção 3.1) | Top 50 músicas mais tocadas | Busca de uma música por id |
|---|---|---|
| Frequência de acesso | Alta: é a vitrine de um serviço de streaming, lida por muitos usuários | Média: depende da música |
| Volatilidade | Média: `reproductions` muda, mas o topo do ranking varia devagar em relação à frequência de leitura | Média: o contador da música muda a cada atualização |
| Custo de recuperação | **Alto**: ordena as 100 mil músicas por `reproductions` (sem índice) e junta o álbum | **Baixo**: busca por chave primária |
| Consequência de dado desatualizado | Baixa: um ranking defasado por até 60 s é aceitável | Baixa |
| Necessidade de invalidação | Sim: uma atualização pode mudar a ordem do ranking | Sim: a entrada da música muda |

**Decisão:** o Top 50 é o melhor candidato (lido com frequência, caro de calcular e tolerante a
pequenos atrasos). A busca por id foi mantida em cache apenas como contraste.

### 3.2 Implementação das duas versões

| Cenário | Endpoint | Comportamento |
|---|---|---|
| A — sem cache | `GET /api/music/top50/sem-cache` | Consulta o banco em toda requisição |
| B — com cache | `GET /api/music/top50/com-cache` | Consulta o banco só em *cache miss* |

As duas versões executam a **mesma consulta**; a única diferença é a anotação `@Cacheable`.
A busca por id segue o mesmo padrão (`/api/music/{id}/sem-cache` e `/api/music/{id}/com-cache`).

```java
// Cenário A: sempre vai ao banco
@Transactional(readOnly = true)
public List<MusicDTO> top50WithoutCache() { return loadTop50(); }

// Cenário B: só vai ao banco em cache miss (ou depois do TTL / invalidação)
@Cacheable(cacheNames = CacheConfig.TOP_MUSICS_CACHE, key = "'top50'")
@Transactional(readOnly = true)
public List<MusicDTO> top50WithCache() { return loadTop50(); }
```

```sql
-- Consulta executada pelo Hibernate (aparece no log a cada acesso ao banco):
select ... from music m join album a on a.id = m.album_id
order by m.reproductions desc, m.id fetch first 50 rows only
```

### 3.3 Tecnologia de cache

Foi usado o **Caffeine**, um cache em memória dentro da própria aplicação.

- **Por que:** não exige servidor extra, tem latência mínima (não há rede), oferece TTL e limite
  de tamanho nativamente e expõe estatísticas de *hit* e *miss* (`recordStats()`), que usamos
  no endpoint `/api/cache/stats`.
- **Alternativas:** o **Redis** é um cache distribuído; compartilharia o cache entre várias
  instâncias da aplicação, mas exigiria um serviço adicional e uma ida pela rede a cada consulta,
  o que não se justifica em um experimento de uma única instância. Hazelcast e Infinispan são
  mais pesados para este escopo.
- **Limitação:** cada instância da aplicação teria o seu próprio cache (ver riscos em 3.4).

### 3.4 Tempo de vida (TTL) e invalidação

```java
Caffeine.newBuilder()
        .expireAfterWrite(60, TimeUnit.SECONDS)   // TTL de 60 s, contado a partir da gravação
        .maximumSize(10_000)
        .recordStats();
```

- **TTL (60 s):** após 60 s da gravação, a entrada expira sozinha. A leitura **não** renova o prazo.
- **Invalidação:** `PUT /api/music/{id}` remove a entrada da música e **todo** o cache do Top 50
  (`@Caching` + `@CacheEvict`), porque a atualização pode mudar a ordem do ranking.
- **Por que as duas:** a invalidação garante que mudanças feitas pela aplicação apareçam
  imediatamente; o TTL é a rede de segurança para qualquer mudança que não passe por ela.

#### Experimento obrigatório (seção 3.4)

Executado por `experiments/cache-experiment.ps1` (aquecimento da JVM antes, banco com 100 mil músicas):

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\cache-experiment.ps1
```

| # | Passo | Etapa do enunciado | Resultado esperado |
|---|---|---|---|
| 1 | 1ª consulta ao Top 50 | consultar e registrar o comportamento | **MISS**: vai ao banco |
| 2 | 2ª consulta | repetir e verificar o reaproveitamento | **HIT**: sem acesso ao banco |
| 3 | `PUT` na música 10 (nova quantidade de reproduções) | modificar pela aplicação | atualiza o banco e invalida o cache |
| 4 | consulta após o `PUT` | verificar se o dado está atualizado | **MISS**, ranking já atualizado |
| 5 | consulta seguinte | | **HIT** |
| 6 | consulta 65 s depois, sem nenhuma atualização | demonstrar a expiração | **MISS** (TTL expirou) |

**Resultado medido:**

![Resultado do script cache-experiment](img.png)

| Hora | Passo | Tempo (ms) | Foi ao banco? |
|---|---|---|---|
| 18:59:53.886 | 1 — primeira chamada (MISS) | 57,6 | sim |
| 18:59:53.953 | 2 — segunda chamada (HIT) | 4,9 | **não** |
| 18:59:53.972 | 3 — PUT música 10 (invalida) | 114,8 | sim (`select` por id + `update`) |
| 18:59:54.088 | 4 — após o PUT (MISS) | 37,1 | sim |
| 18:59:54.126 | 5 — chamada seguinte (HIT) | 4,4 | **não** |
| 19:00:59.176 | 6 — após o TTL (MISS) | 41,9 | sim |

Estatísticas do cache `top-musics`: depois do passo 5, `hits = 2`, `misses = 2`, `hitRate = 0,5`;
depois do passo 6, `hits = 2`, `misses = 3`, `hitRate = 0,4`, `size = 1`.

**Log da aplicação durante o experimento** (cada linha `org.hibernate.SQL` é um acesso ao banco):

![Log do terminal ao rodar o script](img_2.png)

| Hora no log | Linha | Corresponde a |
|---|---|---|
| 18:59:53.604 / .795 / .835 | `select ... order by reproductions desc` (3x) | aquecimento (`sem-cache`) |
| 18:59:53.908 | `select ... order by reproductions desc` | passo 1 — **MISS** |
| *(nenhuma linha)* | | passo 2 — **HIT** |
| 18:59:54.055 | `select ... from music where id=?` | passo 3 — o `PUT` lê a música 10 |
| 18:59:54.073 | `update music set ...` | passo 3 — o `PUT` grava no banco |
| 18:59:54.091 | `select ... order by reproductions desc` | passo 4 — **MISS** (cache invalidado) |
| *(nenhuma linha)* | | passo 5 — **HIT** |
| 19:00:59.182 | `select ... order by reproductions desc` | passo 6 — **MISS** (TTL expirou) |

**Conclusões do experimento:**
- **Reaproveitamento:** nos passos 2 e 5 não há `select` no log: a resposta veio do cache.
- **Invalidação:** após o `PUT`, o passo 4 voltou ao banco e já trouxe o dado atualizado.
- **TTL:** entre o passo 5 e o passo 6 passaram-se cerca de 65 s sem nenhuma atualização, e mesmo
  assim o `select` voltou a aparecer: a entrada expirou sozinha.

**Dado desatualizado.** A estratégia permite dado desatualizado em dois casos: (1) se o banco for
alterado por fora da aplicação (script SQL, outro serviço), o cache só se corrige quando o TTL
expira, ou seja, por até 60 s; (2) com mais de uma instância da aplicação, o `@CacheEvict` limpa
apenas o cache da instância que recebeu o `PUT`. Em ambos os casos o risco é o usuário ver um
ranking defasado por no máximo o tempo do TTL.

### 3.5 Análise de desempenho do cache

#### Resultado do experimento (Top 50)

| Métrica | Sem cache | Com cache |
|---|---|---|
| Tempo de resposta (média, 10 chamadas; ver tabela abaixo) | 34 ms | 2,8 ms (*hit*) |
| Acessos ao banco (5 consultas do experimento 3.4: passos 1, 2, 4, 5 e 6) | 5 | **3** (passos 1, 4 e 6) |
| Hit / miss no experimento 3.4 | — | 2 *hits* e 3 *misses* (`hitRate` = 0,4) |

O *hit* foi cerca de **12 vezes mais rápido** que a consulta sem cache (34 → 2,8 ms, redução de
≈ 92%) e, no experimento 3.4, eliminou 2 dos 5 acessos ao banco. O tempo medido inclui o HTTP
local e o PowerShell, portanto o ganho efetivo no banco é maior. Os *hits* do experimento 3.4
(4,9 e 4,4 ms) foram um pouco mais lentos que a média da comparação (2,8 ms) porque são apenas
duas amostras, medidas logo após invalidações.

#### Comparação com × sem cache (10 chamadas cada)

Executado por `experiments/cache-comparison.ps1`:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\cache-comparison.ps1
```

| Operação | Média (ms) | Mín (ms) | Máx (ms) |
|---|---|---|---|
| Top 50 — sem cache | 34 | 32,3 | 37,7 |
| Top 50 — com cache (MISS) | 50,8 | 50,8 | 50,8 |
| Top 50 — com cache (HIT) | 2,8 | 2,5 | 3,4 |
| Busca por id — sem cache | 4,6 | 4,2 | 5,1 |
| Busca por id — com cache (MISS) | 6,7 | 6,7 | 6,7 |
| Busca por id — com cache (HIT) | 2,5 | 1,2 | 11,5 |

![img_4.png](img_4.png)
Estatísticas ao final: cada cache registrou 10 *hits* e 1 *miss* (`hitRate` ≈ 0,91). Os
*misses* foram medidos com uma única chamada cada, portanto são amostras isoladas. Na busca por
id, a média do HIT (2,5 ms) é puxada por um valor isolado de 11,5 ms; sem ele, a média cairia
para ≈ 1,5 ms.

#### Efeito do TTL e da invalidação

- **TTL:** dentro dos 60 s a leitura é servida do cache; passado o prazo a entrada expira e a próxima
  leitura é um *miss* que repovoa o cache (passo 6).
- **Invalidação:** cada `PUT` limpa o Top 50, então a leitura seguinte é sempre um *miss*
  (passo 4). Com poucas atualizações isso é irrelevante; com muitas, o cache perde eficácia.
  No experimento, o `hitRate` caiu para 0,4 justamente por causa da invalidação e do TTL.

#### Perguntas da seção 3.5

**1. Em quais situações o cache apresentou maior benefício?**
Em leituras repetidas do Top 50 dentro da janela do TTL: a consulta ordena 100 mil linhas, então o
*hit* (≈ 2,8 ms) foi cerca de 12 vezes mais rápido que a consulta sem cache (≈ 34 ms), uma
economia de ≈ 31 ms por requisição, e poupou acessos ao banco. Quanto mais leituras por janela de
60 s, maior o benefício.


**2. Como a volatilidade dos dados influenciou a escolha do TTL?**
`reproductions` muda com frequência, mas o topo do ranking varia devagar em relação à frequência
de leitura. Um TTL maior aumenta os *hits*, mas também o tempo máximo de dado desatualizado; um
TTL menor deixa o dado mais fresco, mas gera mais *misses*. Escolheu-se 60 s por tolerar um
ranking defasado por até 1 minuto. A invalidação explícita no `PUT` cobre as mudanças feitas pela
aplicação, e o TTL cobre as demais.

**3. Quais são os riscos de utilizar informações desatualizadas?**
O usuário pode ver um ranking defasado por até o tempo do TTL quando o banco é alterado por fora da
aplicação. Com várias instâncias, o cache local de cada uma só se corrige pelo TTL, e
instâncias diferentes podem mostrar rankings diferentes. Em dados críticos (saldo, estoque,
preço) esse risco seria inaceitável; para um ranking de popularidade é tolerável.

**4. O cache sempre melhorou o desempenho? Justifique com os resultados observados.**
Não. O ganho depende do custo da consulta: no Top 50 o *hit* economizou ≈ 31 ms por
requisição (34 → 2,8 ms); na busca por id, apenas ≈ 2 ms (4,6 → 2,5 ms), porque a consulta por
chave primária já era barata. O *miss* é mais lento que o *sem cache*: faz a mesma consulta e
ainda soma a verificação e a gravação no cache (50,8 ms contra 34 ms no Top 50 e 6,7 ms contra
4,6 ms na busca por id; cada *miss* é uma única amostra, então parte da diferença pode ser
ruído). Para um dado lido uma única vez, o cache só acrescenta custo; ele compensa quando há
*hits* suficientes para cobrir os *misses*. Com atualizações frequentes, cada `PUT` esvazia o
ranking e o `hitRate` cai (0,4 no experimento 3.4), o que reduz o benefício. O cache só compensa
quando a leitura é cara, repetida e tolera pequena defasagem.

## 4. Otimização das consultas

Esta seção investiga como a estratégia de carregamento do relacionamento **Álbum → Músicas** (1:N)
influencia a quantidade de consultas SQL, o tempo de resposta e o volume de dados recuperados, e
como um índice altera o plano de execução de uma consulta.

Os endpoints `/api/albums/*` devolvem um relatório (`QueryReport`) montado com as estatísticas do Hibernate:

| Campo | Significado |
|---|---|
| `albums` / `musics` | álbuns e músicas retornados |
| `sqlStatements` | número de comandos SQL executados (evidência do N+1) |
| `entitiesLoaded` | número de entidades carregadas na sessão (volume de dados recuperado) |
| `timeMs` | tempo da operação medido no servidor |

> Os contadores do Hibernate são globais, então os endpoints foram chamados **uma requisição por vez**.
> Com `limit=5` o objetivo é mostrar o **comportamento** (log do SQL ligado); os tempos dessas chamadas
> únicas incluem aquecimento da JVM e **não** servem para comparar estratégias. A comparação de
> tempos está em 4.3, com aquecimento e média de 5 chamadas.

### 4.1 Estratégia LAZY e o problema N+1

`Album` mapeia as músicas com carregamento sob demanda:

```java
@OneToMany(mappedBy = "album", fetch = FetchType.LAZY)
private List<Music> musics = new ArrayList<>();
```

A operação `GET /api/albums/lazy?limit=N` busca os N primeiros álbuns e, para cada um, acessa a
coleção de músicas:

```java
List<Album> albums = albumRepository.findFirst(PageRequest.of(0, limit));   // 1 query
for (Album a : albums) {
    musics += a.getMusics().size();      // dispara 1 query por álbum (carregamento sob demanda)
}
```

**Resultado com `limit=5`:**

![Resposta de /api/albums/lazy?limit=5](img_5.png)
![Log SQL de /api/albums/lazy?limit=5](img_7.png)

| Hora no log | Linha | Corresponde a |
|---|---|---|
| 20:26:51.509 | `select ... from album ... order by id fetch first ? rows only` | 1 query dos álbuns |
| 20:26:51.515 / .529 / .539 / .549 / .560 | `select ... from music where album_id=?` (5x) | 1 query de músicas **por álbum**, disparada no `getMusics()` |

Total: **6 comandos SQL** (`sqlStatements = 6`), ou seja, 1 + N com N = 5. Esse é o problema **N+1**:
o número de consultas cresce linearmente com o número de álbuns (esperado: 1.001 consultas com
`limit=1000`; confirmado na tabela de 4.3).

### 4.2 Estratégia EAGER

O `fetch` é definido na entidade e vale para qualquer uso dela. Para comparar as duas estratégias
sobre os mesmos dados, a tabela `album` foi mapeada em uma segunda entidade, **somente leitura**,
com carregamento antecipado:

```java
@Entity
@Table(name = "album")
public class AlbumEager {
    @Id private Long id;
    private String title;
    private Integer releaseYear;

    @OneToMany(fetch = FetchType.EAGER)
    @JoinColumn(name = "album_id", insertable = false, updatable = false)
    private List<Music> musics = new ArrayList<>();
}
```

`GET /api/albums/eager?limit=N` executa a mesma operação (busca N álbuns e soma suas músicas).

**Resultado com `limit=5`:**

![Resposta de /api/albums/eager?limit=5](img_8.png)
![Log SQL de /api/albums/eager?limit=5](img_9.png)

| Hora no log | Linha | Corresponde a |
|---|---|---|
| 20:30:13.698 | `select ... from album ... order by id fetch first ? rows only` | 1 query dos álbuns |
| 20:30:13.708 / .726 / .744 / .775 / .794 | `select ... from music where album_id=?` (5x) | 1 query de músicas por álbum, **logo após** a query principal |

**Observações:**
- **O EAGER não virou uma única consulta:** foram 6 comandos SQL, o mesmo número do LAZY. Isso
  confirma o aviso do enunciado: o carregamento EAGER define *quando* os dados são carregados
  (imediatamente), e não *como* (com `JOIN` ou com consultas separadas). Na consulta JPQL do
  repositório, o Hibernate carregou os álbuns e depois inicializou a coleção de cada um com uma
  query própria.
- **Diferença para o LAZY:** no LAZY as queries extras acontecem quando o código acessa
  `getMusics()`; no EAGER elas acontecem **sempre**, logo após a query principal, mesmo que o código
  nunca use as músicas (comprovado em 4.3, no cenário "só álbuns").
- **Limitação da comparação:** `Album` mapeia a coluna `artist_id` e `AlbumEager` não, então o
  `select` dos álbuns tem uma coluna a mais no LAZY. O que se compara é o tratamento das músicas.

### 4.3 Comparação das estratégias

#### Resultado já medido (limit = 5)

| Estratégia | Comandos SQL | Entidades carregadas | Ocorrência de N+1 |
|---|---|---|---|
| LAZY | 6 | 55 (5 álbuns + 50 músicas) | **Sim** |
| EAGER | 6 | 55 | **Sim** |
| JOIN FETCH (4.4) | 1 | 55 | Não |

O volume de dados recuperado é o mesmo nas três estratégias (55 entidades); o que muda é o número
de idas ao banco.

#### Comparação com quantidades diferentes de registros

Executado por `experiments/lazy-eager-comparison.ps1` (aquecimento + média de 5 chamadas). Para essa
medição o log do SQL foi desligado (`org.hibernate.SQL = INFO`) para não distorcer os tempos.

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\lazy-eager-comparison.ps1
```

| Estratégia | Álbuns | Músicas | Comandos SQL | Entidades carregadas | Tempo médio (ms) | Mín (ms) | Máx (ms) |
|---|---|---|---|---|---|---|---|
| LAZY | 10 | 10 | 11 | 110 | 92,2 | 88 | 99 |
| EAGER | 10 | 10 | 11 | 110 | 86,2 | 85 | 88 |
| JOIN FETCH | 10 | 10 | 1 | 110 | 10,2 | 10 | 11 |
| LAZY | 100 | 100 | 101 | 1100 | 837,2 | 817 | 875 |
| EAGER | 100 | 100 | 101 | 1100 | 818,6 | 815 | 824 |
| JOIN FETCH | 100 | 100 | 1 | 1100 | 16,4 | 16 | 17 |
| LAZY | 1000 | 1000 | 1001 | 11000 | 8204,8 | 8179 | 8236 |
| EAGER | 1000 | 1000 | 1001 | 11000 | 8577,8 | 8276 | 8947 |
| JOIN FETCH | 1000 | 1000 | 1 | 11000 | 87 | 83 | 91 |

![img_12.png](img_12.png)

#### Efeito de carregar dados desnecessários

Quando o código precisa **apenas dos álbuns** (por exemplo, uma listagem de títulos) e não das músicas:

| Estratégia | Álbuns | Comandos SQL | Entidades carregadas | Tempo médio (ms) |
|---|---|---|---|---|
| LAZY (só álbuns) | 100 | 1 | 100 | 1,4 |
| EAGER (só álbuns) | 100 | 101 | 1100 | 839,2 |
| LAZY (só álbuns) | 1000 | 1 | 1000 | 6 |
| EAGER (só álbuns) | 1000 | 1001 | 11000 | 8317 |

![img_13.png](img_13.png)

_( Esperado: o LAZY faz 1 comando e carrega só os álbuns; o EAGER continua
executando uma query por álbum e carregando todas as músicas, sem que ninguém as use.)_

#### Em quais situações LAZY ou EAGER é mais adequado

- **LAZY é mais adequado** quando o relacionamento nem sempre é usado (listagens que mostram só dados
  do álbum), quando a coleção é grande ou quando o acesso é pontual (detalhe de um único álbum).
  O risco é percorrer a coleção de muitos objetos e cair no N+1 (4.1); nesses casos, combinar com
  `JOIN FETCH` ou busca em lote.
- **EAGER é mais adequado** quando o dado relacionado é pequeno e **sempre** usado junto com a
  entidade principal. Deve ser evitado em coleções grandes ou usadas só às vezes: além de custar
  consultas extras, carrega dados que ninguém lê (ver tabela acima) e **não garante** uma única
  consulta (4.2).
- **Regra prática adotada:** mapear como LAZY e buscar exatamente o necessário em cada caso de uso
  (por exemplo, com `JOIN FETCH`).

### 4.4 Otimização das consultas

A alternativa implementada foi o **`JOIN FETCH`** em JPQL, que traz os álbuns e as músicas em uma
única consulta:

```java
@Query("select distinct a from Album a join fetch a.musics where a.id <= :limit order by a.id")
List<Album> findWithMusics(@Param("limit") long limit);
```

**Resultado com `limit=5`:**

![Resposta de /api/albums/optimized?limit=5](img_10.png)
![Log SQL de /api/albums/optimized?limit=5](img_11.png)

SQL gerado pelo Hibernate (1 único comando):

```sql
select distinct a1_0.id, a1_0.artist_id, m1_0.album_id, m1_0.id, m1_0.release_date, m1_0.reproductions,
       m1_0.seconds_duration, m1_0.title, a1_0.release_year, a1_0.title
from album a1_0 join music m1_0 on a1_0.id = m1_0.album_id
where a1_0.id <= ? order by a1_0.id
```

**Original × otimizada:** com `limit=5`, de 6 comandos SQL (LAZY e EAGER) para **1** (JOIN FETCH),
carregando as mesmas 55 entidades. A comparação de tempos com 10, 100 e 1000 álbuns está na tabela
de 4.3. Nela, na comparação de 1000 álbuns, o LAZY fez 1.001 comandos e 8204,8 ms, enquanto o JOIN FETCH fez 1 comando e 87 ms.

**Cuidados e limitações do `JOIN FETCH`:**
- O `distinct` evita álbuns duplicados no resultado (a junção gera uma linha por música).
- Foi usado `where a.id <= :limit` em vez de paginação: combinar `JOIN FETCH` de coleção com
  paginação faz o Hibernate aplicar a paginação **em memória** (carrega tudo e corta depois).
- A consulta fica específica para o caso de uso, e o resultado maior trafega em uma única resposta.

**Outras alternativas (não implementadas):** projeção em DTO (traz só as colunas necessárias) e busca
em lote (`@BatchSize`, reduz de 1 + N para 1 + N/tamanho do lote).

#### SQL nativo trouxe benefícios reais?

SQL nativo **não foi usado**, e não era necessário: o log mostra que o Hibernate já gerou **uma única
consulta com `JOIN`**, equivalente à que seria escrita à mão. Um SQL nativo não reduziria o número de
comandos nem o tempo neste caso. As consequências de adotá-lo seriam:
- **Portabilidade:** o SQL fica preso ao dialeto do PostgreSQL; JPQL é traduzido para cada banco.
- **Manutenção:** o texto SQL não é validado pelo compilador nem pelo mapeamento (mudanças no schema
  quebram em tempo de execução) e o resultado precisa ser mapeado manualmente para objetos.
- **Perda de recursos do ORM:** entidades retornadas por consulta nativa exigem mais cuidado com o
  contexto de persistência e o carregamento de relacionamentos.
- **Quando valeria a pena:** consultas complexas (funções de janela, CTEs, recursos específicos do
  banco), nas quais o JPQL não consegue expressar a consulta ou o plano gerado é ruim.

### 4.5 Índices (seção 5 do enunciado)

#### Consulta selecionada

```sql
SELECT * FROM music WHERE album_id = 150 ORDER BY reproductions DESC;
```

Combina **filtro** (`album_id`) e **ordenação** (`reproductions`). É também a consulta que o LAZY
executa para cada álbum no N+1, então um índice aqui afeta a aplicação inteira. Pelo schema, a tabela
`music` só tem o índice da chave primária (`music_pkey`), que não atende a esse filtro; o PostgreSQL
não cria índice automático para chave estrangeira.

#### Sem índice × com índice

Executado com os comandos de `experiments/indexes.sql`:

```powershell
docker exec -it streaming-db psql -U streaming -c "\d music"
docker exec -it streaming-db psql -U streaming -c "EXPLAIN ANALYZE SELECT * FROM music WHERE album_id = 150 ORDER BY reproductions DESC;"
docker exec -it streaming-db psql -U streaming -c "CREATE INDEX idx_music_album_reproductions ON music (album_id, reproductions DESC);"
docker exec -it streaming-db psql -U streaming -c "ANALYZE music;"
docker exec -it streaming-db psql -U streaming -c "EXPLAIN ANALYZE SELECT * FROM music WHERE album_id = 150 ORDER BY reproductions DESC;"
```

#### Plano de execução

**Sem índice:** ![img_14.png](img_14.png)

**Com índice:** ![img_15.png](img_15.png)

| Item do plano | Sem índice | Com índice |
|---|---|---|
| Operação de acesso à tabela | `Seq Scan on music` | `Index Scan using idx_music_album_reproductions on music` |
| Varredura completa da tabela | Sim | Não |
| Operação de ordenação (`Sort`) | Sim (`quicksort`, `25kB`, `reproductions DESC`) | Não |
| Linhas descartadas pelo filtro (`Rows Removed by Filter`) | `99990` | `0` (`Index Cond: (album_id = 150)`) |
| Linhas retornadas | `10` | `10` |
| Tempo de planejamento (ms) | `0.199` | `0.232` |
| Tempo de execução (ms) | `7.149` | `0.055` |

**Efeito do índice na aplicação (N+1):** repetindo `lazy?limit=1000` (mesma metodologia de 4.3):

| Cenário | Comandos SQL | Tempo médio (ms) |
|---|---|---|
| LAZY, limit=1000, sem índice | ___ | ___ |
| LAZY, limit=1000, com índice | ___ | ___ |

**Custo em espaço:**

| Objeto | Tamanho |
|---|---|
| Tabela `music` | `8536 kB` |
| Índice `idx_music_album_reproductions` | `3104 kB` |
![img_16.png](img_16.png)

#### Perguntas da seção 5.4

**1. O índice foi efetivamente utilizado pelo banco?**
_(Responder com o plano. Ex.: "Sim: o plano passou de `Seq Scan on music` para `Index Scan using
idx_music_album_reproductions`." Informar também se o banco usou algum outro índice existente: o
único era `music_pkey`, que não atende ao filtro por `album_id`.)_

**2. Houve redução no tempo de execução?**
Sim: de 7.149 ms para 0.055 ms (redução de 99,23%)"

**3. Quais fatores influenciaram o resultado?**
- **Seletividade:** o filtro `album_id = 150` retorna ~10 linhas de 100.000 (≈ 0,01% da tabela),
  o cenário em que o índice mais compensa; para consultas que devolvem grande parte da tabela, o
  planejador tende a preferir a varredura completa.
- **Ordem das colunas do índice:** `album_id` primeiro (igualdade no `WHERE`) e `reproductions DESC`
  depois, o que entrega as linhas já ordenadas e elimina a etapa de `Sort` _(confirmar no plano)_.
- **Estatísticas do banco:** o `ANALYZE` mantém atualizadas as estimativas usadas pelo planejador.
- **Cache de páginas:** a primeira execução pode estar "fria"; por isso cada consulta foi executada
  3 vezes e foi registrada a última.
- **Tamanho dos dados:** com 100 mil linhas o ganho é visível; em tabelas pequenas a diferença seria
  desprezível.

**4. Quais podem ser os custos de manter índices adicionais?**
- **Espaço em disco:** o índice ocupa 3104 kB (tabela: 8536 kB).
- **Escritas mais lentas:** cada `INSERT`, `UPDATE` e `DELETE` precisa atualizar também o índice.
  Como `reproductions` faz parte do índice, cada `PUT` que altera as reproduções de uma música (Item 1)
  também passa a atualizar o índice.
- **Manutenção:** o índice sofre fragmentação com muitas atualizações e depende de rotinas como
  `VACUUM`; além disso, mais índices dão mais opções (e mais chances de erro) ao planejador.

**5. Criar índices em todas as colunas consultadas seria uma boa estratégia? Por quê?**
Não. Cada índice adicional consome espaço e torna **todas** as escritas mais lentas, e índices que
nenhuma consulta usa são custo sem benefício. Em colunas de baixa seletividade (poucos valores
distintos) o planejador costuma ignorar o índice e fazer a varredura completa. A estratégia correta
é indexar o que as consultas reais precisam, validando com `EXPLAIN ANALYZE`.

> **Atenção:** antes dos testes de carga do Item 3 (seção 5), o índice deve ser removido
> (`DROP INDEX idx_music_album_reproductions;`) para medir o cenário "sem índice" e depois recriado
> para medir o cenário "com índice".

## 5. Testes de desempenho

_(TODO — Item 3.)_

## 6. Discussão

_(TODO)_

## 7. Conclusão

_(TODO)_
