# Aşama 3 — İki Motor MIMO Modelleme (MATLAB)

> **Amaç:** İkinci motor + encoder eklenip **çapraz kuplaj** karakterize edilir:
> 2×2 transfer matrisi $G(s)$, RGA + condition number analizi (`[Skogestad2005] §3, §10`),
> decoupling potansiyeli. Derin anlatı → `../../docs/asama_3_mimo_model.md` (kapanış içeriği §12.x).
>
> **Aşama 3 ✅ YÜKSÜZ KAPALI (2026-06-24, tag asama-3-kapali):** HP eksen-0 cascade karakterize edildi ($\tau\approx70$ ms — eski "yavaş τ≈420 ms" hükmü §12.11'de firmware-ramp confound olarak çürütüldü), analitik tasarım flash'landı; bench **stick-slip** gösterdi. Sanılan ~32 ms loop kök-neden aslında **KOPUK-IMU I2C-BUSY artefaktıydı** → tek-satır GPIO_PULLUP, loop 32→6/8 ms (timer-ISR GEREKMEDİ, §12.13/§12.14). HP K0/K1 baseline KAPALI, residual limit-cycle → K7/Aşama-5. Detay: `../../docs/asama_3_mimo_model.md` §12.13/§12.14.

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

### Yüklü sürtünme/gravite feedforward (✅ tasarım+sim — 🧪 bench PASS)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `design_loaded_feedforward.m` | Yüklü cascade (Karnopp stick-slip + ölçülen $a$=0.097/$u_c$=0.090/$u_s$=0.107) üzerinde **computed-torque feedforward** 4 yapı × 3 setpoint kıyası; $\theta_{std}$ limit-cycle göstergesi | `results/loaded_ff/` (compare_50deg + thetastd_map PNG) | ✅ sim → 🧪 bench PASS |

> **Sonuç:** FF-yok ort. $\theta_{std}$ 2.21° (limit-cycle), gravite-only 2.60° (daha kötü — Coulomb baskın), grav+Coulomb **sign 0.00°** / **ölü-bant 0.34°** (bastırır). **Bench (motor-2, 20°): off 1.30°→ db 0.00°** — sim doğrulandı. Firmware: `LFF/LFFG/LFFC/LFFDB` (default kapalı). Derin anlatı + bench: [`../../docs/asama_3_mimo_model.md`](../../docs/asama_3_mimo_model.md) §12.8. Yüklü-ID: `scripts/loaded_id_test.py`; bench: `scripts/loaded_ff_test.py`.

### HP plant ID (eksen-0, HW-039/BTS7960 — teşhis)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `hp_identify.m` | HP plant kimliği step verisinden: ω=dEC/dt → `tfest` (1./2. mertebe + gecikme) ile $\tau_{HP}$ doğrulaması. **ARTIK SÜPERSEDED:** §12.12 Faz-1 temiz karakterizasyon $\tau\approx70$ ms verdi; ~420 ms premisi §12.11'de **firmware-ramp confound** olarak çürütüldü | `results/3_hp_id/` (hp_step_id.png + hp_id.json) | 🟡 erken teşhis (superseded) — temiz karakterizasyon docs §12.11/§12.12 |

### HP ekseni cascade (eksen-0, 3-faz, docs §12.12)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `hp_cascade_design.m` | HP cascade analitik tasarım: iç hız PI $K_p=0.00167$/$K_i=0.0548$ (serbest-mil $K_g\approx1042$'den; firmware'de rijit $K_g=974$/$\tau=72$ ms ile $K_i=0.0570$'e re-derive edildi, docs §12.14.7 — bkz `hp_cascade_redesign.m`) (PM 68°) + dış pozisyon P $K_{p,pos}=2.0$ (PM 88°), `pidtune` doğrulamalı; Faz-1 temiz karakterizasyon ($\tau\approx70$ ms) üzerine; bench stick-slip teşhisi | `results/hp_cascade/` (5 PNG) | 🧪 bench (stick-slip; loop-rate fix erteli — kök-neden ~32 ms loop, docs §12.12.5) |
| `hp_cascade_redesign.m` | Rijit-mount limit-cycle kök-neden + fix-option scan: **NONLİNEER** Karnopp stick-slip + kuantizasyon simülasyonu, yön-asimetrik feedforward; rijit re-char ($K_g$/$\tau$) üzerine fix-seçenek taraması (docs §12.13.4-5) | `results/hp_cascade_redesign/` (hp_redesign_optionB.png + hp_redesign_scan.png — 2 PNG) | 📐 sim |

> **Sonuç:** Faz-1 forward-yön temiz (RPWM kablo-fix), K/τ simetrik, dead-band statik 0.21≫kinetik 0.14. Faz-2 analitik cascade `pidtune` doğrulandı. Faz-3 firmware per-eksen split flash OK. **Bench:** HP hedefi 3-15° aşıp yapışıyor; Coulomb FF çözmedi (bipolar sign-FF limit-cycle). Kök neden **~32 ms IMU-bağlı loop** (eski Aşama 0-2 ~7 ms → ölçülen ~32 ms, docs §12.12.5) — kazanç-uzayı tükendi; kanıtlanmış fix loop-rate ayrımı (sonraki oturum). Derin anlatı: [`../../docs/asama_3_mimo_model.md`](../../docs/asama_3_mimo_model.md) §12.12.

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
├── design_gyro_feedforward.m        (K2)
├── design_gain_schedule.m           (K3)
├── analyze_rga.m                    (K4)
├── design_loaded_feedforward.m      (yüklü sürtünme/gravite FF — §12.8)
├── hp_identify.m                    (HP plant ID — 🟡 erken teşhis, superseded §12.12)
├── hp_cascade_design.m              (HP cascade analitik tasarım — §12.12)
├── hp_cascade_redesign.m            (rijit re-char + limit-cycle kök-neden, nonlineer Karnopp sim — 📐 sim, §12.13.4-5)
└── results/
    ├── 3_3_eksen_mimari/   ← eksen_mimari.png
    ├── 3_3_bench/          ← cascade/mirror/stab + model_validation PNG + JSON
    ├── 3_8_gyro_ff/ · 3_9_gain_sched/ · 3_5_rga/
    ├── 3_hp_id/           ← hp_step_id.png + hp_id.json (🟡 erken teşhis, superseded)
    ├── hp_cascade/        ← hp_inner_speed_pi · hp_inner_tau_robustness · hp_outer_position_p · hp_bench_noFF_stickslip · hp_bench_FF_limitcycle (5 PNG)
    ├── hp_cascade_redesign/ ← hp_redesign_optionB.png + hp_redesign_scan.png (rijit re-char + fix-option scan — 📐 sim, §12.13.4-5)
    └── loaded_ff/         ← compare_50deg + thetastd_map PNG
```

Ham veri `artifacts/3/<test_id>/raw/`'dan okunur (test artifact disiplini — global CLAUDE.md).
Grafikler kalıcı `results/`'a yazılır (git'te; `raw/` gitignored → embed kalıcı kaynaktan).
