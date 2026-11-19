package br.uva.aos.streaming.dto;

import br.uva.aos.streaming.entity.Artist;

public record ArtistDTO(Long id, String name, String country, String genre) {

    public static ArtistDTO from(Artist a) {
        return new ArtistDTO(a.getId(), a.getName(), a.getCountry(), a.getGenre());
    }
}
