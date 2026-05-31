# Aşama 2.7/2.8 — IMU Mirror Takip (Test 2.T6)

- **Test ID:** 20260531_174740
- **Tarih:** 2026-05-31 17:48
- **Commit:** `746d374`
- **Mimari:** MODE:MIRROR — θ_ref=clamp(fused_pitch−pitch₀, ±60°), slew 90°/s → cascade (Kp_pos=firmware 6 (analitik, [Franklin2010] §4.2))
- **Komut:** `python3 scripts/mirror_test.py`
- **NOT:** Serbest mil. Kazançlar Aşama 2.3/2.5 (yüksüz). Gerçek gimbalda yük ile yeniden ayar.

## Sonuçlar

| Metrik | Değer |
|---|---|
| valid | True |
| n | 1036 |
| rms_error_deg | 4.02 |
| rms_all_deg | 3.91 |
| max_error_deg | 9.08 |
| ref_span_deg | 95.4 |
| stall | False |
| status | PASS |

## Yorum

🟢 **PASS** — takip hatası RMS 4.02° < 5° (hedef). Motor IMU pitch'ini cascade ile izledi (ref aralığı 95.4°). Pozisyon dış döngü + hız PI iç döngü canlı değişen referansı takip ediyor.

## Artifacts
- `data.csv`
- `mirror_plot.png` (θ_ref vs θ_out + hata)
