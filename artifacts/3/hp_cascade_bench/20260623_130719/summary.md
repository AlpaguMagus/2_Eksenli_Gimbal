# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 13:07 · **Commit:** `80f0606` · **Durum:** STICK_SLIP
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Coulomb FF:** AÇIK — kff_coul=0.14, coul_db=0.35 (analitik §12.12.4)
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +37.00° | 7.0 | 26.62 | — | 20.51 | ⚠ LIMIT-CYCLE |
| +90° | +101.60° | 11.6 | 12.75 | — | 0.09 | ⚠ STICK-SLIP |
| +45° | +59.57° | 14.57 | 21.38 | — | 0.31 | 🟢 OK |
| +0° | -9.20° | 9.2 | 35.62 | — | 0.31 | ⚠ STICK-SLIP |
| -45° | -42.21° | 2.79 | 2.62 | — | 0.19 | 🟢 OK |
| +0° | +11.64° | 11.64 | 15.38 | — | 0.34 | ⚠ STICK-SLIP |

## Durum: **STICK_SLIP**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)