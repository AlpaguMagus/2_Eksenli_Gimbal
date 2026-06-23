# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 16:38 · **Commit:** `e7608b5` · **Durum:** LIMIT_CYCLE
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Coulomb FF:** KAPALI
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +26.93° | 3.07 | 0.0 | — | 0.15 | 🟢 OK |
| +90° | +89.36° | 0.64 | 9.38 | — | 10.16 | ⚠ LIMIT-CYCLE |
| +45° | +41.99° | 3.01 | 4.12 | — | 0.13 | 🟢 OK |
| +0° | +0.00° | 0.0 | 0.75 | 0.994s | 0.0 | 🟢 OK |
| -45° | -42.37° | 2.63 | 0.0 | — | 0.02 | 🟢 OK |
| +0° | +8.91° | 8.91 | 45.75 | — | 21.82 | ⚠ LIMIT-CYCLE |

## Durum: **LIMIT_CYCLE**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)