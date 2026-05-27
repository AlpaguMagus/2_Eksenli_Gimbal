# Aşama 1 — Tek Motor Sistem Tanımlama — Fit Raporu

- **Test ID:** 20260518_dogrulama
- **Commit:** `a065ec2`
- **Tarih:** 2026-05-24 16:27:35
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
| K_cw            | 54.535 | rad/s/V |
| K_ccw           | 53.982 | rad/s/V |
| τ_median        | 0.0774 | s |
| τ_iqr           | 0.0399 | s |
| V_dead⁺         | -0.242 | V |
| V_dead⁻         | +0.248 | V |
| CW/CCW simetri  | 1.02 | % |
| R²_pos          | 0.9998 | — |
| R²_neg          | 0.9998 | — |
| Fit edilen step | 18 | — |

## Dead-band Yorumu

Küçük dead-band (CW -0.242 V, CCW 0.248 V) — kontrolcü için gerekirse compensation eklenebilir, ihmal de edilebilir.

## Step Bazlı Detay

| # | yön | duty | ω_ss (rad/s) | τ (ms) | NRMSE % | K_app | method |
|---|---|---|---|---|---|---|---|
| 1 | CW | +0.120 | +58.52 | 30.4 | 11.12 | 61.09 | lsqcurve |
| 2 | CCW | -0.120 | -58.14 | 58.5 | 9.41 | 60.69 | lsqcurve |
| 3 | CW | +0.140 | +69.95 | 25.8 | 11.25 | 58.24 | lsqcurve |
| 4 | CCW | -0.140 | -68.57 | 72.1 | 11.77 | 57.09 | tfest |
| 5 | CW | +0.160 | +81.60 | 85.6 | 9.96 | 56.51 | tfest |
| 6 | CCW | -0.160 | -80.58 | 106.1 | 9.56 | 55.80 | tfest |
| 7 | CW | +0.180 | +91.77 | 30.8 | 5.01 | 54.40 | lsqcurve |
| 8 | CCW | -0.180 | -91.77 | 66.5 | 6.58 | 54.40 | lsqcurve |
| 9 | CW | +0.200 | +105.40 | 101.8 | 8.64 | 54.61 | tfest |
| 10 | CCW | -0.200 | -105.40 | 80.4 | 8.82 | 54.61 | lsqcurve |
| 11 | CW | +0.250 | +133.32 | 66.2 | 4.52 | 52.54 | lsqcurve |
| 12 | CCW | -0.250 | -131.25 | 70.0 | 3.21 | 51.72 | lsqcurve |
| 13 | CW | +0.300 | +162.52 | 74.4 | 5.43 | 51.68 | lsqcurve |
| 14 | CCW | -0.300 | -160.48 | 86.1 | 5.76 | 51.03 | lsqcurve |
| 15 | CW | +0.400 | +223.36 | 111.7 | 2.95 | 51.23 | lsqcurve |
| 16 | CCW | -0.400 | -219.64 | 108.2 | 4.20 | 50.38 | lsqcurve |
| 17 | CW | +0.450 | +250.92 | 128.5 | 4.00 | 50.51 | lsqcurve |
| 18 | CCW | -0.450 | -248.99 | 118.7 | 3.57 | 50.12 | lsqcurve |

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
| 1.T3 (CW/CCW simetri) | < %5 | 1.02% | PASS |
| 1.T4 (dead-band cross-check) | V_dead < 0.5 V | bkz. dead-band yorumu | PASS |
| 1.T5 (Model validation, lsim+Simulink) | ort NRMSE<%15, max<%20 | ort 10.36%, max 16.81% | PASS |

> **Test 1.T5 notu:** Tek (K, τ) ile tüm step seviyelerinde validation U-şekli NRMSE eğrisi verir (uçlarda %12-14, |duty|≈0.18'de %5.7). Bu, K(duty) ve τ(duty) varyasyonunun (V_sat etkisi + 1. derece varsayımının sınırı) doğal sonucudur. Akademik literatürde NRMSE < %15 "good agreement" kabul edilir ([Ljung1999] §16). Aşama 2 kontrolcü tasarımı için konservatif yeterli; gerekirse "gain scheduling" Aşama 2 alt-maddesi olarak değerlendirilir.

## Kaynakça (KAYNAKCA.md)

- `[Ljung1999 §3]`
- `[Ljung1999 §4]`
- `[Ljung1999 §16]`
- `[Franklin2010 §3]`
- `[Soderstrom1989 §4]`
- `[TB6612_DS §1]`
