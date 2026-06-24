# 3.HP-charac-Faz1 — HP karakterizasyon (her iki yön, ≤0.5 duty)

- **Test ID:** 3.HP-charac-Faz1
- **Tarih:** 20260623_165658  ·  **Commit:** 9d3c62a  ·  **Durum:** PASS
- **Hedef:** RPWM kablo-fix + ~940µF bulk sonrası HP'yi temiz karakterize et (forward artık temiz mi, yön simetrisi, dead-band, K(duty), τ) → Faz 2 analitik cascade girdisi.
- **Donanım:** HP Pololu (HW-039/BTS7960, 20:1), Sagemcom 12V + ~940µF bulk, **mil serbest**, duty cap 0.5.

## Sonuç (sayısal)
| Metric | fwd | rev | Simetri |
|---|---|---|---|
| Kg_duty (cnt/s/duty) | 7439 | 6849 | %8 |
| τ63 (ms) | 71.9 | 71.5 | — |
| V_dead | None | None | — |

K_motor≈81.1 rad/s/V (motor mili, Vs=12.0) · K_out≈4.06 (çıkış mili, ÷20).

### K(duty) eğrisi — forward
| duty | ω (cnt/s) | Kg | canary |
|---|---|---|---|
| +0.10 | None | None | ✓ |
| +0.15 | None | None | ✓ |
| +0.20 | None | None | ✓ |
| +0.30 | 2196.0 | 7321.2 | ✓ |
| +0.40 | 2986.0 | 7465.6 | ✓ |
| +0.50 | 3765.0 | 7530.5 | ✓ |

### K(duty) eğrisi — reverse
| duty | ω (cnt/s) | Kg | canary |
|---|---|---|---|
| -0.10 | None | None | ✓ |
| -0.15 | None | None | ✓ |
| -0.20 | None | None | ✓ |
| -0.30 | -1991.0 | 6635.6 | ✓ |
| -0.40 | -2770.0 | 6923.8 | ✓ |
| -0.50 | -3494.0 | 6987.6 | ✓ |

## Flags / canary
✓ Dropout/freeze yok, ters-yön yok (0.5 cap güvenli).

## Artifacts
- meta.json · raw/stepid_{fwd,rev}_{base,step}.csv (τ ham veri)

## İlgili
- Plan: Faz 1 (onaylı) → Faz 2 analitik cascade (`matlab/asama_3_mimo_model/hp_cascade_design.m`) → Faz 3 firmware.
- Üreten: `scripts/hp_characterize.py`
