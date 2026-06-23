# 3.K3-tau-duty — HP τ-vs-duty (gain scheduling gerekli mi?)

- **Tarih:** 20260623_214740 · **Commit:** c869206 · **Hüküm:** tek-kazanç YETERLİ (τ ~sabit) → K3 gereksiz
- **Hedef:** HP τ farklı çalışma-noktalarında değişiyor mu → K3 (gain scheduling) gerekçeli mi.
- **Donanım:** HP serbest mil, mengeneli, loop 8ms.

## Sonuç
| base→step | ω (rad/s) | τ63 (ms) |
|---|---|---|
| 0.15→0.20 | 71.4→170.6 | 40.4 |
| 0.25→0.30 | 228.4→284.3 | 47.8 |
| 0.35→0.40 | 335.1→389.2 | 48.7 |
| 0.45→0.50 | 439.6→490.7 | 40.0 |

- τ aralığı: 40.0–48.7 ms (oran 1.22×)
- **Hüküm:** tek-kazanç YETERLİ (τ ~sabit) → K3 gereksiz

## Yorum
τ ~sabitse tek-kazanç cascade tüm çalışma-aralığında yeterli (K3 gereksiz). Belirgin değişiyorsa çalışma-
noktası kazanç tablosu (K3). Bu rijit-mengene ölçümü Aşama-1 U-eğrisi sezgisini doğrudan test eder.

## Üreten: `scripts/k3_tau_vs_duty.py`
