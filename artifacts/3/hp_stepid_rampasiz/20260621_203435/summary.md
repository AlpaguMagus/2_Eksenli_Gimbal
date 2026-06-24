# HP step-ID A/B — RAMPALI vs RAMPASIZ (firmware-ramp confound)
- **Tarih:** 20260621_203435  · **Commit:** bb3ff52
- **Hedef:** §12.10 τ_eff≈450ms firmware-rampası mı, sürücü mü ayır.
## Sonuç
| Adım | Δduty | yol | τ63 |
|---|---|---|---|
| A | 0.20 | RAMPALI | 2595ms |
| B | 0.10 | DİREKT | 3139ms |
Oran A/B = 0.8×
## Hüküm
τ_B < 100ms → 450ms firmware-ramp artefaktı (HW-039 hızlı). τ_B > 200ms → sürücü gerçekten yavaş.
