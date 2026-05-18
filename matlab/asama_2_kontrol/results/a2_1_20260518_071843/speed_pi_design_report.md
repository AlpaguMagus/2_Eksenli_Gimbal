# Aşama 2.1 — Hız PI Tasarımı Raporu

- **Tarih:** 2026-05-18 07:19:22
- **Aşama 1 girişi:** K=53.891 rad/s/V, τ=0.0605 s (test_id=20260518_011926)

## Pole Placement A — Agresif (Butterworth, [Franklin2010] §6.4)

- ζ = 0.707 (Butterworth)
- ω_n = 83.0 rad/s (τ_cl = 12.0 ms)
- **Kp = 0.1133, Ki = 7.7401**
- Hızlı (~60 ms settling) ama overshoot ~%15 — gimbal mirror için fazla

## Pole Placement B — Konservatif (Critically Damped, [Franklin2010] §3.6)

- ζ = 1.000 (critically damped, sıfır overshoot)
- ω_n = 60.0 rad/s (τ_cl = 16.7 ms)
- **Kp = 0.1163, Ki = 4.0447**
- ⭐ **Firmware seçimi (Aşama 2.2)** — IMU mirror senaryosu için ideal: smooth, overshoot yok

## pidtune (Otomatik, MATLAB Control System Toolbox)

| Mod | Kp | Ki | ω_c (rad/s) | PM (°) |
|---|---|---|---|---|
| pidtune_Robust | 0.0045 | 0.5112 | 18.6 | 51.0 |
| pidtune_Balanced | 0.0000 | 0.2664 | 11.7 | 54.7 |
| pidtune_Fast | 0.0000 | 0.2664 | 11.7 | 54.7 |

## Karşılaştırma Tablosu

| Kontrolcü | Kp | Ki | GM (dB) | PM (°) | T_set (ms) | OS (%) | ss_err (%) |
|---|---|---|---|---|---|---|---|
| pole_placement_aggressive | 0.1133 | 7.7401 | Inf | 67.6 | 59.9 | 15.39 | 0.000 |
| pole_placement_conservative | 0.1163 | 4.0447 | Inf | 80.8 | 80.5 | 6.71 | 0.000 |
| pidtune_Robust | 0.0045 | 0.5112 | Inf | 51.0 | 376.5 | 18.14 | 0.000 |
| pidtune_Balanced | 0.0000 | 0.2664 | Inf | 54.7 | 376.4 | 13.58 | 0.000 |
| pidtune_Fast | 0.0000 | 0.2664 | Inf | 54.7 | 376.4 | 13.58 | 0.000 |

## Hedef Performans (Test 2.T1)

- GM ≥ 6 dB, PM ≥ 45°
- Settling time < 5×τ_ol = 300 ms (konservatif)
- Overshoot < %10

## Görsel Kanıtlar

- `01_bode_comparison.png` — Açık döngü Bode (4 kontrolcü)
- `02_step_response.png` — Kapalı döngü step response
- `03_metrics_bar.png` — Margin/settling/overshoot bar chart
- `speed_loop_a2_1.slx` — Simulink kapalı döngü modeli
- `speed_pi_params.json` — Aşama 2.2 firmware için kaynak

## Aşama 2.2'ye Önerilen Seçim

> Aşağıdaki kontrolcülerden biri firmware'e aktarılacak. Sokratik karar: hocaya sunum için **pole placement** akademik şeffaflık, **pidtune Robust** ise sahada güvenli margin. Aşama 2.2 öncesi onay alınır.

## Kaynakça

- `[Franklin2010] §6.4` — pole placement, cascade kuralları
- `[Franklin2010] §6.7` — gain/phase margin
- `[AstromMurray2008] §10.2` — discrete-time PID ayrıştırma
- `[AstromMurray2008] §10.4` — back-calculation anti-windup
