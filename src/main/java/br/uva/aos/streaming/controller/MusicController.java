package br.uva.aos.streaming.controller;

import br.uva.aos.streaming.dto.MusicDTO;
import br.uva.aos.streaming.dto.UpdateMusicRequest;
import br.uva.aos.streaming.service.MusicService;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/music")
public class MusicController {

    private final MusicService service;

    public MusicController(MusicService service) {
        this.service = service;
    }

    // ----- Top 50 (cache principal) -----

    @GetMapping("/top50/sem-cache")
    public List<MusicDTO> top50WithoutCache() {
        return service.top50WithoutCache();
    }

    @GetMapping("/top50/com-cache")
    public List<MusicDTO> top50WithCache() {
        return service.top50WithCache();
    }

    // ----- Busca por id (contraste) -----

    @GetMapping("/{id}/sem-cache")
    public MusicDTO withoutCache(@PathVariable Long id) {
        return service.findWithoutCache(id);
    }

    @GetMapping("/{id}/com-cache")
    public MusicDTO withCache(@PathVariable Long id) {
        return service.findWithCache(id);
    }

    @GetMapping("/album/{albumId}")
    public List<MusicDTO> byAlbum(@PathVariable Long albumId) {
        return service.findByAlbum(albumId);
    }

    // ----- Atualização -----

    @PutMapping("/{id}")
    public MusicDTO update(@PathVariable Long id, @RequestBody UpdateMusicRequest request) {
        return service.update(id, request);
    }
}
