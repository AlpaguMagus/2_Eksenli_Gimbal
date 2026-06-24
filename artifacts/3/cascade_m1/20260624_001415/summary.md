# Aşama 3.3 — Eksen-1 Cascade Pozisyon Step

- **Test ID:** 20260624_001415
- **Tarih:** 2026-06-24 00:14
- **Commit:** `b7eec66`
- **Eksen:** motor-1 (base komutlar)
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [30.0, -30.0, 0.0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/motor_cascade_test.py --motor 1 --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Mekanik+yük → ROADMAP §5 yeniden-ID.

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +63.36° | 33.36 | 52.66 | — | 14.56 | ⚠ LIMIT-CYCLE |
| -30° | -65.35° | 35.35 | 40.3 | — | 6.98 | ⚠ LIMIT-CYCLE |
| +0° | +0.00° | 0.0 | 3.09 | 0.779s | 0.0 | 🟢 OK |

## Durum: **LIMIT_CYCLE**

## Hedef
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC×360/466 (çıkış mili, 0.773°/count). instance-based g_axis firmware.

## Artifacts
- `data.csv.gz`
- `cascade_plot.png` (θ takip + ω_ref/ω + u)
