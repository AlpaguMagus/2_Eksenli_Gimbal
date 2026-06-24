# 3.LP-stepid — Kg + tau, iki yön

- **Tarih:** 20260623_203358 · **Commit:** df989e7 · **Durum:** PASS
- **Hedef:** LP plant — Kg (rad/s/duty), Coulomb ofset, τ63; iki yön; eski Aşama-1 LP modeliyle kıyas.
- **Donanım:** LP Motor2/TB6612/9.7:1, mil serbest, mengeneli.

## Sonuç
| | Kg (rad/s/duty) | duty0 (Coulomb) | τ63 (ms) |
|---|---|---|---|
| **FWD** | 559.8 | 0.024 | 39.9 |
| **REV** | 555.1 | 0.023 | 39.9 |

## Kıyas
- Eski Aşama-1 LP: K=53.89 rad/s/V, τ=60.5 ms (×12V nominal ≈ 647 rad/s/duty).
- HP rijit §12.13.5: Kg~974/897, τ~72 ms, Coulomb 0.14/0.20 (asimetrik).
- LP dead-band (3.LP-deadband): breakaway ~0.05, simetrik, stiction yok.

## Üreten: `scripts/lp_stepid.py`
