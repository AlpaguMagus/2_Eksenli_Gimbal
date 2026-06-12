# Aşama 3.3 — Eksen-2 Cascade Pozisyon Step

- **Test ID:** 20260612_115042
- **Tarih:** 2026-06-12 11:51
- **Commit:** `9d1a32c`
- **Eksen:** motor-2 ('2' sonekli komutlar)
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/motor_cascade_test.py --motor 2 --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Mekanik+yük → ROADMAP §5 yeniden-ID.

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +30.04° | 0.04 | 0.13 | 1.169s | 0.25 | 🟢 OK |
| +90° | +90.39° | 0.39 | 0.39 | 1.87s | 0.0 | 🟢 OK |
| +45° | +44.03° | 0.97 | 0.97 | 1.698s | 0.0 | 🟢 OK |
| +0° | +0.00° | 0.0 | 0.0 | 1.64s | 0.0 | 🟢 OK |
| -45° | -44.81° | 0.19 | 0.0 | 1.274s | 0.0 | 🟢 OK |
| +0° | +0.00° | 0.0 | 0.0 | 1.388s | 0.0 | 🟢 OK |

## Durum: **PASS**

## Hedef
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC×360/466 (çıkış mili, 0.773°/count). instance-based g_axis firmware.

## Artifacts
- `data.csv`
- `cascade_plot.png` (θ takip + ω_ref/ω + u)
