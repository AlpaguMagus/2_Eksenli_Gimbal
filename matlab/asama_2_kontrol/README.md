# Aşama 2 — Tek Motor Kontrol (PI / PID / Cascade)

> **Amaç:** Aşama 1'de çıkarılan motor modeliyle (K=53.89 rad/s/V, τ=60.5 ms)
> hız iç döngü PI + pozisyon dış döngü P kontrolcülerini tasarla, firmware'e aktar,
> IMU mirror demosunu çalıştır.

---

## Plan ve Kaynak

| Adım | Yöntem | Kaynak |
|---|---|---|
| 2.1 Hız PI tasarımı | Pole placement + `pidtune` karşılaştırma | `[Franklin2010] §6.4`, MATLAB Control System Toolbox |
| 2.2 Firmware hız PI | Bilinear (Tustin) ayrıştırma, Ts=5 ms | `[AstromMurray2008] §10.2` |
| 2.3 Anti-windup | Back-calculation, T_b = T_i | `[AstromMurray2008] §10.4` |
| 2.5 Pozisyon kontrolcü | Cascade, iç döngünün 1/5 hızında | `[Franklin2010] §6.4` |
| 2.7 IMU mirror | Setpoint = +fused_pitch | proje konsepti |

## Klasör Yapısı

```
matlab/asama_2_kontrol/
├── README.md                          ← Bu dosya
├── load_motor_params.m                 ← Aşama 1 JSON yükleyici
├── design_speed_pi_pole_placement.m    ← Adım 2.1 — analitik tasarım
├── design_speed_pi_autotune.m          ← Adım 2.1 — pidtune yöntemi
├── compare_speed_pi.m                  ← Adım 2.1 — Bode + step + margins
├── design_position_p.m                 ← Adım 2.5 — dış döngü
├── create_speed_loop_simulink.m         ← Simulink kapalı döngü (programatik)
├── create_cascade_simulink.m            ← Simulink cascade (programatik)
├── run_pipeline_2_1.m                   ← Adım 2.1 orchestrator
└── results/<test_id>/                   ← Çıktılar (PNG, JSON, MD, .slx)
```

## Pipeline Akışı (Adım 2.1)

1. `load_motor_params.m` — `motor_params.json`'dan K, τ oku
2. `design_speed_pi_pole_placement.m` — ζ=0.707, ω_n=83 rad/s → Kp, Ki (analitik)
3. `design_speed_pi_autotune.m` — `pidtune` 3 mod (Robust, Balanced, Fast)
4. `compare_speed_pi.m` — her 4 kontrolcü için Bode, step, margins → PNG
5. `create_speed_loop_simulink.m` — programatik `speed_loop_a2_1.slx`
6. JSON parametre kaydı + Markdown raporu

## Firmware'e Transfer (Adım 2.2)

Pipeline çıktısı `speed_pi_params.json` Aşama 2.2'de okunur, manuel transfer:

```c
/* Hız PI kazançları — matlab/asama_2_kontrol/.../design_speed_pi_pole_placement.m §2'den:
 *   Pole placement: ζ=0.707, ω_n=83 rad/s, K=53.89, τ=0.0605 s
 *   Kp = (2·ζ·ω_n·τ − 1) / K
 *   Ki = ω_n²·τ / K
 * Kaynak: [Franklin2010] §6.4 */
const float SPEED_PI_KP = 0.42f;   // değer 2.1 pipeline çıktısından
const float SPEED_PI_KI = 12.3f;
const float SPEED_PI_TS = 0.005f;  // 200 Hz fixed sample
```

## Test Akışı (Adım 2.3 sonrası)

```bash
# Firmware flash (yeni speed_pi.c eklendikten sonra)
pio run -t upload

# Python step response testi (2.3)
python3 scripts/speed_step_test.py

# Artifact:
# artifacts/2/speed_step/<test_id>/raw/data.csv.gz + summary.md + meta.json
```

## Akademik Çıktı Hedefi

Aşama 2 sonunda:
- `results/<test_id>/` — Bode plots (4 kontrolcü), step responses, margin tablosu,
  Simulink modelleri, JSON parametreler, Markdown rapor
- README §11 — Aşama 2 el kitapçığı bölümü (sokratik kararlar + sayısal sonuçlar
  + görsel kanıtlar + akademik tartışma)
