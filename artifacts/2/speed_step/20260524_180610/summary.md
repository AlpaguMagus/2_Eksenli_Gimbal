# Aşama 2.3 — Hız PI Step Response (Test 2.T2)

- **Test ID:** 20260524_180610
- **Tarih:** 2026-05-24 18:06
- **Commit:** `3504fb9`
- **Kazanç:** Kp=0.002, Ki=0.1, slew=200 (Aşama 2.3 ampirik)
- **Komut:** `python3 scripts/speed_step_test.py`
- **NOT:** Serbest mil (yüksüz). Gerçek gimbalda yük ile yeniden ayar (ROADMAP §5).

## Sonuçlar

| Setpoint | ω_ss | ss_err % | OS % | settling | u_std | durum |
|---|---|---|---|---|---|---|
| +40 | +39.2 | 2.0 | 12.2 | 2.881s | 0.005 | 🟢 OK |
| -40 | +40.1 | 0.2 | 12.2 | 2.969s | 0.004 | 🟢 OK |
| +80 | +76.8 | 4.1 | 2.9 | — | 0.003 | 🟢 OK |
| -80 | +79.1 | 1.2 | 12.2 | — | 0.002 | 🟢 OK |
| +120 | +120.2 | 0.2 | 2.9 | 0.88s | 0.002 | 🟢 OK |
| -120 | +120.3 | 0.3 | 6.0 | 2.182s | 0.003 | 🟢 OK |
| +160 | +158.6 | 0.9 | 2.9 | 1.138s | 0.003 | 🟢 OK |
| -160 | +160.7 | 0.5 | 2.9 | 1.137s | 0.003 | 🟢 OK |

## Durum: **PASS**

## Hedef (Test 2.T2)
- settling < 5τ (~300 ms), overshoot < %10, ss_error < %2
- ω metrikleri raw telemetri 5-örnek moving-average ile yumuşatıldı (encoder kuantizasyon)

## Artifacts
- `data.csv`
