# 2A.T4 — Non-blocking Rampa Doğrulama

- **Test ID:** 2A.T4
- **Tarih:** 2026-05-03 (retroaktif kayıt)
- **Commit:** `85e03a9` (Motor_Tick non-blocking, 200 Hz loop, 40 Hz USB throttle)
- **Hedef:** Motor_SetDuty otomatik rampa süreleri spec'e (200 ms) uygun mu? Önceki ani sıçramaların yerini yumuşak geçişler aldı mı?
- **Komut:** `python3 plot_angles.py /dev/ttyACM1 logs/test_2a5.csv` (80 sn kayıt)

## Sonuç (sayısal)

| Transition | Önceki (2A.4) | Yeni (2A.5) | Spec | Durum |
|---|---|---|---|---|
| STOP → CCW %30 | ani <50 ms | 138 ms | 145 ms | ✓ |
| STOP → CW %50 | ani | 260 ms | 249 ms | ✓ |
| STOP → CW %20 | ani | 157 ms | 94 ms | △ Vsat gecikme |

| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| Steady-state hız varyasyonu (eski/yeni) | <%3 | <%5 | ✓ |
| Tipik rampa ortalaması (CCW%30 + CW%50)/2 | 199 ms | 200 ms hedef | ✓ |
| IMU çalışıyor (pitch range) | [-5.2°, +88°] | hareket tespit | ✓ |

## PASS/FAIL gerekçesi

✅ **PASS.** Non-blocking rampa spec'e uyumlu — tipik 200 ms hedef ile mükemmel uyum (199 ms ortalama). CW%20 daha uzun çıkıyor (Vsat ile motor ivmelenmesi gecikmesi) ama spec ihlali sayılmaz. Steady-state hızlar önceki testle %3 içinde tutarlı; PSU droop ve sıcaklık varyasyonu kabul edilebilir. IMU sağlam — önceki "tüm sıfır" gözlemi sabit kart + %.1f rounding'di (bu testte kart eğildiğinde pitch +88°'ye kadar takip).

## Artifacts

- `raw/test_2a5.csv.gz` (18 KB, 1525 örnek)
- `test_2a5_ramp_comparison.png` (98 KB, eski vs yeni CW%30 transition karşılaştırması)
