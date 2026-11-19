package br.uva.aos.streaming.controller;

import br.uva.aos.streaming.config.CacheConfig;
import com.github.benmanes.caffeine.cache.stats.CacheStats;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCache;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/cache")
public class CacheStatsController {

    private static final List<String> CACHES =
            List.of(CacheConfig.TOP_MUSICS_CACHE, CacheConfig.MUSICS_CACHE);

    private final CacheManager cacheManager;

    public CacheStatsController(CacheManager cacheManager) {
        this.cacheManager = cacheManager;
    }

    private CaffeineCache cache(String name) {
        return (CaffeineCache) cacheManager.getCache(name);
    }

    @GetMapping("/stats")
    public Map<String, Object> stats() {
        Map<String, Object> result = new LinkedHashMap<>();
        for (String name : CACHES) {
            CacheStats s = cache(name).getNativeCache().stats();
            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("hits", s.hitCount());
            entry.put("misses", s.missCount());
            entry.put("hitRate", s.hitRate());
            entry.put("size", cache(name).getNativeCache().estimatedSize());
            result.put(name, entry);
        }
        return result;
    }

    /** Zera os caches: serve para começar os testes com cache frio. */
    @DeleteMapping
    public void clear() {
        CACHES.forEach(name -> cache(name).clear());
    }
}
