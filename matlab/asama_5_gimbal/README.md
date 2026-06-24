# Aşama 5 — Gerçek Gimbal + LQG/Kalman MATLAB

> **Rol:** Kontrol Yöntemleri Merdiveni'nin **K7** basamağı (ROADMAP) + gerçek 3D-baskı gimbal.
> Kestirim izi (complementary → Mahony/Madgwick → **EKF/Kalman**) ve LQG (LQR ⊕ Kalman) burada
> olgunlaşır; IMU payload'a taşınınca tam eylemsiz stabilizasyon + gyro-FF doğrulaması.

---

## Scriptler

### K7 attitude Kalman (✅ tasarım/sim — donanımsız)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `design_kalman_attitude.m` | 2-durum [θ, b_gyro] **bias-augmented** Kalman; Q/R **Allan variance'tan** (ARW 1.09°/√hr, accel σ=2°); steady-state kazanç (predict-form DARE); **complementary (α=0.98) ile sim kıyası** | `results/5_1_kalman/` (PNG + JSON) | ✅ |

**Sonuç:** Kalman gyro bias'ını (1.5→2.5 °/s drift) **birebir kestirip** kaldırır → açı RMS
**0.198° vs complementary 0.560° (2.8× iyi)**, özellikle titreşim (8–16 s) altında. Steady-state
Kθ=0.0071 → **α≈0.993 denkliği** (firmware complementary α=0.98 ile mertebe-uyumlu, [Higgins1975]).

> ⚠ Complementary filtre SABİT kazançlı + bias'ı ayrı kestirmez (bias sızar). Kalman bias'ı AÇIK
> durum yapar → gyro'ya güvenip (smooth) bias'ı kaldırır. **LQG = bu Kalman ⊕ Aşama-4 LQR** (K7).
> q_b (bias process noise) Allan alt-sınırından büyütüldü (gözlenen termal drift takibi — tasarım seçimi).

### Planlı (Aşama 5)

| İş | Durum |
|---|---|
| LQG entegrasyon (Kalman ⊕ LQR), bozucu-reddi sim | ⬜ |
| EKF (tam quaternion attitude, ±90° singülarite) | ⬜ ([Madgwick2010] alternatif) |
| Gerçek gimbal: IMU payload'a → tam eylemsiz STAB + gyro-FF doğrulama | ⬜ (donanım) |

## Klasör
```
matlab/asama_5_gimbal/
├── README.md
├── design_kalman_attitude.m
└── results/5_1_kalman/   ← attitude PNG + params JSON
```

Kaynak: [Simon2006] Ch.5,7 (Kalman + bias-augmented), [Higgins1975] (complementary↔Kalman), [IEEE952] Allan.
