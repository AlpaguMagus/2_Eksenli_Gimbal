# Yüklü STAB + sürtünme-FF A/B (motor-2) — 20260613_215312

- **Tarih:** 2026-06-13 21:56 · **Commit:** `2e5d667` · **Durum:** FF_MIXED
- **Hedef:** ASIL amaç stabilizasyon — yük altında sürtünme FF düzeltmeleri pürüzsüzleştiriyor mu?
- **Yöntem:** MODE2:STAB, FF off/on/off/on dönüşümlü (10s/seg), el ile yavaş base eğme
- **⚠ Sınır:** IMU base'de (payload değil) → stabilizasyon YASASI demosu; inertial doğrulama Aşama 5. El-eğmesi tekrarlanamaz → yarı-nicel.

## Sonuç (FF kapalı vs açık, segmentler toplandı)

> Birincil metrikler: **takip-RMS** (θ−ref) + **norm-jerk** (jerk/hız — ham pürüzlülük eğme-hızıyla confound olduğu için hıza normalize). >0 Δ = FF iyileştirir.

| Durum | n | FP-aralık | takip-RMS | norm-jerk | ham-jerk | max\|hata\| |
|---|---|---|---|---|---|---|
| FF-OFF | 695 | 44.8° | 2.84° | 1.344 | 2.058 | 13.3° |
| FF-ON | 702 | 50.1° | 1.81° | 1.412 | 2.358 | 7.2° |

## Değerlendirme
FF açık vs kapalı (birincil metrikler): takip-RMS 2.84→1.81° (Δ+1.03°, >0=iyi), norm-jerk 1.344→1.412 (Δ-0.068, >0=pürüzsüz). max|hata| 13.3→7.2°. FF-ON eğme genliği 50° vs OFF 45° (daha zor koşul). ⚠ base-IMU yasa demosu; inertial doğrulama Aşama 5; el-eğmesi yarı-nicel.

## Artifacts
- raw/data.csv
- stab_ff_plot.png
