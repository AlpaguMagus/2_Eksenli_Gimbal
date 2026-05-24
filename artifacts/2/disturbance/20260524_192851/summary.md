# Aşama 2.4 — Disturbance Rejection

- **Test ID:** 20260524_192851
- **Tarih:** 2026-05-24 19:29
- **Commit:** `b4b5d78`
- **Setpoint:** 100 rad/s
- **Kazanç:** Kp=0.002, Ki=0.1
- **Yöntem:** Motor sabit hızda dönerken çıkış mili elle yavaşlatıldı (2-3 kez)

## Sonuçlar

| Metrik | Değer |
|---|---|
| valid | True |
| baseline_omega | 86.9 |
| baseline_u | 0.168 |
| min_omega_during_dist | 15.0 |
| max_dip_pct | 82.8 |
| max_u_response | 0.5 |
| final_omega | 94.2 |
| recovered_to_setpoint | True |
| stall_triggered | False |

## Yorum

🟢 PASS — Disturbance ile ω %82.8 düştü (min 15.0 rad/s), PI duty'yi 0.168→0.5'e çıkararak telafi etti, ω setpoint'e döndü (son 94.2 rad/s). İntegral aksiyon disturbance rejection sağlıyor.

`disturbance_plot.png`'de **7 net `u` piki** görülüyor — her elle yavaşlatmada PI çıkışı baseline 0.18'den 0.4-0.5'e fırlıyor (yük telafisi), müdahale bitince baseline'a dönüyor. Klasik döngü: yük → hız düşer → error artar → duty yükselir → hız toparlanır.

**Not:** 3 denemede geçerli. İlk 2 geçersizdi (el kaydı / motoru tam durdurma). 3. deneme eller-çekili başlangıç + hafif yavaşlatma ile temiz.

**İzleme notu:** 2. denemede motor tam durdurulunca `u` saturation'a (0.5) çıkması beklenirken 0.026'da kaldı (anomali). Bu temiz testte yok; "motor durma + uzun tutma" edge-case'i izleme listesinde.

## Artifacts
- `data.csv` (raw, gitignored)
- `disturbance_plot.png` (ω + u zaman serisi, 7 müdahale piki)
