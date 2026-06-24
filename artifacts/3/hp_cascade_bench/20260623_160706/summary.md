# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)

- **Test ID:** HP-cascade-bench · **Tarih:** 2026-06-23 16:07 · **Commit:** `00e8c57` · **Durum:** NO_REACH
- **Mimari:** cascade — poz P Kp_pos=2.0 → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)
- **Coulomb FF:** KAPALI
- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap
- **Hedefler:** [30.0, 0.0] (mutlak çıkış mili açısı °) · mil serbest

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +26.82° | 3.18 | 0.0 | — | 0.19 | 🟢 OK |
| +0° | +2.50° | 2.5 | 0.0 | — | 0.19 | 🟢 OK |

## Durum: **NO_REACH**

## Hedef (Faz 3 PASS)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK
- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)

## Artifacts
- raw/data.csv
- hp_cascade_plot.png (θ takip + ω_ref/ω + u)