# Faz 3b — HP sürekli-takip (sinüs, stick-slip baypas testi)

- **Tarih:** 2026-06-23 13:21 · **Commit:** `767fb66` · **Durum:** STICK_SLIP
- **Hipotez:** sürekli hareket stick-slip'i baypas eder (§12.12.5 öngörüsü). FF KAPALI, mil serbest.
- **Referans:** sinüs A=40.0° f=0.2Hz (tepe 50°/s) · Kp_pos=2.0 · cpr=960

## Sonuç
| Metrik | Değer | Yorum |
|---|---|---|
| RMS takip hatası | 49.5° | genlik 40.0° |
| max hata | 111.1° | |
| stuck-fraksiyon | %95 | ref hareketliyken ω≈0 |
| lurch-spike | 14 | breakaway imzası |

**Hüküm:** STICK-SLIP DEVAM — sürekli takipte de takılıyor (öngörü çürüdü → loop-rate fix gerek)

## Artifacts
- raw/data.csv · hp_track_plot.png
## Üreten: `scripts/hp_track_test.py`
