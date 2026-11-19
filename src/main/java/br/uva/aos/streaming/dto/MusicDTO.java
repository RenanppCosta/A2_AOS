package br.uva.aos.streaming.dto;

import br.uva.aos.streaming.entity.Music;

public record MusicDTO(Long id, String title, Integer secondsDuration,
                       Long reproductions, Long albumId) {

    public static MusicDTO from(Music m) {
        return new MusicDTO(m.getId(), m.getTitle(), m.getSecondsDuration(),
                m.getReproductions(), m.getAlbum().getId());
    }
}
