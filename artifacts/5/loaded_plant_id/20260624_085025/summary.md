# 5.loaded-plant-id — Y0 yüklü plant-ID veri-yakalama

- **Test ID:** 5.loaded-plant-id
- **Tarih:** 20260624_085025
- **Commit:** 4a7a901
- **Hedef:** Yüklü nonlineer plant için B1 (gravite+statik-sürtünme, üçgen-rampa histerezis) +
  B3 (validasyon adımları) ham verisi. Gravite/sürtünme ayrıştırma → `loaded_plant_id_design.m`.
- **Komut:** `python3 scripts/loaded_plant_id_capture.py`

## Sonuç
| Metric | Değer |
|---|---|
| DIP referans (fp/θ_out) | -12.7° / -21.6° |
| Örnek sayısı | 7591 |
| FP span | 44.6° |
| Durum | OK |

## Durum / gerekçe
`OK` — B1 histerezis + B3 validasyon ham verisi `raw/plantid.csv`'de. Gravite/sürtünme
ayrıştırma + ω_n/ζ (free-decay ayrı) + NRMSE → MATLAB. ABORTED ise |FP|>72/|θ|>80 güvenlik tetiklendi.

## Artifacts
- raw/plantid.csv  (phase,t,duty,fp,th_out,fp_rel,th_rel)
