# 3.HP-FF-compare — Coulomb-FF HP statik-offset'i azaltıyor mu

- **Tarih:** 20260623_210501 · **Commit:** 0fc1fe8 · **Hüküm:** Coulomb-FF HP statik-offset'i AZALTIYOR
- **Hedef:** K1'de HP 2/6 (hedefi ~6° aşıp stiction-hold). Coulomb-FF (yön-bağımlı 0.14/0.20) bu STATİK offset'i azaltır mı? (§12.13.4 FF'i limit-cycle için denemişti.)
- **Donanım:** HP serbest mil, mengeneli. ⚠ Gravite-FF KAPALI (LFFG:0; kff_grav=0.097 LP-placeholder serbest-milde yanlış). Yalnız Coulomb-FF.

## Sonuç
| HP hedef | err OFF | err ON | Δ | std OFF | std ON |
|---|---|---|---|---|---|
| +30° | 5.88° | 0.34° | -5.54° | 0.17° | 4.3° |
| +90° | 5.62° | 1.38° | -4.24° | 0.0° | 4.27° |
| -45° | 0.38° | 0.13° | -0.25° | 0.0° | 4.26° |
| +60° | 5.96° | 3.0° | -2.96° | 8.22° | 0.0° |
| +0° | 8.29° | 1.04° | -7.25° | 3.6° | 3.73° |

- **Ortalama ss_err:** FF-OFF 5.23° → FF-ON 1.18° (-4.05°)
- **Hüküm:** Coulomb-FF HP statik-offset'i AZALTIYOR

## Yorum
§12.13.4 FF'i LIMIT-CYCLE için denedi (çözmedi). Bu test STATİK-OFFSET'e etkisini ayırır. Coulomb-FF near-target stiction kırmaya yardım edip ss_err düşürdü.

## Üreten: `scripts/hp_ff_compare.py`
