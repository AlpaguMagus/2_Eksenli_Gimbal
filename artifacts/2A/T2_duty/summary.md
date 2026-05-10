# 2A.T2/T3 — Duty Linearitesi + Yön + BRAKE

- **Test ID:** 2A.T2 + 2A.T3 (aynı log)
- **Tarih:** 2026-04-06 (geçmiş kayıt, retroaktif olarak artifact'a taşındı)
- **Commit:** `320d1d0` (firmware: Motor_SetDir + Motor_SetDuty + geçici test sequence)
- **Hedef:** %20/%30/%50 duty seviyelerinde encoder hızı lineer mi? CW/CCW simetri? BRAKE durma davranışı?
- **Komut:** `python3 plot_angles.py /dev/ttyACM1 logs/test_2a4.csv` (40 sn manuel kayıt)

## Sonuç (sayısal)

| Mod | Motor şaftı (rad/s) | K = ω/duty | Beklenti |
|---|---|---|---|
| CW %30 | +165.65 | 552.2 | ~565 (no-load × 0.30) |
| CCW %30 | −164.16 | 547.2 | simetri |
| CW %20 | +106.97 | 534.9 | ~113 |
| CW %50 | +282.46 | 564.9 | 282.5 (mükemmel uyum) |

| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| K min/max sapma | %5.3 | <%10 lineer model | ✓ |
| CW/CCW simetri (%30) | %0.9 | <%5 | ✓ |
| BRAKE −164 → %10 hız | 1456 ms | <2 sn | ✓ |
| No-load uyum (%50) | %0.16 | <%5 | ✓ |

## PASS/FAIL gerekçesi

✅ **PASS.** Duty lineerlik %5.3 sapma — Vsat etkisi (0.5V/12V = %4) ile tutarlı, lineer model uygun. Yön simetrisi mükemmel (%0.9). BRAKE durma süresi makul (atalet + redüktör). No-load tahmini ile ölçüm arasında %0.16 hata — sistem karakterizasyonu güvenilir.

## Artifacts

- `raw/test_2a4.csv.gz` (4.4 KB, 770 örnek)
- `test_2a4_analysis.png` (109 KB, 3 panel: encoder count delta, hız profili sequence renkli, IMU)
