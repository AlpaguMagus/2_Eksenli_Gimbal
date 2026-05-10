# 2A.T7 — 135 sn Entegrasyon Testi

- **Test ID:** 2A.T7
- **Tarih:** 2026-05-11
- **Commit:** `f8bf5c7` (Aşama 2A kapanış)
- **Hedef:** IMU + encoder + motor + stall_check aynı anda 60+ sn boyunca anormallik olmadan çalışsın
- **Komut:** `python3 plot_angles.py /dev/ttyACM0 logs/test_2a7_integration.csv` (135 sn kayıt — 60 sn hedefin fazlasıyla üstü)

## Sonuç (sayısal)

| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| Süre | 135.4 sn | ≥60 sn | ✓ |
| Örnek sayısı | 2527 | — | — |
| Sample rate | 18.7 Hz (plot tarafı) | USB 40 Hz, plot 25 fps | ✓ açıklanır |
| Sequence döngü sayısı | 7.5 | 3+ | ✓ |
| USB drop ≥100 ms | 5 (hepsi 30 sn aralık) | plot screenshot kaynaklı | ✓ açıklanır |
| Yanlış pozitif stall | 0 | 0 | ✓ |
| En uzun 0-hız periyodu | 4.8 sn | <5 sn (stall şüphesi sınırı) | ✓ |
| IMU pitch range | [-9.4°, +36.6°] | hareket | ✓ |
| CW%30 ortalama (7 döngü) | +167.98 ± 0.94 | önceki +165.60 | ✓ |
| CCW%30 ortalama | −166.48 ± 0.71 | önceki −164.00 | ✓ |
| CW%50 ortalama | +287.56 ± 1.33 | önceki +282.50 | ✓ |
| **CW%20 ortalama** | **+0.00** | önceki +107 | ⚠ R6 |

## PASS/FAIL gerekçesi

✅ **PASS.** Entegrasyon (IMU + encoder + motor + stall_check) kesintisiz çalışıyor. USB drop'lar plot_angles.py'nin 30 sn'lik screenshot fonksiyonu kaynaklı — firmware/USB tarafı temiz (ec_jump drop anlarında 0-658 count, gerçek atlaması yok). Yanlış pozitif stall yok, IMU sağlam, hızlar önceki testle %2 içinde. **CW%20 anomalisi** açık soru olarak kaldı (R6): 7 farklı denemede de ölü-banttan kalkamadı. Stall_check tetiklenmedi çünkü `current_duty > 0.20` strict greater (doğru davranış). Dead-band Aşama 2B.6'da nicelendirilecek.

## Artifacts

- `raw/test_2a7_integration.csv.gz` (26 KB, 2527 örnek)
- (görsel grafik üretilmedi — gerek görülmedi, sayısal sonuç yeterli)

## Açık konular (R6)

CW %20 ölü-bant değişkenliği: test_2a4 vs test_2a7 arasında +107 → +0 değişimi. Olası nedenler: motor sıcaklığı, PSU droop, kontak direnci. 2B.6 dead-band tespiti ile nicelendirilecek.
