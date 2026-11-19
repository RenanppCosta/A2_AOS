-- Experimento do Item 5 (índices). Rode manualmente, comando a comando:
--
-- 1) SEM índice (rode 3x e guarde o print da última):
EXPLAIN ANALYZE
SELECT * FROM music WHERE album_id = 150 ORDER BY reproductions DESC;

-- 2) Criar o índice:
CREATE INDEX idx_music_album_reproductions ON music (album_id, reproductions DESC);
ANALYZE music;

-- 3) COM índice (mesma consulta):
EXPLAIN ANALYZE
SELECT * FROM music WHERE album_id = 150 ORDER BY reproductions DESC;

-- 4) Voltar ao estado sem índice (antes de repetir testes de carga "sem índice"):
-- DROP INDEX idx_music_album_reproductions;
