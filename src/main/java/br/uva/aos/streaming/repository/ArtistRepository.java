package br.uva.aos.streaming.repository;

import br.uva.aos.streaming.entity.Artist;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ArtistRepository extends JpaRepository<Artist, Long> {
}