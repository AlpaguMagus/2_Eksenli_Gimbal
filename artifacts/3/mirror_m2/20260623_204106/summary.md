# Aşama 3.3 — Eksen-2 IMU Mirror Takip (taklit, +pitch)

- **Test ID:** 20260623_204106
- **Tarih:** 2026-06-23 20:41
- **Commit:** `fca5ec1`
- **Eksen:** motor-2 (MODE2:MIRROR)
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s; mirror/STAB takip kazancı Kp_pos=6 — MODE girişinde firmware OTOMATİK uygular (cmd_parser.c:66, Kv=6 analitik hedefi; KPP gönderilmez). POS step default 2.0 ayrı, bkz docs §12.9.3 teşhis)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 30`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 72.5° (-29.7…42.8) |
| Takip RMS (θ−ref) | **5.72°** |
| Hareketli pencere RMS | 6.76° |
| Max |hata| | 16.4° |
| Örnek sayısı | 3752 |

## Durum: **PASS**

## Yorum
🟢 Motor-2 IMU pitch'ini takip etti, RMS 5.72° (<10° hedef). Aşama 2.7 mirror (sağlıklı ünite ~4.02°) ile mertebe-uyumlu → instance-based MIRROR yolu gerçek-donanımda doğrulandı. Hızlı el bant limitini aşar (beklenen).

## Artifacts
- `data.csv.gz`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
