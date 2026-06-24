# 3.HP-charac-Faz1 — HP karakterizasyon (her iki yön, ≤0.5 duty)

- **Test ID:** 3.HP-charac-Faz1
- **Tarih:** 20260623_121124  ·  **Commit:** faba92f  ·  **Durum:** PASS
- **Hedef:** RPWM kablo-fix + ~940µF bulk sonrası HP'yi temiz karakterize et (forward artık temiz mi, yön simetrisi, dead-band, K(duty), τ) → Faz 2 analitik cascade girdisi.
- **Donanım:** HP Pololu (HW-039/BTS7960, 20:1), Sagemcom 12V + ~940µF bulk, **mil serbest**, duty cap 0.5.

## Sonuç (sayısal)
| Metric | fwd | rev | Simetri |
|---|---|---|---|
| Kg_duty (cnt/s/duty) | 7389 | 7260 | %2 |
| τ63 (ms) | 63.4 | 64.2 | — |
| V_dead | None | None | — |

K_motor≈80.6 rad/s/V (motor mili, Vs=12.0) · K_out≈4.03 (çıkış mili, ÷20).

### K(duty) eğrisi — forward
| duty | ω (cnt/s) | Kg | canary |
|---|---|---|---|
| +0.10 | None | None | ✓ |
| +0.15 | None | None | ✓ |
| +0.20 | None | None | ✓ |
| +0.30 | 2158.0 | 7192.9 | ✓ |
| +0.40 | 2989.0 | 7471.7 | ✓ |
| +0.50 | 3751.0 | 7502.7 | ✓ |

### K(duty) eğrisi — reverse
| duty | ω (cnt/s) | Kg | canary |
|---|---|---|---|
| -0.10 | None | None | ✓ |
| -0.15 | None | None | ✓ |
| -0.20 | None | None | ✓ |
| -0.30 | -2113.0 | 7044.9 | ✓ |
| -0.40 | -2928.0 | 7321.1 | ✓ |
| -0.50 | -3706.0 | 7412.8 | ✓ |

## Flags / canary
✓ Dropout/freeze yok, ters-yön yok (0.5 cap güvenli).

## Artifacts
- meta.json · raw/stepid_{fwd,rev}_{base,step}.csv (τ ham veri)

## İlgili
- Plan: Faz 1 (onaylı) → Faz 2 analitik cascade (`matlab/asama_3_mimo_model/hp_cascade_design.m`) → Faz 3 firmware.
- Üreten: `scripts/hp_characterize.py`
