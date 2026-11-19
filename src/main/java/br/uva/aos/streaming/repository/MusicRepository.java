package br.uva.aos.streaming.repository;

import br.uva.aos.streaming.entity.Music;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface MusicRepository extends JpaRepository<Music, Long> {

    /**
     * Ranking das mais tocadas. O JOIN FETCH traz o álbum junto e evita
     * queries extras ao montar o DTO (nada de N+1 escondido aqui).
     */
    @Query("select m from Music m join fetch m.album order by m.reproductions desc, m.id asc")
    List<Music> findTop(Pageable pageable);
}
