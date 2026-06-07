# Aşama 2.5 — Pozisyon Cascade Step (Test 2.5)

- **Test ID:** 20260531_151114
- **Tarih:** 2026-05-31 15:11
- **Commit:** `a9eb046`
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/position_step_test.py --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Gerçek gimbalda yük ile yeniden ayar (ROADMAP §5).

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +30.13° | 0.13 | 0.13 | 1.259s | 0.0 | 🟢 OK |
| +90° | +90.39° | 0.39 | 0.39 | 1.79s | 0.0 | 🟢 OK |
| +45° | +44.22° | 0.78 | 0.97 | 1.847s | 0.33 | 🟢 OK |
| +0° | +0.00° | 0.0 | 0.0 | 1.372s | 0.0 | 🟢 OK |
| -45° | -45.19° | 0.19 | 0.58 | 1.484s | 0.44 | 🟢 OK |
| +0° | -0.08° | 0.08 | 0.0 | 1.4s | 0.24 | 🟢 OK |

## Durum: **PASS**

## ASIL SORU — limit-cycle var mı?
🟢 **Limit-cycle YOK** — gerçek motorda statik sürtünme, simdeki düşük-hız kuantizasyon gezinmesini söndürdü. Cascade gerçek sistemde temiz oturuyor. Sim kötümserdi (sürtünmesiz). Hipotez doğrulandı.

## Hedef (Test 2.5)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC × 360/466 (çıkış mili, pozisyon kuant. 0.773°/count)

## Artifacts
- `data.csv`
- `position_plot.png` (θ takip + ω_ref/ω + u)
