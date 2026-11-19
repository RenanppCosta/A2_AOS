package br.uva.aos.streaming.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import java.util.concurrent.TimeUnit;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableCaching
public class CacheConfig {

    /** Cache de músicas individuais (busca por id). */
    public static final String MUSICS_CACHE = "musics";

    /** Cache do ranking Top 50 (consulta cara: ordena a tabela inteira). */
    public static final String TOP_MUSICS_CACHE = "top-musics";

    @Bean
    public CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager(MUSICS_CACHE, TOP_MUSICS_CACHE);
        manager.setCaffeine(Caffeine.newBuilder()
                .expireAfterWrite(60, TimeUnit.SECONDS)  // TTL
                .maximumSize(10_000)
                .recordStats());                         // permite ver hits e misses
        return manager;
    }
}
