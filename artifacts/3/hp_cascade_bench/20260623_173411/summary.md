# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 17:34 · **Commit:** `698808f` · **Durum:** LIMIT_CYCLE
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Coulomb FF:** AÇIK — kff_coul=0.14, coul_db=0.35 (analitik §12.12.4)
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +22.13° | 7.87 | 6.0 | — | 6.67 | ⚠ LIMIT-CYCLE |
| +90° | +91.76° | 1.76 | 9.0 | — | 8.66 | ⚠ LIMIT-CYCLE |
| +45° | +38.83° | 6.17 | 7.88 | — | 0.37 | 🟢 OK |
| +0° | -5.70° | 5.7 | 6.75 | 3.995s | 1.38 | 🟢 OK |
| -45° | -48.01° | 3.01 | 8.25 | — | 0.07 | 🟢 OK |
| +0° | -9.02° | 9.02 | 1.88 | — | 5.29 | ⚠ LIMIT-CYCLE |

## Durum: **LIMIT_CYCLE**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)