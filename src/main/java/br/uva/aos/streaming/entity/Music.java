package br.uva.aos.streaming.entity;

import jakarta.persistence.*;
import java.time.LocalDate;

@Entity
@Table(name = "music")
public class Music {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String title;
    private Integer secondsDuration;
    private Long reproductions;
    private LocalDate releaseDate;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "album_id")
    private Album album;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public Integer getSecondsDuration() { return secondsDuration; }
    public void setSecondsDuration(Integer secondsDuration) { this.secondsDuration = secondsDuration; }
    public Long getReproductions() { return reproductions; }
    public void setReproductions(Long reproductions) { this.reproductions = reproductions; }
    public LocalDate getReleaseDate() { return releaseDate; }
    public void setReleaseDate(LocalDate releaseDate) { this.releaseDate = releaseDate; }
    public Album getAlbum() { return album; }
    public void setAlbum(Album album) { this.album = album; }
}