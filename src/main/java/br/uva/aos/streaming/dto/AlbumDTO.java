package br.uva.aos.streaming.dto;

import br.uva.aos.streaming.entity.Album;

public record AlbumDTO(Long id, String title, Integer releaseYear, Long artistId) {

    public static AlbumDTO from(Album a) {
        return new AlbumDTO(a.getId(), a.getTitle(), a.getReleaseYear(), a.getArtist().getId());
    }
}
