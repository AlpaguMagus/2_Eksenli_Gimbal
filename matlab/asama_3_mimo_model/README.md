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

### K2 gyro feedforward (3.8, ✅ tasarım+sim — donanımsız)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `design_gyro_feedforward.m` | Analitik $k_{ff}=$ redüktör $=9.7$ türetme; 2-DOF bozucu-reddi: $S_{fb}=1/(1+L_{out})$ vs $S_{ff}=1-T_{in}$ vs FB+FF; reddi-bant 0.89→3.63 Hz (**4.1×**); zaman-domeni (2 Hz sentetik + gerçek base) | `results/3_8_gyro_ff/` (design + block PNG + JSON) | ✅ tasarım/sim (firmware bekliyor) |

> ⚠ İç-döngü plant'ı **duty-domeni** $K_g=K\cdot V_s=654.8$ kullanılmalı (Aşama 2.3 H1 — voltaj $K=53.89$ değil); `analyze_mirror_stab.m` de bu konvansiyona göre düzeltildi.

### K3 gain scheduling ön-tasarım (3.9, ✅ analiz — mevcut veriden)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `design_gain_schedule.m` | Aşama-1 ölçülen $\tau$(duty) (43→133 ms) → duty-indeksli $K_i$ schedule ($K_i\propto\tau$, sabit $\omega_n=33$); sabit-kazançla step kıyası + LUT | `results/3_9_gain_sched/` (4-panel PNG + JSON LUT) | ✅ analiz |

> **Sonuç (dürüst):** schedule $\omega_n$'i sabitler (sabit-kazanç 38→22 rad/s değişir) AMA $K_p$ doyum-kısıtında (0.002) sabit kaldığından **ζ yüksek-duty'de azalır** (tam ζ sabitliği $K_p>0.002$ ister). Saturation-kısıtlı aktüatörde fayda **marjinal** → firmware'in **"gain scheduling default KAPALI"** kararını destekler (sigorta gelince $K_p$ gevşer, schedule değerlenir). LUT hazır.

### MIMO ID (3.4–3.5, planlı — iki sağlam eksen gelince)

| Script | Amaç | Durum |
|---|---|---|
| `load_mimo_data.m` | SISO↔MIMO veri toplama CSV'lerini oku (her motoru ayrı sür, diğerini ölç) | ⬜ planlı |
| `fit_transfer_matrix.m` | 2×2 $G(s)$ tahmini (`tfest`, eleman-bazlı) | ⬜ planlı |
| `analyze_rga.m` | RGA $\Lambda = G(0) \circ (G(0)^{-1})^T$ + condition number + **karar kuralı** (decentralized vs MIMO). **✅ çerçeve hazır** (sentetik doğrulandı: zayıf→λ11=1.01 "K1 yeter", güçlü→2.78 "MIMO"); gerçek 2-motor verisi beklemede | 🟡 çerçeve |
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
