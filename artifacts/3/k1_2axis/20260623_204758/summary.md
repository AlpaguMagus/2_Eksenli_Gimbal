# 3.K1-2axis — 2-eksen eşzamanlı decentralized cascade

- **Tarih:** 20260623_204758 · **Commit:** f751feb · **Durum:** PARTIAL
- **Hedef:** HP+LP aynı anda pozisyon cascade; her eksen kendi hedefini bağımsız izler mi (K1 milestone).
- **Donanım:** HP Motor1/HW-039 + LP Motor2/TB6612, iki mil serbest, mengeneli, loop 8ms.

## Sonuç
| seg | HP hedef | HP err | HP std | LP hedef | LP err | LP std |
|---|---|---|---|---|---|---|
| | +30° | 5.82° | 0.19° | -30° | 0.23° | 0.39° |
| | +90° | 10.29° | 4.23° | +45° | 0.19° | 0.00° |
| | +0° | 0.00° | 0.00° | +0° | 0.26° | 0.36° |
| | -45° | 6.25° | 0.18° | +60° | 0.21° | 0.69° |
| | +60° | 5.70° | 8.34° | -60° | 0.60° | 0.24° |
| | +0° | 2.41° | 0.19° | +0° | 0.77° | 0.00° |

- HP: 2/6 ss_err≤2.5° (max θ_std 8.34° — residual limit-cycle §12.13.4, K7'ye kadar yapısal)
- LP: 6/6 ss_err≤2.5° (max θ_std 0.69°, temiz)

## Yorum
Serbest mil → mekanik kuplaj ~0; iki cascade paralel koştu, her eksen bağımsız izledi → **K1 decentralized**.
Anlamlı kuplaj (RGA, K4) yüklü gimbalda (Aşama-5). HP limit-cycle K7 (Kalman) ile çözülür.

## Üreten: `scripts/k1_2axis_test.py`
