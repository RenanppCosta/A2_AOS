package br.uva.aos.streaming.repository;

import br.uva.aos.streaming.entity.Music;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MusicRepository extends JpaRepository<Music, Long> {
}