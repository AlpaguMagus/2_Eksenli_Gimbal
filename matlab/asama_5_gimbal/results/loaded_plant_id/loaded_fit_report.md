# Yüklü Plant Sistem-Tanımlama — Fit Raporu (Y0, ilk koşum)

- **Test ID:** 20260624_085025
- **Commit:** 491684c
- **Yöntem tasarımı + estimator doğrulama:** `matlab/asama_5_gimbal/loaded_plant_id_design.m` (sentetik PASS)
- **Bench yakalama:** `scripts/loaded_plant_id_capture.py` (B1 üçgen-rampa + B3 validasyon)
- **Fit:** `matlab/asama_5_gimbal/loaded_plant_id_fit.m`

## Plant

$$J\ddot\theta + b\dot\theta + \tau_c(\mathrm{yön})\,\mathrm{sign}(\dot\theta) + mgL\sin\theta = K_m u$$

θ = **θ_out (encoder, çıkış mili)**, dip-relatif (gravitasyonel-nötr asılı denge = θ=0).
⚠ **IMU (FP) base/şasi tarafında = "yasa-demosu" config** — motor θ_out'u döndürür, IMU görmez;
plant-ID θ_out ile yapılır, FP ayrı (ileride STAB bozucu-girişi).

## Sonuç (sayısal)

| Parametre | Değer | Durum |
|---|---|---|
| **a** (gravite, duty) | **0.23** | ✅ SOLID — 3-yol çapraz-doğrulama (B1 rampa 0.230; B3 0.20@64°→0.222; B3 −0.11@−29°→0.224) |
| **s+** (statik sürt. +, duty) | 0.059 | ⚠ yön solid, magnitüd tahmini |
| **s−** (statik sürt. −, duty) | 0.027 | ⚠ yön solid, magnitüd tahmini |
| asimetri s+/s− | 2.16 | ✅ yön solid |
| B1 fit R² | 0.963 | ✅ |
| ω_n (rad/s) | 4.0 | ⚠ PRIOR (bu-oturum free-decay ring-down yapmadı) |
| ζ | — | belirsiz |

> 📊 **Üreten betikler:** `loaded_plant_id_fit.m` (gerçek fit), `loaded_plant_id_design.m` (estimator doğrulama).
> Figürler: `real_fit_085025.png` (B1 histerezis fit), `estimator_synthetic_verify.png` (sentetik PASS).

## Bulgular / tartışma

1. **Sürtünme eski tek-açı ID'de FAZLA tahmin edilmişti** (0.09/0.05). Çok-açılı kopma + midpoint-vs-sinθ
   ayrıştırma graviteyi ($a\sin\theta$) sürtünmeden ayırdı → gerçek (düşük) sürtünme 0.06/0.03. Model-önce kazancı.
2. **Stick-slip + geniş statik-sürtünme bandı:** B3 duty=0.20 **+64°'de oturdu** (ascending-branch 38° değil) —
   açı momentumla bandın içine girip yüksekte takıldı (settle pozisyonu band-içinde tek-değer DEĞİL). Bu yüzden
   sürtünme magnitüdü band-scatter'ıyla belirsiz; **a** ise band-ORTASINDAN geldiği için sağlam.
3. **ω_n için free-decay zayıf:** yüksek stiction yerçekimi-restoring'i yenip serbest salınamıyor (bir kez
   salınıp takılıyor). Sürülen rejimde Coulomb overshoot'u söndürür → **driven-τ** (B3) daha kontrol-relevant.

## Açık konular (Y0 → Y0-rafine / Y1)

- [ ] **Sürtünme magnitüd precision:** yarı-statik **settled multi-açı adımlar** (rampa yerine) — band-ortası temiz ölçüm.
- [ ] **Fresh ω_n/ζ:** tek-büyük-bırakış temiz free-decay VEYA driven-τ (B3 transientlerinden).
- [ ] **IMU payload'a:** şu an base (yasa-demosu) → tam eylemsiz STAB validasyonu IMU payload'a taşınınca.

## Estimator güvenilirliği (sentetik, bench'ten önce)

`loaded_plant_id_design.m` bilinen-parametre → fit → geri-kurtar: **a −0.8%, s+ %0, s− +0.9% (R²=0.9998),
ω_n +0.3%, NRMSE 5.94%** → ayrıştırma matematiği + estimator DOĞRU; gerçek-veri belirsizliği plant'ın
stick-slip doğasından (estimator'dan değil).
