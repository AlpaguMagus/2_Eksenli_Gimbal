# Bring-up Smoke Test — IMU + LP + HP tam bench

- **Test ID:** 3.SMOKE
- **Tarih:** 2026-06-23
- **Commit:** d6c7c6e
- **Düzenek:** HP (Motor1/HW-039) + LP (Motor2/TB6612) **ikisi de mengeneli (rijit) + serbest milli**; IMU bağlı; tek 12V besleme
- **Hedef:** Tüm bağlantıların (IMU, iki encoder, iki motor) canlı + doğru pinde olduğunu ve **IMU bağlıyken gerçek loop hızını** doğrula (GPIO_PULLUP fix'i şimdiye dek yalnız IMU-koparılmışken test edilmişti).
- **Komut:** non-destructive telemetri okuma + `scripts`-tarzı DUTY sürüşü (raw/motor_smoke.log)

## Sonuç (sayısal)
| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| Loop (IMU okunurken) | **8.00 ms / 125 Hz** | <15 ms (32 değil) | ✅ |
| Loop (IMU NACK, kıyas) | 6.00 ms | — | (NACK imzası) |
| IMU FP / GX / GY | −64.8° / 1.5 / 2.2 dps | ≠0, gerçek | ✅ |
| Encoder-1 (HP, PA15/PB3) | elle çevir → EC=400 | sayar | ✅ |
| Encoder-2 (LP, PA8/PA9) | elle çevir → EC2=73 | sayar | ✅ |
| HP motor ±0.30 | ΔEC +2054 / −2010 | ±, zıt işaret | ✅ |
| LP motor ±0.30 | ΔEC2 +1162 / −1135 | ±, zıt işaret | ✅ |

## PASS/FAIL gerekçesi
Dört alt-sistem de (IMU, iki encoder, iki motor) bağımsız doğrulandı: IMU gerçek gravite/gyro verisi
veriyor; iki encoder elle çevirmede sayıyor; iki motor iki yönde dönüp ilgili encoder'da tutarlı-işaret
ΔEC üretiyor. **Kritik bulgu:** IMU bağlıyken gerçek loop = **8 ms** (6 ms değil — 6 ms NACK durumuydu);
32 ms artefaktı kesin gitti. Bring-up bulgusu: **SCL teli gevşekti** (FP/GX/GY tam 0.0 + loop 6.00 ms TAM
= hızlı-NACK imzası ile teşhis edildi), re-seat sonrası IMU okudu. **PASS.**

## İzlek (sonraki adıma not)
- Gerçek loop 8 ms → $T_s/dt = 5/8 = 0.625$ (docs'taki 6 ms/0.83 = NACK durumu). LP karakterizasyon/
  kontrol adımında docs §12.13'e işlenecek.
- Yön işaretleri tutarlı; mutlak yön (CW/CCW ↔ +duty) cascade adımında doğrulanır.

## Artifacts
- raw/motor_smoke.log (gitignored)
