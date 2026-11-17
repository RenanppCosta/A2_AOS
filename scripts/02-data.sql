-- ============================================================
-- 02-dados.sql
-- Popular banco musical para o trabalho de Análise e Otimização
-- PostgreSQL | 1.000 artistas | 10.000 álbuns | 100.000 músicas
--
-- Requisitos:
--   Tabelas já criadas (01-schema.sql):
--     artist(id, name, country, genre)
--     album(id, title, release_year, artist_id)
--     music(id, title, seconds_duration, reproductions,
--           release_date, album_id)
--
-- Observações:
--   1. Execute em um banco de testes, pois o bloco TRUNCATE limpa
--      as três tabelas e reinicia suas identidades.
--   2. O script não acessa a internet e gera sempre os mesmos dados.
--   3. Uma parte dos nomes é real; o restante é sintético, porém
--      variado. Os dados sintéticos não devem ser apresentados como
--      discografia real.
-- ============================================================

BEGIN;

TRUNCATE TABLE music, album, artist RESTART IDENTITY CASCADE;

-- ------------------------------------------------------------
-- 1) ARTISTAS
-- ------------------------------------------------------------
WITH
real_names(name, country, genre) AS (
    VALUES
      ('The Beatles', 'Reino Unido', 'Rock'),
      ('Queen', 'Reino Unido', 'Rock'),
      ('The Rolling Stones', 'Reino Unido', 'Rock'),
      ('Pink Floyd', 'Reino Unido', 'Rock'),
      ('Led Zeppelin', 'Reino Unido', 'Rock'),
      ('David Bowie', 'Reino Unido', 'Rock'),
      ('Elton John', 'Reino Unido', 'Pop'),
      ('Adele', 'Reino Unido', 'Pop'),
      ('Amy Winehouse', 'Reino Unido', 'Soul'),
      ('Ed Sheeran', 'Reino Unido', 'Pop'),
      ('Radiohead', 'Reino Unido', 'Rock'),
      ('Coldplay', 'Reino Unido', 'Rock'),
      ('Oasis', 'Reino Unido', 'Rock'),
      ('Arctic Monkeys', 'Reino Unido', 'Rock'),
      ('The Smiths', 'Reino Unido', 'Rock'),
      ('The Cure', 'Reino Unido', 'Rock'),
      ('The Who', 'Reino Unido', 'Rock'),
      ('The Clash', 'Reino Unido', 'Punk Rock'),
      ('Fleetwood Mac', 'Reino Unido', 'Rock'),
      ('Iron Maiden', 'Reino Unido', 'Heavy Metal'),
      ('Nirvana', 'EUA', 'Grunge'),
      ('Metallica', 'EUA', 'Heavy Metal'),
      ('Michael Jackson', 'EUA', 'Pop'),
      ('Madonna', 'EUA', 'Pop'),
      ('Prince', 'EUA', 'Pop'),
      ('Bruce Springsteen', 'EUA', 'Rock'),
      ('Bob Dylan', 'EUA', 'Folk'),
      ('Elvis Presley', 'EUA', 'Rock'),
      ('Aretha Franklin', 'EUA', 'Soul'),
      ('Stevie Wonder', 'EUA', 'Soul'),
      ('Whitney Houston', 'EUA', 'Pop'),
      ('Beyoncé', 'EUA', 'R&B'),
      ('Taylor Swift', 'EUA', 'Pop'),
      ('Kendrick Lamar', 'EUA', 'Hip-Hop'),
      ('Eminem', 'EUA', 'Hip-Hop'),
      ('Kanye West', 'EUA', 'Hip-Hop'),
      ('Billie Eilish', 'EUA', 'Pop'),
      ('Foo Fighters', 'EUA', 'Rock'),
      ('Green Day', 'EUA', 'Punk Rock'),
      ('Red Hot Chili Peppers', 'EUA', 'Rock'),
      ('Guns N Roses', 'EUA', 'Hard Rock'),
      ('Aerosmith', 'EUA', 'Hard Rock'),
      ('The Doors', 'EUA', 'Rock'),
      ('Jimi Hendrix', 'EUA', 'Rock'),
      ('Johnny Cash', 'EUA', 'Country'),
      ('Frank Sinatra', 'EUA', 'Jazz'),
      ('Miles Davis', 'EUA', 'Jazz'),
      ('John Coltrane', 'EUA', 'Jazz'),
      ('Louis Armstrong', 'EUA', 'Jazz'),
      ('Daft Punk', 'França', 'Eletrônica'),
      ('Justice', 'França', 'Eletrônica'),
      ('Phoenix', 'França', 'Indie Rock'),
      ('Stromae', 'Bélgica', 'Pop'),
      ('ABBA', 'Suécia', 'Pop'),
      ('Roxette', 'Suécia', 'Pop'),
      ('Avicii', 'Suécia', 'Eletrônica'),
      ('A-ha', 'Noruega', 'Pop'),
      ('Björk', 'Islândia', 'Alternativo'),
      ('Rammstein', 'Alemanha', 'Industrial'),
      ('Kraftwerk', 'Alemanha', 'Eletrônica'),
      ('Shakira', 'Colômbia', 'Pop'),
      ('Juanes', 'Colômbia', 'Rock'),
      ('Bad Bunny', 'Porto Rico', 'Reggaeton'),
      ('Calle 13', 'Porto Rico', 'Urbano'),
      ('Soda Stereo', 'Argentina', 'Rock'),
      ('Charly García', 'Argentina', 'Rock'),
      ('Mercedes Sosa', 'Argentina', 'MPB'),
      ('Gustavo Cerati', 'Argentina', 'Rock'),
      ('Luis Alberto Spinetta', 'Argentina', 'Rock'),
      ('Café Tacvba', 'México', 'Rock'),
      ('Maná', 'México', 'Rock'),
      ('Natalia Lafourcade', 'México', 'Pop'),
      ('Caetano Veloso', 'Brasil', 'MPB'),
      ('Gilberto Gil', 'Brasil', 'MPB'),
      ('Chico Buarque', 'Brasil', 'MPB'),
      ('Djavan', 'Brasil', 'MPB'),
      ('Milton Nascimento', 'Brasil', 'MPB'),
      ('Elis Regina', 'Brasil', 'MPB'),
      ('Tom Jobim', 'Brasil', 'Bossa Nova'),
      ('João Gilberto', 'Brasil', 'Bossa Nova'),
      ('Tim Maia', 'Brasil', 'Soul'),
      ('Jorge Ben Jor', 'Brasil', 'MPB'),
      ('Legião Urbana', 'Brasil', 'Rock'),
      ('Paralamas do Sucesso', 'Brasil', 'Rock'),
      ('Titãs', 'Brasil', 'Rock'),
      ('Skank', 'Brasil', 'Rock'),
      ('Charlie Brown Jr.', 'Brasil', 'Rock'),
      ('Rita Lee', 'Brasil', 'Rock'),
      ('Cássia Eller', 'Brasil', 'MPB'),
      ('Marisa Monte', 'Brasil', 'MPB'),
      ('Seu Jorge', 'Brasil', 'MPB'),
      ('Marília Mendonça', 'Brasil', 'Sertanejo'),
      ('Jorge & Mateus', 'Brasil', 'Sertanejo'),
      ('Anitta', 'Brasil', 'Pop'),
      ('Ludmilla', 'Brasil', 'Funk'),
      ('Emicida', 'Brasil', 'Hip-Hop'),
      ('Racionais MCs', 'Brasil', 'Hip-Hop'),
      ('MC Cabelinho', 'Brasil', 'Funk'),
      ('Pabllo Vittar', 'Brasil', 'Pop'),
      ('Alceu Valença', 'Brasil', 'MPB'),
      ('Zé Ramalho', 'Brasil', 'MPB'),
      ('Sepultura', 'Brasil', 'Heavy Metal'),
      ('Angra', 'Brasil', 'Heavy Metal')
),
synthetic_names AS (
    SELECT
      'Artista Independente ' || lpad(g::text, 4, '0') AS name,
      (ARRAY['Brasil','EUA','Reino Unido','Argentina','Portugal',
             'Canadá','França','Alemanha','Japão','Austrália'])
        [1 + ((g * 7) % 10)] AS country,
      (ARRAY['Rock','Pop','MPB','Funk','Jazz','Eletrônica',
             'Hip-Hop','Indie','Sertanejo','Reggae'])
        [1 + ((g * 11) % 10)] AS genre

    FROM generate_series(
      1,
      1000 - (SELECT count(*) FROM real_names)
    ) AS g
),
all_artists AS (
    SELECT name, country, genre
 FROM real_names
    UNION ALL
    SELECT name, country, genre
 FROM synthetic_names
)
INSERT INTO artist (name, country, genre)
SELECT name, country, genre

FROM all_artists;

-- ------------------------------------------------------------
-- 2) ÁLBUNS
-- Cada artista recebe exatamente 10 álbuns.
-- Os títulos combinam nomes conhecidos e títulos sintéticos.
-- ------------------------------------------------------------
WITH titles AS (
    SELECT ARRAY[
      'Abbey Road','Thriller','The Dark Side of the Moon',
      'Back in Black','Nevermind','Rumours','The Wall',
      'A Night at the Opera','Led Zeppelin IV','Kind of Blue',
      'Blue','The Joshua Tree','OK Computer','Nevermind the Bollocks',
      'Purple Rain','Like a Prayer','Born to Run','Hotel California',
      'Acabou Chorare','Clube da Esquina','Construção',
      'A Tábua de Esmeralda','Transa','Refazenda','Alucinação',
      'Dois','Que País É Este','As Quatro Estações',
      'Californication','American Idiot','Ten','Hybrid Theory',
      'Discovery','Random Access Memories','The Fame',
      '21','1989','Future Nostalgia','AM','Is This It',
      'Paranoid','Master of Puppets','Appetite for Destruction',
      'Sgt. Pepper''s Lonely Hearts Club Band','Let It Be',
      'Hunky Dory','Houses of the Holy','The Bends',
      'Definitely Maybe','Dookie','Jagged Little Pill'
    ] AS arr
)
INSERT INTO album (title, release_year, artist_id)
SELECT
    CASE
      WHEN a.id <= 100 AND n.num = 1
        THEN (SELECT arr[1 + ((a.id - 1) % cardinality(arr))]
              FROM titles)
      ELSE
        (ARRAY['Horizontes','Noite Aberta','Caminhos','Entre Mundos',
               'Sessões ao Vivo','Novas Frequências','Memórias',
               'Ponto de Partida','Lado B','Depois do Amanhã'])
          [1 + ((a.id * 3 + n.num * 7) % 10)]
        || ' - Volume ' || n.num
        || ' (' || lpad(a.id::text, 4, '0') || ')'
    END AS title,
    1980 + ((a.id * 13 + n.num * 3) % 45) AS release_year,
    a.id AS artist_id
FROM artist a
CROSS JOIN generate_series(1, 10) AS n(num)
ORDER BY a.id, n.num;

-- ------------------------------------------------------------
-- 3) MÚSICAS
-- Cada álbum recebe exatamente 10 músicas.
-- Reproduções têm distribuição desigual para simular popularidade:
-- algumas faixas são muito ouvidas e outras têm poucas reproduções.
-- ------------------------------------------------------------
WITH words AS (
    SELECT ARRAY[
      'Horizonte','Saudade','Caminho','Tempestade','Luz',
      'Silêncio','Destino','Memórias','Liberdade','Distância',
      'Coração','Cidade','Estrelas','Verdade','Labirinto',
      'Amanhecer','Noite','Tempo','Mar','Fogo',
      'Dreams','Forever','Tonight','Changes','Home',
      'Runaway','Believe','Shadows','Paradise','Revolution',
      'Blue Sky','Heartbeat','Echoes','Wildflower','Midnight',
      'Golden','Summer','Falling','Awake','Breathe'
    ] AS arr
)
INSERT INTO music (
    title, seconds_duration, reproductions, release_date, album_id
)
SELECT
    CASE
      WHEN m.num = 1 AND al.id <= 50
        THEN (SELECT arr[1 + ((al.id - 1) % cardinality(arr))]
              FROM words)
      ELSE
        (SELECT arr[1 + ((al.id * 5 + m.num * 9)
                          % cardinality(arr))]
         FROM words)
        || ' '
        || (SELECT arr[1 + ((al.id * 3 + m.num * 13 + 7)
                            % cardinality(arr))]
            FROM words)
        || ' ' || lpad(m.num::text, 2, '0')
    END AS title,

    120 + ((al.id * 17 + m.num * 29) % 241) AS seconds_duration,

    -- Distribuição determinística e assimétrica, entre 0 e ~1 milhão.
    (1000000 * power(((al.id * 7919 + m.num * 104729) % 1000) / 1000.0, 3))::bigint AS reproductions,

    DATE '1980-01-01'
      + ((al.id * 37 + m.num * 113) % 16000)::int
      AS release_date,

    al.id AS album_id
FROM album al
CROSS JOIN generate_series(1, 10) AS m(num)
ORDER BY al.id, m.num;

-- Atualiza estatísticas para o otimizador do PostgreSQL.
ANALYZE artist;
ANALYZE album;
ANALYZE music;

COMMIT;

-- ------------------------------------------------------------
-- 4) CONFERÊNCIA DOS VOLUMES
-- Execute este SELECT após a carga para validar os registros.
-- ------------------------------------------------------------
SELECT 'artist' AS table_name, count(*) AS total FROM artist
UNION ALL
SELECT 'album', count(*) FROM album
UNION ALL
SELECT 'music', count(*) FROM music;