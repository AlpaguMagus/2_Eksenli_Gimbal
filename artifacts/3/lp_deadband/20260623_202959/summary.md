# 3.LP-deadband — statik kopma vs kinetik dropout

- **Tarih:** 20260623_202959 · **Commit:** df989e7 · **Durum:** PASS
- **Hedef:** LP dead-band'ı ayır — statik kopma (breakaway/stiction) vs kinetik dropout (Coulomb). Eski Aşama-1 LP modeliyle kıyas + cascade dead-band telafisi.
- **Donanım:** LP Motor2/TB6612/9.7:1, mil serbest, mengeneli, duty cap 0.5.

## Sonuç
| | fwd | rev |
|---|---|---|
| **Statik kopma** (breakaway) | 0.08 | 0.08 |
| **Kinetik dropout** (sustain min) | 0.08 | 0.08 |
| stiction/kinetik oranı | 1.0× | 1.0× |

## Yorum
Statik ≫ kinetik → stick-slip eğilimi. HP rijit (§12.13.5: statik 0.22/0.25, kinetik 0.14/0.20) ile kıyasla.

## Üreten: `scripts/lp_deadband.py`
