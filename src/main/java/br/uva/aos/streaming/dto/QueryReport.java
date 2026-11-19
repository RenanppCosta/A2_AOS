package br.uva.aos.streaming.dto;

public record QueryReport(String strategy, int albums, int musics,
                          long sqlStatements, long entitiesLoaded, long timeMs) {
}
