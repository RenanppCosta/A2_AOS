import json
from pathlib import Path

RESULTS_DIR = Path(__file__).parent / "results"
CHARTS_DIR = Path(__file__).parent / "charts"
CHARTS_DIR.mkdir(parents=True, exist_ok=True)

VUS_LIST = [10, 50, 100, 200]

SCENARIOS = {
    "c1": [
        ("c1-sem-cache", "Sem cache"),
        ("c1-com-cache-quente", "Com cache (quente / HIT)"),
        ("c1-com-cache-frio", "Com cache (frio / MISS inicial)"),
    ],
    "c2": [
        ("c2-lazy", "LAZY (N+1)"),
        ("c2-eager", "EAGER (N+1)"),
        ("c2-optimized", "JOIN FETCH (otimizada)"),
    ],
    "c3": [
        ("c3-sem-indice", "Sem índice"),
        ("c3-com-indice", "Com índice"),
    ],
}


def load_metric(prefix: str, vus: int):
    path = RESULTS_DIR / f"{prefix}-vus{vus}.json"
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    m = data["metrics"]
    dur = m["http_req_duration"]
    reqs = m["http_reqs"]
    failed = m["http_req_failed"]
    return {
        "avg": dur["avg"],
        "p95": dur["p(95)"],
        "p99": dur["p(99)"],
        "rps": reqs["rate"],
        "count": int(reqs["count"]),
        "err_pct": failed["value"] * 100.0,
    }


def print_tables():
    for key, title in [
        ("c1", "Cenário 1 — Cache (GET /api/music/top50)"),
        ("c2", "Cenário 2 — Estratégias de persistência (GET /api/albums/*?limit=10)"),
        ("c3", "Cenário 3 — Índices (GET /api/music/album/{id})"),
    ]:
        print(f"\n### {title}\n")
        print("| Implementação | VUs | Latência média (ms) | p95 (ms) | p99 (ms) | Throughput (req/s) | Taxa de erros (%) | Total reqs |")
        print("|---|---:|---:|---:|---:|---:|---:|---:|")
        for prefix, label in SCENARIOS[key]:
            for vus in VUS_LIST:
                r = load_metric(prefix, vus)
                print(
                    f"| {label} | {vus} | {r['avg']:.2f} | {r['p95']:.2f} | {r['p99']:.2f} | "
                    f"{r['rps']:.1f} | {r['err_pct']:.2f}% | {r['count']} |"
                )


def generate_charts():
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("\n[AVISO] matplotlib não instalado; geração de gráficos ignorada.")
        return

    def plot_scenario(key, title, filename, colors):
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4.8))
        x = np.arange(len(VUS_LIST))
        width = 0.25 if len(SCENARIOS[key]) == 3 else 0.35

        for idx, (prefix, label) in enumerate(SCENARIOS[key]):
            avgs = [load_metric(prefix, v)["avg"] for v in VUS_LIST]
            p95s = [load_metric(prefix, v)["p95"] for v in VUS_LIST]
            rpss = [load_metric(prefix, v)["rps"] for v in VUS_LIST]
            offset = (idx - (len(SCENARIOS[key]) - 1) / 2) * width

            ax1.bar(x + offset, avgs, width, label=f"{label} (média)", color=colors[idx], alpha=0.88)
            ax1.plot(x + offset, p95s, marker="o", linestyle="--", color=colors[idx], linewidth=1.2)

            ax2.bar(x + offset, rpss, width, label=label, color=colors[idx], alpha=0.88)

        ax1.set_title("Latência Média (barras) e p95 (linha tracejada)")
        ax1.set_xticks(x)
        ax1.set_xticklabels([f"{v} VUs" for v in VUS_LIST])
        ax1.set_ylabel("Latência (ms)")
        ax1.legend(fontsize=8)

        ax2.set_title("Throughput (req/s)")
        ax2.set_xticks(x)
        ax2.set_xticklabels([f"{v} VUs" for v in VUS_LIST])
        ax2.set_ylabel("Requisições / segundo")
        ax2.legend(fontsize=8)

        fig.suptitle(title, fontsize=13, fontweight="bold")
        plt.tight_layout()
        out = CHARTS_DIR / filename
        plt.savefig(out, dpi=150)
        plt.close(fig)
        print(f"Gráfico salvo: {out}")

    plot_scenario("c1", "Cenário 1 — Cache (Top 50)", "cenario1_cache.png", ["#dc2626", "#16a34a", "#2563eb"])
    plot_scenario("c2", "Cenário 2 — Persistência (LAZY vs EAGER vs JOIN FETCH)", "cenario2_persistencia.png", ["#dc2626", "#f59e0b", "#16a34a"])
    plot_scenario("c3", "Cenário 3 — Índices (Sem índice vs Com índice)", "cenario3_indices.png", ["#dc2626", "#16a34a"])


if __name__ == "__main__":
    print_tables()
    generate_charts()
