# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 12:53 · **Commit:** `80f0606` · **Durum:** DROPOUT
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +33.00° | 3.0 | 3.75 | — | 0.0 | 🟢 OK |
| +90° | +99.00° | 9.0 | 10.12 | — | 0.0 | ⚠ FROZEN |
| +45° | +60.00° | 15.0 | 0.0 | — | 0.0 | ⚠ FROZEN |
| +0° | -13.03° | 13.03 | 13.12 | — | 0.31 | ⚠ FROZEN |
| -45° | -37.77° | 7.23 | 5.62 | — | 17.66 | ⚠ LIMIT-CYCLE |
| +0° | +15.38° | 15.38 | 16.12 | — | 0.0 | ⚠ FROZEN |

## Durum: **DROPOUT**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)