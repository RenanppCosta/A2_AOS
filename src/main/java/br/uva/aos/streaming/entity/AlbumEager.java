package br.uva.aos.streaming.entity;

import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Mesma tabela "album", mapeada com EAGER, só para comparar com a entidade Album (LAZY).
 * Entidade somente leitura (sem setters).
 */
@Entity
@Table(name = "album")
public class AlbumEager {

    @Id
    private Long id;
    private String title;
    private Integer releaseYear;

    @OneToMany(fetch = FetchType.EAGER)
    @JoinColumn(name = "album_id", insertable = false, updatable = false)
    private List<Music> musics = new ArrayList<>();

    public Long getId() { return id; }
    public String getTitle() { return title; }
    public Integer getReleaseYear() { return releaseYear; }
    public List<Music> getMusics() { return musics; }
}
