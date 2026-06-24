# HP step-ID karakterizasyonu — eksen-0 (HW-039/BTS7960, 20 kHz, 20:1)

- **Test ID:** hp_stepid_20260615_021942
- **Tarih:** 2026-06-15 02:19
- **Commit:** `f4267bf`
- **Hedef:** HP plant kimliği (Kg, K, τ, V_dead) — firmware LP paramıyla sürüyordu (cascade YANLIŞ)
- **Komut:** `python3 scripts/hp_stepid_test.py`
- **Koşul:** serbest mil (kullanıcı tutuyor), kalkış-kick'li, ω = EC(48 CPR motor) eğimi

## Sonuç (sayısal)
| Metric | HP | LP (Aşama-1) | Durum |
|---|---|---|---|
| Kg [rad/s/duty] | 1012.7 | 654.8 | ✓ |
| K [rad/s/V] | 83.35 | 53.89 | — |
| τ [ms] | ~~514.9 (otomatik, BOZUK)~~ → **235 ön-değer (geri yön)** | ~60.5 | ⚠ şüpheli |
| V_dead [duty] | 0.019 | ~0 | — |
| fit R² | 0.987 | — | ✓ |
| Kg_geri/Kg_ileri | 1.067 | (CW/CCW ~%1) | — |

## Kararlı-hal (duty → ω_ss motor rad/s)
| duty | ω_ss |
|---|---|
| +0.15 | 0.0 |
| +0.20 | -0.0 |
| +0.25 | 0.0 |
| +0.30 | 287.5 |
| +0.35 | 0.0 |
| +0.40 | 375.1 |
| +0.45 | 442.8 |
| +0.50 | 4.9 |
| -0.25 | -222.2 |
| -0.35 | -338.2 |
| -0.50 | -493.3 |

## Durum: **PARTIAL** (K sağlam; τ + forward eksik)

> ⚠ **Düzeltme (manuel, 2026-06-15):** (1) **K_HP SAĞLAM** — R²=0.987, forward 0.30/0.40/0.45 + reverse;
> LP'nin 1.55×'i (no-load 1.65× ile uyumlu). (2) **τ otomatik 514ms BOZUK** (Test B forward 0.50 dropout'una
> denk geldi); geri yönde 3/3 tekrar **~235ms** ama ω0 tutarsızlığı var → **şüpheli, MATLAB cross-check gerek.**
> (3) **FORWARD dropout (0.35/0.50 = 0)** devam ediyor — geri yön (CCW=LPWM) TEMİZ, ileri (CW=RPWM=PB8)
> flaky → **RPWM (PB8) bağlantısı marjinal** hipotezi. **Temiz tam karakterizasyon (τ + forward) RPWM fix sonrası.**

## Not
ω motor-şaftı (EC 48 CPR, redüktör-bağımsız). HP/LP K oranı ≈ 1.55 (no-load hız oranı ~1.65 ile uyumlu).
Ölü-bölge KİNETİK (kick sonrası); STARTING stiction ~0.30 duty (ayrı, dead-band telafisi gerek).
MATLAB fit + plot: matlab/asama_3_mimo_model/ (Aşama-1 disipliniyle).
