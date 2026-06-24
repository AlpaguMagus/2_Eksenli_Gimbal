# Aşama 3.3 — Eksen-2 IMU Mirror Takip

- **Test ID:** 20260612_115610
- **Tarih:** 2026-06-12 11:56
- **Commit:** `f01013f`
- **Eksen:** motor-2 (MODE2:MIRROR)
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s, Kp_pos=6 takip)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 30`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 0.0° (0.0…0.0) |
| Takip RMS (θ−ref) | **0.00°** |
| Hareketli pencere RMS | 0.00° |
| Max |hata| | 0.0° |
| Örnek sayısı | 1072 |

## Durum: **NO_MOTION**

## Yorum
⚠ Board yeterince eğilmedi (FP aralığı 0.0° < 20°). Tekrar: pitch ekseninde daha geniş yavaş eğme.

## Artifacts
- `data.csv`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
