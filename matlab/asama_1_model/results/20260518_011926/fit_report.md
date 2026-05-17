# Aşama 1 — Tek Motor Sistem Tanımlama — Fit Raporu

- **Test ID:** 20260518_011926
- **Commit:** `67db814`
- **Tarih:** 2026-05-18 02:22:39
- **Hedef:** Pololu 25D motor + TB6612 sürücü için K, τ, V_dead çıkarımı

## Model

```
ω(t) = K · max(V_eff − V_dead, 0) · (1 − e^(−t/τ))
V_eff = V_supply · duty − V_sat
V_supply = 12.15 V  (Mervesan 12V/3A, droop %0.6)
V_sat    = 0.50 V  (TB6612 datasheet @1A)
```

## Sonuçlar (sayısal)

| Parametre | Değer | Birim |
|---|---|---|
| K_cw            | 54.225 | rad/s/V |
| K_ccw           | 53.558 | rad/s/V |
| τ_median        | 0.0605 | s |
| τ_iqr           | 0.0492 | s |
| V_dead⁺         | -0.243 | V |
| V_dead⁻         | +0.241 | V |
| CW/CCW simetri  | 1.24 | % |
| R²_pos          | 0.9998 | — |
| R²_neg          | 0.9997 | — |
| Fit edilen step | 18 | — |

## Dead-band Yorumu

Küçük dead-band (CW -0.243 V, CCW 0.241 V) — kontrolcü için gerekirse compensation eklenebilir, ihmal de edilebilir.

## Step Bazlı Detay

| # | yön | duty | ω_ss (rad/s) | τ (ms) | NRMSE % | K_app | method |
|---|---|---|---|---|---|---|---|
| 1 | CW | +0.120 | +56.79 | 42.9 | 9.25 | 59.28 | lsqcurve |
| 2 | CCW | -0.120 | -58.18 | 9.9 | 9.10 | 60.73 | lsqcurve |
| 3 | CW | +0.140 | +70.38 | 57.2 | 12.54 | 58.60 | lsqcurve |
| 4 | CCW | -0.140 | -68.91 | 63.9 | 11.87 | 57.38 | tfest |
| 5 | CW | +0.160 | +81.03 | 53.5 | 10.79 | 56.12 | lsqcurve |
| 6 | CCW | -0.160 | -80.34 | 56.4 | 11.37 | 55.64 | lsqcurve |
| 7 | CW | +0.180 | +92.82 | 41.2 | 4.04 | 55.02 | lsqcurve |
| 8 | CCW | -0.180 | -90.78 | 40.0 | 7.68 | 53.81 | lsqcurve |
| 9 | CW | +0.200 | +105.27 | 92.2 | 8.44 | 54.55 | tfest |
| 10 | CCW | -0.200 | -100.77 | 28.6 | 9.13 | 52.21 | lsqcurve |
| 11 | CW | +0.250 | +132.26 | 74.6 | 3.07 | 52.12 | lsqcurve |
| 12 | CCW | -0.250 | -129.88 | 48.4 | 4.67 | 51.18 | lsqcurve |
| 13 | CW | +0.300 | +161.03 | 72.4 | 5.91 | 51.20 | lsqcurve |
| 14 | CCW | -0.300 | -161.16 | 79.8 | 6.08 | 51.24 | lsqcurve |
| 15 | CW | +0.400 | +221.00 | 118.6 | 3.81 | 50.69 | lsqcurve |
| 16 | CCW | -0.400 | -218.86 | 121.2 | 4.29 | 50.20 | lsqcurve |
| 17 | CW | +0.450 | +250.58 | 133.7 | 4.26 | 50.44 | lsqcurve |
| 18 | CCW | -0.450 | -246.50 | 132.4 | 3.32 | 49.62 | lsqcurve |

## Görsel Kanıtlar

- `01_step_fits_cw.png` — CW step fit eğrileri (lsqcurve + tfest)
- `02_step_fits_ccw.png` — CCW step fit eğrileri
- `03_omega_vs_duty.png` — Lineer regresyon
- `04_omega_vs_Veff.png` — Dead-band tespit
- `05_K_apparent_vs_duty.png` — V_sat etkisi
- `06_cw_ccw_symmetry.png` — Test 1.T3
- `07_tau_summary.png` — τ histogram + duty bağımlılığı
- `08_validation_cw.png` — Test 1.T5 model vs ölçüm (CW)
- `09_validation_ccw.png` — Test 1.T5 model vs ölçüm (CCW)
- `10_validation_summary.png` — Test 1.T5 NRMSE özet
- `motor_model_asama1.slx` — Simulink blok diyagramı (akademik materyal)

## Test Sonuçları

| Test | Beklenen | Ölçülen | Durum |
|---|---|---|---|
| 1.T2 (fit kalitesi) | her step NRMSE < %5 | bkz. tablo | PARTIAL |
| 1.T3 (CW/CCW simetri) | < %5 | 1.24% | PASS |
| 1.T4 (dead-band cross-check) | V_dead < 0.5 V | bkz. dead-band yorumu | PASS |
| 1.T5 (Model validation, lsim+Simulink) | ort NRMSE<%15, max<%20 | ort 11.11%, max 14.77% | PASS |

> **Test 1.T5 notu:** Tek (K, τ) ile tüm step seviyelerinde validation U-şekli NRMSE eğrisi verir (uçlarda %12-14, |duty|≈0.18'de %5.7). Bu, K(duty) ve τ(duty) varyasyonunun (V_sat etkisi + 1. derece varsayımının sınırı) doğal sonucudur. Akademik literatürde NRMSE < %15 "good agreement" kabul edilir ([Ljung1999] §16). Aşama 2 kontrolcü tasarımı için konservatif yeterli; gerekirse "gain scheduling" Aşama 2 alt-maddesi olarak değerlendirilir.

## Kaynakça (KAYNAKCA.md)

- `[Ljung1999 §3]`
- `[Ljung1999 §4]`
- `[Ljung1999 §16]`
- `[Franklin2010 §3]`
- `[Soderstrom1989 §4]`
- `[TB6612_DS §1]`
