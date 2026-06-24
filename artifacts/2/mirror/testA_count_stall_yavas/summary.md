# Aşama 2.7/2.8 — IMU Mirror Takip (Test 2.T6)

- **Test ID:** testA_count_stall_yavas
- **Tarih:** 2026-06-07 16:33
- **Commit:** `0376605`
- **Mimari:** MODE:MIRROR — θ_ref=clamp(fused_pitch−pitch₀, ±60°), slew 90°/s → cascade (Kp_pos=firmware 6 (analitik, [Franklin2010] §4.2))
- **Komut:** `python3 scripts/mirror_test.py`
- **NOT:** Serbest mil. Kazançlar Aşama 2.3/2.5 (yüksüz). Gerçek gimbalda yük ile yeniden ayar.

## Sonuçlar

| Metrik | Değer |
|---|---|
| valid | True |
| n | 1208 |
| rms_error_deg | 5.8 |
| rms_all_deg | 4.64 |
| max_error_deg | 15.38 |
| ref_span_deg | 101.3 |
| stall | False |
| status | FAIL |

## Yorum

🔴 FAIL — RMS 5.8° ≥ 5°. Takip yetersiz; slew/clamp/kazanç gözden geçir.

## Artifacts
- `data.csv`
- `mirror_plot.png` (θ_ref vs θ_out + hata)
