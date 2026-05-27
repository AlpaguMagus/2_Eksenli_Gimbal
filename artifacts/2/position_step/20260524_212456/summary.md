# Aşama 2.5 — Pozisyon Cascade Step (Test 2.5)

- **Test ID:** 20260524_212456
- **Tarih:** 2026-05-24 21:25
- **Commit:** `9579254`
- **Mimari:** cascade (pozisyon P Kp_pos=2.0 → hız PI Kp=0.002/Ki=0.1)
- **Hedefler:** [30, 90, 45, 0, -45, 0] (mutlak çıkış mili açısı, derece)
- **Komut:** `python3 scripts/position_step_test.py --kpp 2.0`
- **NOT:** Serbest mil (yüksüz). Gerçek gimbalda yük ile yeniden ayar (ROADMAP §5).

## Sonuçlar

| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |
|---|---|---|---|---|---|---|
| +30° | +30.05° | 0.05 | 0.13 | 1.212s | 0.24 | 🟢 OK |
| +90° | +90.25° | 0.25 | 0.39 | 1.624s | 0.3 | 🟢 OK |
| +45° | +44.52° | 0.48 | 0.97 | 1.681s | 0.69 | 🟢 OK |
| +0° | -0.77° | 0.77 | 0.77 | 1.798s | 0.0 | 🟢 OK |
| -45° | -44.81° | 0.19 | 0.0 | 1.363s | 0.0 | 🟢 OK |
| +0° | -0.23° | 0.23 | 0.0 | 1.507s | 0.36 | 🟢 OK |

## Durum: **PASS**

## ASIL SORU — limit-cycle var mı?
🟢 **Limit-cycle YOK** — gerçek motorda statik sürtünme, simdeki düşük-hız kuantizasyon gezinmesini söndürdü. Cascade gerçek sistemde temiz oturuyor. Sim kötümserdi (sürtünmesiz). Hipotez doğrulandı.

## Hedef (Test 2.5)
- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°
- θ_out = EC × 360/466 (çıkış mili, pozisyon kuant. 0.773°/count)

## Artifacts
- `data.csv`
- `position_plot.png` (θ takip + ω_ref/ω + u)
