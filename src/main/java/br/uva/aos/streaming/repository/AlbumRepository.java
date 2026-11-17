package br.uva.aos.streaming.repository;

import br.uva.aos.streaming.entity.Album;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AlbumRepository extends JpaRepository<Album, Long> {
}