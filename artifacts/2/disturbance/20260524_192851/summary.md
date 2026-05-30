# Aşama 2.4 — Disturbance Rejection

- **Test ID:** 20260524_192851
- **Tarih:** 2026-05-24 19:29
- **Commit:** `b4b5d78`
- **Setpoint:** 100 rad/s
- **Kazanç:** Kp=0.002, Ki=0.1
- **Yöntem:** Motor sabit hızda dönerken çıkış mili elle yavaşlatıldı (2-3 kez)

## Sonuçlar (ramp-sonrası pencere [1.5–3 s] ile düzeltilmiş)

| Metrik | Değer |
|---|---|
| valid | True |
| baseline_omega | **101.1** (= setpoint 100, PI sıfır ss-error) |
| baseline_u | 0.186 |
| min_omega_during_dist (aktif [3–14 s]) | 56.0 |
| max_dip_pct | 44.0 |
| max_u_response | 0.5 (saturation) |
| recovered_to_setpoint | True |
| stall_triggered | False |

> **Düzeltme notu:** İlk otomatik özet baseline penceresini 0–3 s aldığından **slew ramp-up'ını** (0→100, ~1 s, başta ω=0) içine katıp yanıltıcı `baseline=86.9` vermişti. Ramp sonrası [1.5–3 s] gerçek baseline **101** (= setpoint). Benzer şekilde ilk "min 15.0 / %82.8" rakamı test sonu **bırakma transientini** (t≈17.8 s, motor serbest → ω→0) yakalamıştı; aktif disturbance penceresinde [3–14 s] gerçek dip **%44** (min 56). Ham otomatik metrikler `meta.json._raw_auto_metrics`'te saklı.

## Yorum

🟢 PASS — Baseline 101 rad/s (= setpoint; PI'nin integral aksiyonu DC'de sıfır kalıcı-hal hatası verdiğini doğrular). Elle yük ω'yı 56 rad/s'ye itti (%44 dip), PI duty'yi 0.186→0.50 saturation'a çıkararak telafi etti, ω her müdahale sonrası setpoint'e (~101) döndü. İntegral aksiyon disturbance rejection sağlıyor.

`disturbance_plot.png`'de çoklu `u` piki görülüyor — her elle yavaşlatmada PI çıkışı baseline 0.186'dan 0.50'ye fırlıyor (yük telafisi), müdahale bitince baseline'a dönüyor. Klasik döngü: yük → hız düşer → error artar → duty yükselir → hız toparlanır.

**Not:** 3 denemede geçerli. İlk 2 geçersizdi (el kaydı / motoru tam durdurma). 3. deneme eller-çekili başlangıç + hafif yavaşlatma ile temiz.

**İzleme notu:** 2. denemede motor tam durdurulunca `u` saturation'a (0.5) çıkması beklenirken 0.026'da kaldı (anomali). Bu temiz testte yok; "motor durma + uzun tutma" edge-case'i izleme listesinde.

## Artifacts
- `data.csv` (raw, gitignored)
- `disturbance_plot.png` (ω + u zaman serisi, 7 müdahale piki)
