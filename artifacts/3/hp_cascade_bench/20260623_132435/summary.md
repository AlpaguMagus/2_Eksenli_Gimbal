# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 13:25 · **Commit:** `767fb66` · **Durum:** LIMIT_CYCLE
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Coulomb FF:** KAPALI
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | -22.79° | 52.79 | 57.75 | — | 59.99 | ⚠ LIMIT-CYCLE |
| +90° | +36.87° | 53.13 | 50.62 | — | 60.6 | ⚠ LIMIT-CYCLE |
| +45° | -15.51° | 60.51 | 61.12 | — | 60.56 | ⚠ LIMIT-CYCLE |
| +0° | -57.41° | 57.41 | 56.62 | — | 61.21 | ⚠ LIMIT-CYCLE |
| -45° | -101.88° | 56.88 | 68.25 | — | 63.93 | ⚠ LIMIT-CYCLE |
| +0° | -47.24° | 47.24 | 43.5 | — | 54.88 | ⚠ LIMIT-CYCLE |

## Durum: **LIMIT_CYCLE**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)