# Yüklü cascade FF re-test (motor-2) — 20260613_clean_pushed

- **Tarih:** 2026-06-13 21:38 · **Commit:** `5613586` · **Durum:** PASS
- **Yük:** son kol + boş telefon-standı (telefon yok), dibe asılı
- **Yöntem:** MODE2:POS basamak; FF yapısı × setpoint; kuyruk(~3s) θ_std limit-cycle metriği
- **FF yapıları:** off / grav / db(default) / sign — firmware LFF*/LFFG/LFFC/LFFDB komutları

## Sonuç (θ_std° / ss_err°)

| FF | 20° | 35° |
|---|---|---|
| off | 1.41 / 0.27 | 0.00 / 0.54 |
| grav | 1.34 / 1.83 | 0.00 / 0.54 |
| db | 0.00 / 0.69 | 0.00 / 0.54 |
| sign | 0.24 / 0.04 | 0.23 / 0.47 |

## PASS/FAIL gerekçesi
PASS şartı: off limit-cycle (θ_std>1°) gösteren açıda FF (db|sign) θ_std<1°'ye indirir. Sonuç: **PASS**. (sim öngörüsü design_loaded_feedforward.m: off≈2.2°, sign/db≈0°)

## Artifacts
- raw/data.csv
- loaded_ff_plot.png
