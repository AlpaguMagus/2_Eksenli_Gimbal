# 3.K4-coupling — serbest-mil off-diagonal (decentralized gerekçesi)

- **Tarih:** 20260623_210022 · **Commit:** af7048a · **Durum:** PASS
- **Hedef:** 2×2 G off-diagonal (kuplaj) serbest-milde ~0 mı → decentralized'ı SAYIYLA doğrula.
- **Yöntem:** bir ekseni POS 0'da aktif tut, diğerini ±0.4 duty sür, tutulan eksenin sapması = kuplaj.
- **Donanım:** HP+LP mengeneli, **serbest mil** (mekanik bağ yok), loop 8ms.

## Sonuç
| off-diagonal | Sürülen döndü | Tutulan saptı | Kuplaj |
|---|---|---|---|
| **G21** (LP←HP) | 1584.0° | 0.77° | 0.05% |
| **G12** (HP←LP) | 1839.4° | 0.0° | 0.0% |

## Yorum
Serbest mil → mekanik bağ yok → off-diagonal ~0 (decentralized cascade GEREKÇELİ). ⚠ **Anlamlı kuplaj
(RGA, decoupling kararı = K4'ün asıl payoff'u) YÜKLÜ gimbalda** (iki eksen mekanik bağlı, Aşama-5). Bu test
bağsız baseline'ı belgeler; gerçek MIMO ID yüklü montajda yapılır.

## Üreten: `scripts/k4_coupling_check.py`
