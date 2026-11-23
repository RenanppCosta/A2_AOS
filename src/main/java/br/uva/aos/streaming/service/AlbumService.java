package br.uva.aos.streaming.service;

import br.uva.aos.streaming.dto.QueryReport;
import br.uva.aos.streaming.entity.Album;
import br.uva.aos.streaming.entity.AlbumEager;
import br.uva.aos.streaming.repository.AlbumEagerRepository;
import br.uva.aos.streaming.repository.AlbumRepository;
import jakarta.persistence.EntityManagerFactory;
import java.util.List;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final AlbumEagerRepository albumEagerRepository;
    private final Statistics statistics;

    public AlbumService(AlbumRepository albumRepository,
                        AlbumEagerRepository albumEagerRepository,
                        EntityManagerFactory entityManagerFactory) {
        this.albumRepository = albumRepository;
        this.albumEagerRepository = albumEagerRepository;
        this.statistics = entityManagerFactory.unwrap(SessionFactory.class).getStatistics();
    }

    @Transactional(readOnly = true)
    public QueryReport lazy(int limit) {
        long start = begin();
        List<Album> albums = albumRepository.findFirst(PageRequest.of(0, limit));
        int musics = 0;
        for (Album a : albums) {
            musics += a.getMusics().size();   // aqui dispara a query de cada álbum
        }
        return report("LAZY", albums.size(), musics, start);
    }

    @Transactional(readOnly = true)
    public QueryReport eager(int limit) {
        long start = begin();
        List<AlbumEager> albums = albumEagerRepository.findFirst(PageRequest.of(0, limit));
        int musics = 0;
        for (AlbumEager a : albums) {
            musics += a.getMusics().size();
        }
        return report("EAGER", albums.size(), musics, start);
    }

    @Transactional(readOnly = true)
    public QueryReport optimized(int limit) {
        long start = begin();
        List<Album> albums = albumRepository.findWithMusics(limit);
        int musics = 0;
        for (Album a : albums) {
            musics += a.getMusics().size();
        }
        return report("JOIN FETCH", albums.size(), musics, start);
    }

    @Transactional(readOnly = true)
    public QueryReport lazyAlbumsOnly(int limit) {
        long start = begin();
        List<Album> albums = albumRepository.findFirst(PageRequest.of(0, limit));
        return report("LAZY (so albuns)", albums.size(), 0, start);
    }

    @Transactional(readOnly = true)
    public QueryReport eagerAlbumsOnly(int limit) {
        long start = begin();
        List<AlbumEager> albums = albumEagerRepository.findFirst(PageRequest.of(0, limit));
        return report("EAGER (so albuns)", albums.size(), 0, start);
    }

    private long begin() {
        statistics.clear();
        return System.nanoTime();
    }

    private QueryReport report(String strategy, int albums, int musics, long startNanos) {
        long ms = (System.nanoTime() - startNanos) / 1_000_000;
        return new QueryReport(strategy, albums, musics,
                statistics.getPrepareStatementCount(),
                statistics.getEntityLoadCount(), ms);
    }
}
