# Aşama 3.3 — Eksen-2 Cascade Pozisyon Step

- **Test ID:** 20260623_203919
- **Tarih:** 2026-06-23 20:39
- **Commit:** `fca5ec1`
- **Eksen:** motor-2 ('2' sonekli komutlar)
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [30.0, 90.0, 45.0, 0.0, -45.0, 0.0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/motor_cascade_test.py --motor 2 --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Mekanik+yük → ROADMAP §5 yeniden-ID.

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +30.90° | 0.9 | 0.9 | 1.606s | 0.0 | 🟢 OK |
| +90° | +89.17° | 0.83 | 0.0 | 1.623s | 0.55 | 🟢 OK |
| +45° | +45.07° | 0.07 | 0.19 | 1.591s | 0.37 | 🟢 OK |
| +0° | +0.74° | 0.74 | 0.0 | 1.448s | 0.3 | 🟢 OK |
| -45° | -45.47° | 0.47 | 1.35 | 1.504s | 1.05 | 🟢 OK |
| +0° | +0.00° | 0.0 | 0.0 | 1.615s | 0.0 | 🟢 OK |

## Durum: **PASS**

## Hedef
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC×360/466 (çıkış mili, 0.773°/count). instance-based g_axis firmware.

## Artifacts
- `data.csv.gz`
- `cascade_plot.png` (θ takip + ω_ref/ω + u)
