# Aşama 4 — MIMO Kontrol (Decoupling + LQR/LQI) MATLAB

> **Rol:** Kontrol Yöntemleri Merdiveni'nin **K5–K6** basamağı (ROADMAP). Decentralized cascade
> (K0/K1) üstüne **centralized optimal** kontrol: tek-eksen LQR/LQI → (kuplaj kanıtlanırsa) MIMO.
> RGA karar kapısı (K4, Aşama 3.5) decoupling'in gerekli olup olmadığını belirler.

---

## Scriptler

### K6 tek-eksen LQR/LQI (✅ tasarım/sim — donanımsız)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `design_lqr_lqi_singleaxis.m` | motor-2 modeli state-space [θ_out, ω_m]; **LQR** (Bryson Q/R + Riccati doğrulama, artık 2e-16); **LQI** (integral augment, sıfır ss-err); **cascade** (Aşama-2.5) ile aynı plant'ta step kıyası | `results/4_1_lqr_lqi/` (step PNG + JSON) | ✅ |

**Sonuç (0→30° step):** cascade t_s **1.98 s** vs LQR+Nbar **0.32 s** vs LQI **0.14 s** (hepsi duty
≤0.40 < 0.50 doyum). Tam-durum geri besleme cascade'i ~6× geçiyor — tezin §2.10'da **simüle ettiği
ama repoda olmayan** "LQG vs cascade" iddiasının gerçek, doğrulanabilir karşılığı.

> ⚠ **Lineer sim** (sürtünme/kuantizasyon/doyum-zorlaması yok). Gerçek cascade settling (~1.3-1.9 s,
> Test 2.5) bu sim ile uyumlu; LQR/LQI gerçek-donanım doğrulaması Aşama-4 bench'inde. LQR **tam durum**
> ister (θ encoder + ω_m encoder-hız — ikisi de mevcut); gözlemci gerekmez (Kalman/LQG = K7, Aşama 5).

### Planlı (Aşama 4 ilerledikçe)

| Script | Amaç | Durum |
|---|---|---|
| `design_decoupling.m` | RGA sonucuna göre decoupling ön-kompansatör (kuplaj varsa) | ⬜ (3.5 RGA kapısına bağlı) |
| `design_mimo_lqr.m` | 2×2 MIMO LQR (iki sağlam motor gelince) | ⬜ |

## Klasör
```
matlab/asama_4_mimo_kontrol/
├── README.md
├── design_lqr_lqi_singleaxis.m
└── results/4_1_lqr_lqi/   ← step PNG + params JSON
```

Kaynak: [Anderson2007] §2-3 (LQR/Riccati), [Franklin2010] §7.9/§9 (integral/durum-FB), Bryson kuralı.
