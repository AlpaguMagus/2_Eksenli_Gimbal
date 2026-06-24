# 3.K1-2axis — 2-eksen eşzamanlı decentralized cascade

- **Tarih:** 20260623_214543 · **Commit:** f2ce0b4 · **Durum:** PARTIAL
- **Hedef:** HP+LP aynı anda pozisyon cascade; her eksen kendi hedefini bağımsız izler mi (K1 milestone).
- **Donanım:** HP Motor1/HW-039 + LP Motor2/TB6612, iki mil serbest, mengeneli, loop 8ms.

## Sonuç
| seg | HP hedef | HP err | HP std | LP hedef | LP err | LP std |
|---|---|---|---|---|---|---|
| | +30° | 0.00° | 0.00° | -30° | 0.06° | 0.33° |
| | +90° | 2.44° | 0.19° | +45° | 0.44° | 0.36° |
| | +0° | 2.62° | 0.00° | +0° | 0.13° | 0.29° |
| | -45° | 2.45° | 8.52° | +60° | 0.23° | 0.14° |
| | +60° | 5.39° | 5.99° | -60° | 0.44° | 0.22° |
| | +0° | 2.28° | 6.05° | +0° | 0.00° | 0.00° |

- HP: 4/6 ss_err≤2.5° (max θ_std 8.52° — residual limit-cycle §12.13.4, K7'ye kadar yapısal)
- LP: 6/6 ss_err≤2.5° (max θ_std 0.36°, temiz)

## Yorum
Serbest mil → mekanik kuplaj ~0; iki cascade paralel koştu, her eksen bağımsız izledi → **K1 decentralized**.
Anlamlı kuplaj (RGA, K4) yüklü gimbalda (Aşama-5). HP limit-cycle K7 (Kalman) ile çözülür.

## Üreten: `scripts/k1_2axis_test.py`
