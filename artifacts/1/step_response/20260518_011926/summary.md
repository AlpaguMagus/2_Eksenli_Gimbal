# Aşama 1.1 — Step Response Veri Toplama

- **Test ID:** 20260518_011926
- **Tarih:** 2026-05-18 01:21:32
- **Commit:** `67db814`
- **Hedef:** Tek motor 1. dereceden + dead-band fit için step response veri seti
- **Komut:** `python3 scripts/step_response.py --test-id 20260518_011926`
- **Handshake RTT:** 0.0 ms

## Step Listesi

| # | Yön | Duty | Faz | ω_steady (rad/s) | Örnekler |
|---|---|---|---|---|---|
| 1 | CW | +0.120 | drive |  +57.36 | 178 |
| 2 | CCW | +0.000 | coast |   +0.00 | 72 |
| 3 | CCW | -0.120 | drive |  -57.78 | 178 |
| 4 | CCW | +0.000 | coast |   +0.00 | 71 |
| 5 | CW | +0.140 | drive |  +67.74 | 179 |
| 6 | CCW | +0.000 | coast |   +0.00 | 71 |
| 7 | CCW | -0.140 | drive |  -69.13 | 178 |
| 8 | CCW | +0.000 | coast |   +0.00 | 72 |
| 9 | CW | +0.160 | drive |  +81.94 | 178 |
| 10 | CCW | +0.000 | coast |   +0.00 | 72 |
| 11 | CCW | -0.160 | drive |  -80.68 | 178 |
| 12 | CCW | +0.000 | coast |   +0.00 | 71 |
| 13 | CW | +0.180 | drive |  +92.88 | 179 |
| 14 | CCW | +0.000 | coast |   +0.00 | 71 |
| 15 | CCW | -0.180 | drive |  -90.59 | 179 |
| 16 | CCW | +0.000 | coast |   +0.00 | 71 |
| 17 | CW | +0.200 | drive | +106.32 | 178 |
| 18 | CCW | +0.000 | coast |   +0.00 | 72 |
| 19 | CCW | -0.200 | drive | -100.43 | 178 |
| 20 | CCW | +0.000 | coast |   +0.00 | 71 |
| 21 | CW | +0.250 | drive | +131.73 | 179 |
| 22 | CCW | +0.000 | coast |   +0.00 | 71 |
| 23 | CCW | -0.250 | drive | -129.65 | 179 |
| 24 | CCW | +0.000 | coast |   +0.00 | 72 |
| 25 | CW | +0.300 | drive | +160.74 | 178 |
| 26 | CCW | +0.000 | coast |   +0.00 | 71 |
| 27 | CCW | -0.300 | drive | -159.78 | 179 |
| 28 | CCW | +0.000 | coast |   +0.00 | 71 |
| 29 | CW | +0.400 | drive | +220.87 | 179 |
| 30 | CCW | +0.000 | coast |   +0.00 | 71 |
| 31 | CCW | -0.400 | drive | -219.15 | 178 |
| 32 | CCW | +0.000 | coast |   +0.00 | 72 |
| 33 | CW | +0.450 | drive | +250.16 | 179 |
| 34 | CCW | +0.000 | coast |   +0.00 | 71 |
| 35 | CCW | -0.450 | drive | -246.42 | 179 |
| 36 | CCW | +0.000 | coast |   +0.00 | 71 |

## Durum

**PASS**

## Artifacts

- `data.csv.gz` (ham CSV, gzipli)
