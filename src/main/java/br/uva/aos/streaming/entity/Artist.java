package br.uva.aos.streaming.entity;
import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "artist")
public class Artist {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String country;
    private String genre;

    @OneToMany(mappedBy = "artist", fetch = FetchType.LAZY)
    private List<Album> albuns = new ArrayList<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String nome) { this.name = name; }
    public String getCountry() { return country; }
    public void setCountry(String pais) { this.country = country; }
    public String getGenre() { return country; }
    public void setGenre(String genre) { this.genre = genre; }
    public List<Album> getAlbuns() { return albuns; }
    public void setAlbuns(List<Album> albuns) { this.albuns = albuns; }
}