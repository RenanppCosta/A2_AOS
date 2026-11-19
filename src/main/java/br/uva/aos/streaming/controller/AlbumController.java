package br.uva.aos.streaming.controller;

import br.uva.aos.streaming.dto.QueryReport;
import br.uva.aos.streaming.service.AlbumService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/albums")
public class AlbumController {

    private final AlbumService service;

    public AlbumController(AlbumService service) {
        this.service = service;
    }

    @GetMapping("/lazy")
    public QueryReport lazy(@RequestParam(defaultValue = "100") int limit) {
        return service.lazy(limit);
    }

    @GetMapping("/eager")
    public QueryReport eager(@RequestParam(defaultValue = "100") int limit) {
        return service.eager(limit);
    }

    @GetMapping("/optimized")
    public QueryReport optimized(@RequestParam(defaultValue = "100") int limit) {
        return service.optimized(limit);
    }

    @GetMapping("/lazy-albums-only")
    public QueryReport lazyAlbumsOnly(@RequestParam(defaultValue = "100") int limit) {
        return service.lazyAlbumsOnly(limit);
    }

    @GetMapping("/eager-albums-only")
    public QueryReport eagerAlbumsOnly(@RequestParam(defaultValue = "100") int limit) {
        return service.eagerAlbumsOnly(limit);
    }
}
