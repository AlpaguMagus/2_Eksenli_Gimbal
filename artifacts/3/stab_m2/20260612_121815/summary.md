# Aşama 3.3 — Eksen-2 IMU Stabilizasyon (karşı, −pitch)

- **Test ID:** 20260612_121815
- **Tarih:** 2026-06-12 12:18
- **Commit:** `bd88852`
- **Eksen:** motor-2 (MODE2:STAB)
- **Mod:** STAB — motor base eğimine TERS döner (gerçek gimbalda payload sabit). ⚠ IMU base'de + mil boş → bu, stabilizasyon YASASININ demosu; tam eylemsiz doğrulama IMU payload'a taşınınca (Aşama 5).
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s, Kp_pos=6 takip)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 30`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 6.9° (-29.4…-22.5) |
| Takip RMS (θ−ref) | **0.28°** |
| Hareketli pencere RMS | 0.27° |
| Max |hata| | 0.8° |
| Örnek sayısı | 1035 |

## Durum: **NO_MOTION**

## Yorum
⚠ Board yeterince eğilmedi (FP aralığı 6.9° < 20°). Tekrar: pitch ekseninde daha geniş yavaş eğme.

## Artifacts
- `data.csv`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
