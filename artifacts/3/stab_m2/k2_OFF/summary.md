# Aşama 3.3 — Eksen-2 IMU Stabilizasyon (karşı, −pitch)

- **Test ID:** k2_OFF
- **Tarih:** 2026-06-23 23:50
- **Commit:** `561da70`
- **Eksen:** motor-2 (MODE2:STAB)
- **Mod:** STAB — motor base eğimine TERS döner (gerçek gimbalda payload sabit). ⚠ IMU base'de + mil boş → bu, stabilizasyon YASASININ demosu; tam eylemsiz doğrulama IMU payload'a taşınınca (Aşama 5).
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s; mirror/STAB takip kazancı Kp_pos=6 — MODE girişinde firmware OTOMATİK uygular (cmd_parser.c:66, Kv=6 analitik hedefi; KPP gönderilmez). POS step default 2.0 ayrı, bkz docs §12.9.3 teşhis)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 25`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 81.4° (-37.5…43.9) |
| Takip RMS (θ−ref) | **5.92°** |
| Hareketli pencere RMS | 6.46° |
| Max |hata| | 16.6° |
| Örnek sayısı | 3206 |

## Durum: **PASS**

## Yorum
🟢 Motor-2 IMU pitch'ini takip etti, RMS 5.92° (<10° hedef). Aşama 2.7 mirror (sağlıklı ünite ~4.02°) ile mertebe-uyumlu → instance-based MIRROR yolu gerçek-donanımda doğrulandı. Hızlı el bant limitini aşar (beklenen).

## Artifacts
- `data.csv.gz`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
