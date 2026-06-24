# Aşama 3.3 — Eksen-2 IMU Mirror Takip

- **Test ID:** 20260612_120636
- **Tarih:** 2026-06-12 12:07
- **Commit:** `94a36e3`
- **Eksen:** motor-2 (MODE2:MIRROR)
- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s, Kp_pos=6 takip)
- **Komut:** `python3 scripts/motor_mirror_test.py --motor 2 --dur 30`

## Sonuç (sayısal)

| Metrik | Değer |
|---|---|
| Eğme genliği (FP aralığı) | 158.6° (-72.0…86.6) |
| Takip RMS (θ−ref) | **5.53°** |
| Hareketli pencere RMS | 5.68° |
| Max |hata| | 15.7° |
| Örnek sayısı | 1036 |

## Durum: **PASS**

## Yorum
🟢 Motor-2 IMU pitch'ini takip etti, RMS 5.53° (<10° hedef). Aşama 2.7 mirror (sağlıklı ünite ~4.02°) ile mertebe-uyumlu → instance-based MIRROR yolu gerçek-donanımda doğrulandı. Hızlı el bant limitini aşar (beklenen).

## Artifacts
- `data.csv`
- `mirror_plot.png` (FP/ref/θ_motor + hata)
