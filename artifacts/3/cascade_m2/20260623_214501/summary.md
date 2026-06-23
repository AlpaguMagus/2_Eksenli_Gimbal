# Aşama 3.3 — Eksen-2 Cascade Pozisyon Step

- **Test ID:** 20260623_214501
- **Tarih:** 2026-06-23 21:45
- **Commit:** `f2ce0b4`
- **Eksen:** motor-2 ('2' sonekli komutlar)
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [30.0, 90.0, 45.0, 0.0, -45.0, 0.0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/motor_cascade_test.py --motor 2 --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Mekanik+yük → ROADMAP §5 yeniden-ID.

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +30.13° | 0.13 | 0.13 | 1.612s | 0.0 | 🟢 OK |
| +90° | +89.20° | 0.8 | 0.0 | 1.631s | 0.42 | 🟢 OK |
| +45° | +45.22° | 0.22 | 0.19 | 1.439s | 0.39 | 🟢 OK |
| +0° | +0.54° | 0.54 | 0.0 | 1.608s | 0.57 | 🟢 OK |
| -45° | -44.98° | 0.02 | 1.35 | 1.663s | 1.21 | 🟢 OK |
| +0° | -0.04° | 0.04 | 0.0 | 1.511s | 0.16 | 🟢 OK |

## Durum: **PASS**

## Hedef
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC×360/466 (çıkış mili, 0.773°/count). instance-based g_axis firmware.

## Artifacts
- `data.csv.gz`
- `cascade_plot.png` (θ takip + ω_ref/ω + u)
