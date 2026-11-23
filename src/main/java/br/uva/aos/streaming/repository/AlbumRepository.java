package br.uva.aos.streaming.repository;

import br.uva.aos.streaming.entity.Album;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AlbumRepository extends JpaRepository<Album, Long> {

    @Query("select a from Album a order by a.id")
    List<Album> findFirst(Pageable pageable);

    @Query("select distinct a from Album a join fetch a.musics where a.id <= :limit order by a.id")
    List<Album> findWithMusics(@Param("limit") long limit);
}
