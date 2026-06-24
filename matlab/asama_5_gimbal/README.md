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

### Y0 yüklü plant rigorous-ID (✅ tasarım + estimator-doğrulama — donanımsız)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `loaded_plant_id_design.m` | Yüklü nonlineer plant (yerçekimi-yüklü sarkaç + yön-asimetrik sürtünme) ID **protokolü + ayrıştırma matematiği**; gravite↔sürtünme↔atalet TEMİZ ayrıştırma; **sentetik veride estimator doğrulama** (bilinen param → fit → geri-kurtar) | `results/loaded_plant_id/` (PNG) | ✅ estimator PASS |
| `loaded_plant_id_fit.m` | **Y0 gerçek bench fit** — `loaded_plant_id_capture.py` B1+B3 ham verisinden plant parametrelerini çıkarır (params.json + fit_report.md üretir) | `results/loaded_plant_id/` (PNG + JSON + MD) | ✅ ilk koşum (FIRST_CUT) |

**Yöntem (B Yolu — `docs/asama_5 §12.5.5/§12.5.7`):** plant $J\ddot\theta+b\dot\theta+\tau_c\,\mathrm{sign}(\dot\theta)+mgL\sin\theta=K_m u$ (θ = dip'ten).
**B1** çok-açılı kopma → midpoint vs $\sin\theta$ LİNEER fit → **a (gravite), s+, s− (yön-asimetrik statik sürtünme) TEMİZ AYRILIR** (tek-açı ID karıştırıyordu). **B2** $\omega_n,\zeta$ pasif **free-decay** ring-down (yüklü sürülen-step Coulomb yüzünden osile ETMEZ). **Validasyon** NRMSE (held-out).

**Sentetik doğrulama (estimator PASS, bench'ten ÖNCE):** a −0.8%, s+ %0, s− +0.9% (R²=0.9998), $\omega_n$ +0.3%, NRMSE 5.94% (<15%). ⚠ ζ Coulomb-coast ile şişer (log-decrement → efektif üst-sınır, saf-viskoz değil).

**Y0 gerçek bench fit (✅ ilk koşum, test 20260624_085025, FIRST_CUT):** a (gravite, duty) **0.23** (SOLID — 3-yol çapraz-doğrulama), s+ **0.059** / s− **0.027** (yön solid, magnitüd tahmini), asimetri s+/s− **2.16**, B1 fit R² **0.963**, $\omega_n\approx 4$ rad/s (PRIOR — bu oturum free-decay ring-down yapmadı, yüksek stiction salınamadı), ζ belirsiz. ⚠ Sürtünme eski tek-açı ID'de FAZLA tahmin edilmişti (0.09/0.05) — çok-açılı ayrıştırma graviteyi sürtünmeden ayırdı → gerçek (düşük) 0.06/0.03 mertebesi.

> 📊 **Üreten betikler:** `matlab/asama_5_gimbal/loaded_plant_id_design.m` (estimator doğrulama), `matlab/asama_5_gimbal/loaded_plant_id_fit.m` (Y0 gerçek fit).
> **Bench veri:** `scripts/loaded_plant_id_capture.py` (B1 üçgen-rampa + B3) + `scripts/loaded_pendulum_id.py` (B2 free-decay).

### Y1 yüklü kontrol tasarımı (✅ ön-tasarım — bench re-tune açık)

| Script | Amaç | Çıktı | Durum |
|---|---|---|---|
| `loaded_control_design.m` | Y0 gerçek plant parametrelerinden (a=0.23, s±) yüklü gimbal kontrol tasarımı — FF gainleri + cascade re-tune | `results/loaded_plant_id/loaded_closedloop_y1.png` | ✅ tasarım (bench re-tune açık-iş) |

### Planlı (Aşama 5)

> **Y0 bench-capture → gerçek plant fit ✅ tamam** (test 20260624_085025, FIRST_CUT): a=0.23, s+=0.059,
> s−=0.027, asimetri 2.16, R²=0.963, $\omega_n\approx 4$ PRIOR. Çıktı: `loaded_plant_id_fit.m` →
> `results/loaded_plant_id/` (params.json + fit_report.md + PNG). Açık-iş: sürtünme magnitüd precision +
> fresh $\omega_n/\zeta$.

| İş | Durum |
|---|---|
| LQG entegrasyon (Kalman ⊕ LQR), bozucu-reddi sim | ⬜ |
| EKF (tam quaternion attitude, ±90° singülarite) | ⬜ ([Madgwick2010] alternatif) |
| Gerçek gimbal: IMU payload'a → tam eylemsiz STAB + gyro-FF doğrulama | ⬜ (donanım) |

## Klasör
```
matlab/asama_5_gimbal/
├── README.md
├── design_kalman_attitude.m        ← K7 attitude Kalman (sim)
├── loaded_plant_id_design.m        ← Y0 yüklü plant ID protokol + estimator doğrulama
├── loaded_plant_id_fit.m           ← Y0 gerçek bench fit (params.json + fit_report.md)
├── loaded_control_design.m         ← Y1 yüklü kontrol tasarımı (FF + cascade re-tune)
└── results/
    ├── 5_1_kalman/                  ← attitude PNG + params JSON
    └── loaded_plant_id/             ← Y0 ID çıktıları:
        ├── estimator_synthetic_verify.png   (sentetik estimator PASS)
        ├── real_fit_085025.png              (B1 histerezis gerçek fit)
        ├── loaded_motor_params.json         (fit parametreleri)
        ├── loaded_fit_report.md             (fit raporu)
        └── loaded_closedloop_y1.png         (Y1 kapalı-çevrim tasarım)
```

Kaynak: [Simon2006] Ch.5,7 (Kalman), [Higgins1975] (complementary↔Kalman), [IEEE952] Allan,
[Ljung1999] §3-4-16 (ID+validasyon), [Olsson1998] §6 (sürtünme ayrıştırma), [Khalil2002] §1 (sarkaç).
