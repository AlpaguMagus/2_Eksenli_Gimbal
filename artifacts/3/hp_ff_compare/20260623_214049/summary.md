# 3.HP-FF-compare — Coulomb-FF HP statik-offset'i azaltıyor mu

- **Tarih:** 20260623_214049 · **Commit:** f2ce0b4 · **Hüküm:** Coulomb-FF HP statik-offset'i AZALTIYOR
- **Hedef:** K1'de HP 2/6 (hedefi ~6° aşıp stiction-hold). Coulomb-FF (yön-bağımlı 0.14/0.20) bu STATİK offset'i azaltır mı? (§12.13.4 FF'i limit-cycle için denemişti.)
- **Donanım:** HP serbest mil, mengeneli. ⚠ Gravite-FF KAPALI (LFFG:0; kff_grav=0.097 LP-placeholder serbest-milde yanlış). Yalnız Coulomb-FF.

## Sonuç
| HP hedef | err OFF | err ON | Δ | std OFF | std ON |
|---|---|---|---|---|---|
| +30° | 2.47° | 0.22° | -2.25° | 0.18° | 6.7° |
| +90° | 2.49° | 0.78° | -1.71° | 0.18° | 6.42° |
| -45° | 2.99° | 0.97° | -2.02° | 0.06° | 5.29° |
| +60° | 0.51° | 3.01° | +2.50° | 5.66° | 0.18° |
| +0° | 2.61° | 0.23° | -2.38° | 0.08° | 6.08° |

- **Ortalama ss_err:** FF-OFF 2.21° → FF-ON 1.04° (-1.17°)
- **Hüküm:** Coulomb-FF HP statik-offset'i AZALTIYOR

## Yorum
§12.13.4 FF'i LIMIT-CYCLE için denedi (çözmedi). Bu test STATİK-OFFSET'e etkisini ayırır. Coulomb-FF near-target stiction kırmaya yardım edip ss_err düşürdü.

## Üreten: `scripts/hp_ff_compare.py`
