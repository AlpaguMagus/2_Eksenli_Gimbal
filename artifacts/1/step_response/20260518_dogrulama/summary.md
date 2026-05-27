# Aşama 1.1 — Step Response Veri Toplama

- **Test ID:** 20260518_dogrulama
- **Tarih:** 2026-05-24 16:26:19
- **Commit:** `a065ec2`
- **Hedef:** Tek motor 1. dereceden + dead-band fit için step response veri seti
- **Komut:** `python3 scripts/step_response.py --test-id 20260518_dogrulama`
- **Handshake RTT:** 0.1 ms

## Step Listesi

| # | Yön | Duty | Faz | ω_steady (rad/s) | Örnekler |
|---|---|---|---|---|---|
| 1 | CW | +0.120 | drive |  +58.83 | 178 |
| 2 | CCW | +0.000 | coast |   +0.00 | 71 |
| 3 | CCW | -0.120 | drive |  -57.76 | 179 |
| 4 | CCW | +0.000 | coast |   +0.00 | 71 |
| 5 | CW | +0.140 | drive |  +68.92 | 178 |
| 6 | CCW | +0.000 | coast |   +0.00 | 72 |
| 7 | CCW | -0.140 | drive |  -68.92 | 178 |
| 8 | CCW | +0.000 | coast |   +0.00 | 71 |
| 9 | CW | +0.160 | drive |  +81.66 | 179 |
| 10 | CCW | +0.000 | coast |   +0.00 | 71 |
| 11 | CCW | -0.160 | drive |  -80.41 | 179 |
| 12 | CCW | +0.000 | coast |   +0.00 | 71 |
| 13 | CW | +0.180 | drive |  +92.03 | 178 |
| 14 | CCW | +0.000 | coast |   +0.00 | 72 |
| 15 | CCW | -0.180 | drive |  -91.40 | 178 |
| 16 | CCW | +0.000 | coast |   +0.00 | 71 |
| 17 | CW | +0.200 | drive | +104.93 | 179 |
| 18 | CCW | +0.000 | coast |   +0.00 | 71 |
| 19 | CCW | -0.200 | drive | -104.93 | 179 |
| 20 | CCW | +0.000 | coast |   +0.00 | 72 |
| 21 | CW | +0.250 | drive | +133.63 | 178 |
| 22 | CCW | +0.000 | coast |   +0.00 | 71 |
| 23 | CCW | -0.250 | drive | -131.53 | 178 |
| 24 | CCW | +0.000 | coast |   +0.00 | 71 |
| 25 | CW | +0.300 | drive | +162.69 | 179 |
| 26 | CCW | +0.000 | coast |   +0.00 | 71 |
| 27 | CCW | -0.300 | drive | -160.20 | 179 |
| 28 | CCW | +0.000 | coast |   +0.00 | 72 |
| 29 | CW | +0.400 | drive | +223.56 | 178 |
| 30 | CCW | +0.000 | coast |   +0.00 | 71 |
| 31 | CCW | -0.400 | drive | -219.21 | 179 |
| 32 | CCW | +0.000 | coast |   +0.00 | 71 |
| 33 | CW | +0.450 | drive | +250.16 | 179 |
| 34 | CCW | +0.000 | coast |   +0.00 | 71 |
| 35 | CCW | -0.450 | drive | -248.77 | 178 |
| 36 | CCW | +0.000 | coast |   +0.00 | 72 |

## Durum

**PASS**

## Artifacts

- `data.csv.gz` (ham CSV, gzipli)
