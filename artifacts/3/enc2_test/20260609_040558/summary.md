# 3.2a — Encoder-2 elle-çevir doğrulaması

- **Test ID:** 3.2a-enc2
- **Tarih:** 2026-06-09 04:05
- **Commit:** `f8cc6fd`
- **Hedef:** Encoder-2 (TIM1, PA8/PA9, 16-bit→yazılım 32-bit) sayıyor mu + kablolama (sarı→PA8, beyaz→PA9) doğru mu + motor-1 izolasyonu
- **Komut:** elle mil çevirme, EC2 telemetri (motorsuz, sıfır risk)

## Sonuç (sayısal)
| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| EC2 değişim aralığı | 4843 count (çift yön) | >5 | ✓ |
| 16-bit wrap artefaktı | yok (−5662'ye ulaştı) | yok | ✓ |
| EC (motor-1) çapraz-konuşma | 0 (sabit) | ≈0 | ✓ |

## PASS — encoder-2 donanım+firmware doğru, izolasyon temiz.

## Açık not
IMU I2C rebuild sonrası BUSY (IMUDIAG rc2) — encoder-2'den bağımsız, ayrı ele alınacak.

## Artifacts
- raw/enc2_hand_turn.log
