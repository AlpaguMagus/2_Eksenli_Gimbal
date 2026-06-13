# Yüklü cascade FF re-test (motor-2) — 20260613_054039

- **Tarih:** 2026-06-13 05:41 · **Commit:** `f605d5c` · **Durum:** PASS
- **Yük:** son kol + boş telefon-standı (telefon yok), dibe asılı
- **Yöntem:** MODE2:POS basamak; FF yapısı × setpoint; kuyruk(~3s) θ_std limit-cycle metriği
- **FF yapıları:** off / grav / db(default) / sign — firmware LFF*/LFFG/LFFC/LFFDB komutları

## Sonuç (θ_std° / ss_err°)

| FF | 20° | 35° |
|---|---|---|
| off | 1.30 / 0.06 | 0.00 / 1.31 |
| grav | 2.08 / 0.67 | 0.00 / 2.08 |
| db | 0.00 / 0.69 | 0.00 / 0.54 |
| sign | 0.38 / 0.38 | 0.00 / 0.54 |

## PASS/FAIL gerekçesi
PASS şartı: off limit-cycle (θ_std>1°) gösteren açıda FF (db|sign) θ_std<1°'ye indirir. Sonuç: **PASS**. (sim öngörüsü design_loaded_feedforward.m: off≈2.2°, sign/db≈0°)

## Artifacts
- raw/data.csv
- loaded_ff_plot.png
