# Aşama 0 — IMU Statik Gürültü Logu (Allan variance)

- **Test ID:** allan_900
- **Tarih:** 2026-05-28 21:47
- **Commit:** `2d09a64`
- **Süre:** 900 s · **Örnek:** 32147 · **fs:** 35.7 Hz
- **Komut:** `python3 scripts/imu_noise_log.py --duration 900`

## Sonraki adım
`matlab/asama_0_altyapi/analyze_allan_variance.m` → Allan deviation, ARW, bias instability, optimal α.

## Artifacts
- `data.csv.gz`
