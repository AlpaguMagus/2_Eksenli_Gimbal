# Aşama 2 — Anti-Windup Recovery (Test 2.T3, gerçek motor)

- **Test ID:** 20260528_203803
- **Tarih:** 2026-05-28 20:38
- **Commit:** `e2528e2`
- **Komut:** `python3 scripts/antiwindup_test.py --sp-high 450 --sp-low 50`
- **Kazanç:** Kp=0.002, Ki=0.1, slew=1000
- **Hedef:** anti-windup (firmware'de aktif) recovery'yi sim OFF (715 ms) altına indirir

## Sonuç

| Metric | Değer | Referans | Durum |
|---|---|---|---|
| recovery (450→50, ±20 rad/s band) | 637 ms | sim ON 235 / OFF 715 | ✓ |
| wind-up platosu | 274.3 rad/s | ~327 (max no-load) | — |

> Recovery bandı ±20 rad/s (~1 encoder count=18.7); ±%5 band kuantizasyonla imkansız.

## Durum: **PASS**

Gerçek recovery sim OFF'tan belirgin hızlıysa anti-windup gerçekte çalışıyor demektir (sim ON ile uyum → sim-to-real gap kapalı). Detay: docs/asama_2_kontrol.md §11.12.9.

## Artifacts
- `data.csv`
