# Aşama 3 — İki Motor MIMO Modelleme (MATLAB)

> **Amaç:** İkinci motor + encoder eklenip **çapraz kuplaj** karakterize edilir:
> 2×2 transfer matrisi $G(s)$, RGA + condition number analizi (`[Skogestad2005] §3, §10`),
> decoupling potansiyeli. Derin anlatı → `../../docs/asama_3_mimo_model.md` (iskelet).

---

## Scriptler

### K0 kapanışı — gerçek-donanım sonuç + analiz (3.3, ✅ tamam)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `create_axis_architecture_diagram.m` | Instance-based `g_axis[2]` decentralized blok diyagramı + mirror/stab işaret-yasası | `results/3_3_eksen_mimari/`, `results/3_3_bench/mirror_stab_law.png` | ✅ |
| `plot_bench_results.m` | Ham bench CSV → tez-stili PNG: cascade step / mirror / stab takip | `results/3_3_bench/{cascade_step,mirror_track,stab_track}.png` | ✅ |
| `analyze_mirror_stab.m` | Takip RMS sim-to-real doğrulama: ölçülen vs cascade `lsim` modeli (+ frekans-domeni sensitivite) | `results/3_3_bench/*_model_validation.png` + `mirror_stab_validation.json` | ✅ |

> Derin anlatı: [`../../docs/asama_3_mimo_model.md`](../../docs/asama_3_mimo_model.md) §12.4 (K0 kapanışı).
> Tümünü üret: `matlab -batch "cd('matlab/asama_3_mimo_model'); create_axis_architecture_diagram; plot_bench_results; analyze_mirror_stab"`

### MIMO ID (3.4–3.5, planlı — iki sağlam eksen gelince)

| Script | Amaç | Durum |
|---|---|---|
| `load_mimo_data.m` | SISO↔MIMO veri toplama CSV'lerini oku (her motoru ayrı sür, diğerini ölç) | ⬜ planlı |
| `fit_transfer_matrix.m` | 2×2 $G(s)$ tahmini (`tfest`, eleman-bazlı) | ⬜ planlı |
| `analyze_rga.m` | RGA $\Lambda = G(0) \circ (G(0)^{-1})^T$ + condition number | ⬜ planlı |
| `create_mimo_diagrams.m` | MIMO blok diyagramları (programatik, beyaz tema) | ⬜ planlı |

## Klasör

```
matlab/asama_3_mimo_model/
├── README.md            ← bu dosya
├── create_axis_architecture_diagram.m
├── plot_bench_results.m
├── analyze_mirror_stab.m
└── results/
    ├── 3_3_eksen_mimari/   ← eksen_mimari.png
    └── 3_3_bench/          ← cascade/mirror/stab + model_validation PNG + JSON
```

Ham veri `artifacts/3/<test_id>/raw/`'dan okunur (test artifact disiplini — global CLAUDE.md).
Grafikler kalıcı `results/`'a yazılır (git'te; `raw/` gitignored → embed kalıcı kaynaktan).
