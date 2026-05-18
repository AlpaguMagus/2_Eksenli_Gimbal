# 2A.T7 — 135 sn Entegrasyon Testi

> ⚠ **REVIZE 2026-05-18:** "CW%20 anomalisi (R6)" başlangıçta fiziksel bir fenomen sanılmıştı; sonradan **ham log yeniden analiz edildi** (`artifacts/1/stiction_test/20260518_111200/`) ve motorun T7 sırasında CW%20'de **gerçekten döndüğü** kanıtlandı (her cycle ΔEC ≈ 1750, ω ≈ 76 rad/s motor şaftı). Anomalinin gerçek nedeni: T7 zamanında firmware USB CDC TX'e `OMEGA:` alanını henüz eklememişti (sonradan `0f27dd3` commit'te eklendi), Python analiz scripti `OMEGA:` regex'ini bulamayınca varsayılan **0.0** raporladı. Aşağıdaki "CW%20 ortalama +0.00" değeri ölçüm/parsing artefaktıdır. Detay → revize artifact.

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
| **CW%20 ortalama** | ~~**+0.00**~~ → **+76** (ham EC'den hesap, REVIZE 2026-05-18) | önceki +107 | ✓ — orijinal +0.00 parsing artefaktıydı |

## PASS/FAIL gerekçesi

✅ **PASS.** Entegrasyon (IMU + encoder + motor + stall_check) kesintisiz çalışıyor. USB drop'lar plot_angles.py'nin 30 sn'lik screenshot fonksiyonu kaynaklı — firmware/USB tarafı temiz (ec_jump drop anlarında 0-658 count, gerçek atlaması yok). Yanlış pozitif stall yok, IMU sağlam, hızlar önceki testle %2 içinde. ~~**CW%20 anomalisi** açık soru olarak kaldı (R6): 7 farklı denemede de ölü-banttan kalkamadı.~~ ✅ **REVIZE 2026-05-18: R6 fiziksel değildi.** Ham log yeniden analizi 8 cycle hepsinde CW%20'de motor döndüğünü gösterdi (ΔEC tutarlı ~1750). "+0.00" değeri Python analizinin OMEGA regex'i o dönem firmware'de olmadığı için verdiği varsayılan değerdi. Stall_check tetiklenmedi çünkü motor zaten dönüyordu.

## Artifacts

- `raw/test_2a7_integration.csv.gz` (26 KB, 2527 örnek)
- (görsel grafik üretilmedi — gerek görülmedi, sayısal sonuç yeterli)

## ~~Açık konular (R6)~~ — KAPATILDI 2026-05-18

~~CW %20 ölü-bant değişkenliği: test_2a4 vs test_2a7 arasında +107 → +0 değişimi. Olası nedenler: motor sıcaklığı, PSU droop, kontak direnci. 2B.6 dead-band tespiti ile nicelendirilecek.~~

**REVIZE:** R6 anomalisi gerçek bir fiziksel fenomen değildi. Bağımsız deneysel doğrulama (`artifacts/1/stiction_test/20260518_111200/`) gösterdi ki motor cold-start dahil tüm test edilen duty seviyelerinde (%10-25) başlıyor. T7 ham log yeniden analizi: motor CW%20'de gerçekten döndü, "+0.00" parsing artefaktı (eski firmware OMEGA göndermiyordu). Aşama 1.3 model yorumu da bu doğrultuda revize edildi (README §10.7 Bulgu 1).
