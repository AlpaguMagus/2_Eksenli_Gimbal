# Aşama 3.3 — Eksen-2 IMU Stabilizasyon (karşı, −pitch)

- **Test ID:** 20260612_121945
- **Tarih:** 2026-06-12 12:20
- **Commit:** `bd88852`
- **Eksen:** motor-2 (MODE2:STAB)
- **Mod:** STAB — motor base eğimine TERS döner (gerçek gimbalda payload sabit). ⚠ IMU base'de + mil boş → bu, stabilizasyon YASASININ demosu; tam eylemsiz doğrulama IMU payload'a taşınınca (Aşama 5).
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s, Kp_pos=6 takip)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 30`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 123.4° (-51.6…71.8) |
| Takip RMS (θ−ref) | **6.72°** |
| Hareketli pencere RMS | 6.74° |
| Max |hata| | 17.2° |
| Örnek sayısı | 1036 |

## Durum: **PASS**

## Yorum
🟢 Motor-2 IMU pitch'ini takip etti, RMS 6.72° (<10° hedef). Aşama 2.7 mirror (sağlıklı ünite ~4.02°) ile mertebe-uyumlu → instance-based MIRROR yolu gerçek-donanımda doğrulandı. Hızlı el bant limitini aşar (beklenen).

## Artifacts
- `data.csv`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
