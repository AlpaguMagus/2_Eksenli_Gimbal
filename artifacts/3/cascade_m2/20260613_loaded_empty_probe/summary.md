# Aşama 3.3 — Eksen-2 Cascade Pozisyon Step

- **Test ID:** 20260613_loaded_empty_probe
- **Tarih:** 2026-06-13 04:45
- **Commit:** `2bf0b08`
- **Eksen:** motor-2 ('2' sonekli komutlar)
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [20.0, 35.0, 50.0, 0.0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/motor_cascade_test.py --motor 2 --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Mekanik+yük → ROADMAP §5 yeniden-ID.

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +20° | +14.89° | 5.11 | 0.0 | — | 2.78 | ⚠ LIMIT-CYCLE |
| +35° | +35.54° | 0.54 | 0.54 | 1.073s | 0.0 | 🟢 OK |
| +50° | +10.08° | 39.92 | 0.0 | — | 20.67 | ⚠ LIMIT-CYCLE |
| +0° | +0.23° | 0.23 | 0.0 | 1.827s | 0.35 | 🟢 OK |

## Durum: **LIMIT_CYCLE**

## Hedef
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC×360/466 (çıkış mili, 0.773°/count). instance-based g_axis firmware.

## Artifacts
- `data.csv`
- `cascade_plot.png` (θ takip + ω_ref/ω + u)
