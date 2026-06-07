# Aşama 3 — İki Motor MIMO Modelleme (MATLAB)

> **Amaç:** İkinci motor + encoder eklenip **çapraz kuplaj** karakterize edilir:
> 2×2 transfer matrisi $G(s)$, RGA + condition number analizi (`[Skogestad2005] §3, §10`),
> decoupling potansiyeli. Derin anlatı → `../../docs/asama_3_mimo_model.md` (iskelet).

---

## Scriptler (planlı — aşama ilerledikçe doldurulur)

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
└── results/             ← üretilen PNG/JSON (git'te; konu-bazlı alt klasörler)
```

Ham veri `artifacts/3/<test_id>/raw/`'dan okunur (test artifact disiplini — global CLAUDE.md).
