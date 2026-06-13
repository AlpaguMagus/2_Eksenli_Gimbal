# Yüklü tek-motor ID (motor-2, sarkaç) — 20260613_loaded_id_run1

- **Tarih:** 2026-06-13 05:01 · **Commit:** `2bf0b08`
- **Yük:** orijinal son kol + boş telefon-standı (telefon yok), dibe asılı sarkaç
- **Yöntem:** açık-döngü yavaş duty-rampası 0→0.15 (18s) + θ-kesme 60°

## Sonuç (model: u = u_coulomb + (mgL/K)·sinθ)
- Maks açı: 45.6°
- **Stiction breakaway: 0.107 duty** (dipten kopuş, θ küçük → gravite~0, ≈ saf statik sürtünme)
- **Coulomb sürtünme u_c = 0.090 duty** · gravite a=mgL/K = **0.097 duty** (R²=0.607, n=270)
- Yatay(90°) toplam holding ≈ 0.187 duty ✓ <0.5; 35° çapraz-kontrol model 0.146 vs cascade ölçüm ~0.15
- **KÖK NEDEN:** Coulomb sürtünme (0.090) ≥ gravite katkısı → stick-slip → serbest-mil cascade kazançları yük altında limit-cycle veriyor. Çözüm: sürtünme+gravite feedforward (sonraki adım).

## Artifacts
- raw/data.csv
- loaded_id_plot.png
