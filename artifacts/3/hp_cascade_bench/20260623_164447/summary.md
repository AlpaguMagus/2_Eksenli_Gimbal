# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 16:45 · **Commit:** `e7608b5` · **Durum:** LIMIT_CYCLE
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Coulomb FF:** AÇIK — kff_coul=0.14, coul_db=0.35 (analitik §12.12.4)
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +30.23° | 0.23 | 3.38 | — | 2.96 | ⚠ LIMIT-CYCLE |
| +90° | +89.43° | 0.57 | 6.38 | — | 5.71 | ⚠ LIMIT-CYCLE |
| +45° | +42.24° | 2.76 | 8.62 | — | 0.78 | 🟢 OK |
| +0° | +0.57° | 0.57 | 3.0 | — | 2.76 | ⚠ LIMIT-CYCLE |
| -45° | -41.79° | 3.21 | 0.0 | — | 0.39 | 🟢 OK |
| +0° | -2.24° | 2.24 | 3.0 | — | 1.82 | 🟢 OK |

## Durum: **LIMIT_CYCLE**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)