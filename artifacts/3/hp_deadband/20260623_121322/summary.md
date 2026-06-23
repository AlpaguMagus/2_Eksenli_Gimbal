# 3.HP-deadband — statik kopma vs kinetik dropout

- **Tarih:** 20260623_121322 · **Commit:** faba92f · **Durum:** PASS
- **Hedef:** HP dead-band'ı ayır — statik kopma (breakaway/stiction) vs kinetik dropout (Coulomb). Cascade dead-band telafisi + stick-slip risk değerlendirmesi.
- **Donanım:** HP HW-039, mil serbest, duty cap 0.5.

## Sonuç
| | fwd | rev |
|---|---|---|
| **Statik kopma** (breakaway) | 0.21 | 0.22 |
| **Kinetik dropout** (sustain min) | 0.14 | 0.2 |
| stiction/kinetik oranı | 1.5× | 1.1× |

## Yorum
Statik ≫ kinetik → stick-slip eğilimi (kopma için yüksek duty, dönerken düşük yeter). Cascade'de
dead-band telafisi statik değil **kinetik** değere göre (sürekli rejimde Coulomb hakim); başlangıç
kopması için kick/integral gerekir. Detay → Faz 2 cascade tasarımı.

## Üreten: `scripts/hp_deadband.py`
