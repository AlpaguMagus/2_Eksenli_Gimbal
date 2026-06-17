# Yüklü cascade FF re-test (motor-2) — 20260613_213251

- **Tarih:** 2026-06-13 21:34 · **Commit:** `5613586` · **Durum:** REVIEW
- **Yük:** son kol + boş telefon-standı (telefon yok), dibe asılı
- **Yöntem:** MODE2:POS basamak; FF yapısı × setpoint; kuyruk(~3s) θ_std limit-cycle metriği
- **FF yapıları:** off / grav / db(default) / sign — firmware LFF*/LFFG/LFFC/LFFDB komutları

## Sonuç (θ_std° / ss_err°)

| FF | 20° | 35° |
|---|---|---|
| off | 0.00 / 15.36 | 0.00 / 30.36 |
| grav | 0.00 / 15.36 | 0.00 / 30.36 |
| db | 0.00 / 15.36 | 0.00 / 0.24 |
| sign | 0.00 / 15.36 | 0.07 / 0.53 |

## PASS/FAIL gerekçesi
PASS şartı: off limit-cycle (θ_std>1°) gösteren açıda FF (db|sign) θ_std<1°'ye indirir. Sonuç: **REVIEW**. (sim öngörüsü design_loaded_feedforward.m: off≈2.2°, sign/db≈0°)

## Artifacts
- raw/data.csv
- loaded_ff_plot.png
