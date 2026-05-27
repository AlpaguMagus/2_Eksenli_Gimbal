# Aşama 2.7/2.8 — IMU Mirror Takip (Test 2.T6)

- **Test ID:** 20260526_204240
- **Tarih:** 2026-05-26 20:43
- **Commit:** `33f1117`
- **Mimari:** MODE:MIRROR — θ_ref=clamp(fused_pitch−pitch₀, ±60°), slew 90°/s → cascade (Kp_pos=5.0)
- **Komut:** `python3 scripts/mirror_test.py`
- **NOT:** Serbest mil. Kazançlar Aşama 2.3/2.5 (yüksüz). Gerçek gimbalda yük ile yeniden ayar.

## Sonuçlar

| Metrik | Değer |
|---|---|
| valid | True |
| n | 863 |
| rms_error_deg | 4.68 |
| rms_all_deg | 1.97 |
| max_error_deg | 10.64 |
| ref_span_deg | 42.2 |
| stall | False |
| status | PASS |

## Yorum

🟢 **PASS** — takip hatası RMS 4.68° < 5° (hedef). Motor IMU pitch'ini cascade ile izledi (ref aralığı 42.2°). Pozisyon dış döngü + hız PI iç döngü canlı değişen referansı takip ediyor.

## Artifacts
- `data.csv`
- `mirror_plot.png` (θ_ref vs θ_out + hata)
