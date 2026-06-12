# Aşama 3.3 — Eksen-2 IMU Stabilizasyon (karşı, −pitch)

- **Test ID:** 20260612_ffB_gyroff
- **Tarih:** 2026-06-12 23:31
- **Commit:** `288bb82`
- **Eksen:** motor-2 (MODE2:STAB)
- **Mod:** STAB — motor base eğimine TERS döner (gerçek gimbalda payload sabit). ⚠ IMU base'de + mil boş → bu, stabilizasyon YASASININ demosu; tam eylemsiz doğrulama IMU payload'a taşınınca (Aşama 5).
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s, Kp_pos=6 takip)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 30`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 168.2° (-80.1…88.1) |
| Takip RMS (θ−ref) | **9.49°** |
| Hareketli pencere RMS | 10.20° |
| Max |hata| | 28.3° |
| Örnek sayısı | 1035 |

## Durum: **PASS**

## Yorum
🟢 Motor-2 IMU pitch'ini takip etti, RMS 9.49° (<10° hedef). Aşama 2.7 mirror (sağlıklı ünite ~4.02°) ile mertebe-uyumlu → instance-based MIRROR yolu gerçek-donanımda doğrulandı. Hızlı el bant limitini aşar (beklenen).

## Artifacts
- `data.csv`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
