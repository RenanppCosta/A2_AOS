package br.uva.aos.streaming.service;

import br.uva.aos.streaming.config.CacheConfig;
import br.uva.aos.streaming.dto.MusicDTO;
import br.uva.aos.streaming.dto.UpdateMusicRequest;
import br.uva.aos.streaming.entity.Music;
import br.uva.aos.streaming.repository.MusicRepository;
import java.util.List;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.Caching;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class MusicService {

    private static final int TOP_SIZE = 50;

    private final MusicRepository repository;

    public MusicService(MusicRepository repository) {
        this.repository = repository;
    }

    // ---------------- Top 50 (cache principal do trabalho) ----------------

    /** Cenário A: toda requisição ordena a tabela no banco. */
    @Transactional(readOnly = true)
    public List<MusicDTO> top50WithoutCache() {
        return loadTop50();
    }

    /** Cenário B: só vai ao banco em cache miss (ou depois do TTL / invalidação). */
    @Cacheable(cacheNames = CacheConfig.TOP_MUSICS_CACHE, key = "'top50'")
    @Transactional(readOnly = true)
    public List<MusicDTO> top50WithCache() {
        return loadTop50();
    }

    private List<MusicDTO> loadTop50() {
        return repository.findTop(PageRequest.of(0, TOP_SIZE)).stream()
                .map(MusicDTO::from)
                .toList();
    }

    // ---------------- Busca por id (contraste: consulta barata) ----------------

    /** Cenário A: sempre consulta o banco. */
    @Transactional(readOnly = true)
    public MusicDTO findWithoutCache(Long id) {
        return MusicDTO.from(find(id));
    }

    /** Cenário B: só consulta o banco em cache miss. */
    @Cacheable(cacheNames = CacheConfig.MUSICS_CACHE, key = "#id")
    @Transactional(readOnly = true)
    public MusicDTO findWithCache(Long id) {
        return MusicDTO.from(find(id));
    }

    // ---------------- Atualização + invalidação ----------------

    /**
     * Atualiza no banco e invalida os caches afetados: a entrada da música e o
     * ranking Top 50 (que pode ter mudado de ordem).
     */
    @Caching(evict = {
            @CacheEvict(cacheNames = CacheConfig.MUSICS_CACHE, key = "#id"),
            @CacheEvict(cacheNames = CacheConfig.TOP_MUSICS_CACHE, allEntries = true)
    })
    @Transactional
    public MusicDTO update(Long id, UpdateMusicRequest request) {
        Music music = find(id);
        if (request.title() != null) music.setTitle(request.title());
        if (request.reproductions() != null) music.setReproductions(request.reproductions());
        return MusicDTO.from(music);   // o Hibernate grava no commit (dirty checking)
    }

    private Music find(Long id) {
        return repository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Music not found"));
    }
}
