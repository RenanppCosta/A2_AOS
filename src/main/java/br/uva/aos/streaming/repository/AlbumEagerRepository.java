package br.uva.aos.streaming.repository;

import br.uva.aos.streaming.entity.AlbumEager;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AlbumEagerRepository extends JpaRepository<AlbumEager, Long> {

    @Query("select a from AlbumEager a order by a.id")
    List<AlbumEager> findFirst(Pageable pageable);
}
