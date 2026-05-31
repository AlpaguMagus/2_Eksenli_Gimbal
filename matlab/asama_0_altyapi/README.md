# Aşama 0 — Altyapı (IMU + complementary filter, MATLAB analiz)

> **Amaç:** IMU (MPU6050) statik gürültü karakterizasyonu (Allan variance) ve
> complementary filter tasarımı/görselleştirmesi. Derin anlatı →
> [`../../docs/asama_0_altyapi.md`](../../docs/asama_0_altyapi.md).

---

## Scriptler

| Script | Amaç | Girdi | Çıktı |
|---|---|---|---|
| `analyze_allan_variance.m` | Allan deviation → ARW + bias instability → optimal complementary $\alpha$ | `artifacts/0/imu_noise/<id>/raw/data.csv[.gz]` | `results/allan_deviation.png`, `allan_result.json` |
| `create_filter_diagram.m` | Complementary filter blok diyagramı + Bode (frekans ayrımı) | filtre $\alpha$ | `results/complementary_filter_*.png` |

## Çıktılar (`results/`, git'te)

| Dosya | İçerik |
|---|---|
| `allan_deviation.png` | Allan sapması log-log ($\tau$ vs $\sigma$), ARW/bias-instability eğimleri |
| `allan_result.json` | Sayısal: ARW, bias instability, optimal $\alpha$ (firmware'e transfer) |
| `complementary_filter_blockdiagram.png` | Filter blok diyagramı (gyro entegrasyon + ivmeölçer düşük-geçiren) |
| `complementary_filter_bode.png` | Yüksek/düşük-geçiren frekans ayrımı (tamamlayıcı karakteristik) |

## İkili iş akışı (firmware → MATLAB)

```
scripts/imu_noise_log.py   (firmware, 15-30 dk statik log, MOTORSUZ)
         │  artifacts/0/imu_noise/<test_id>/raw/data.csv[.gz]
         ▼
analyze_allan_variance.m   → optimal complementary α → firmware (src/imu.c)
```

> 📊 Görseller `docs/asama_0_altyapi.md`'de embed edilir. **Karıştırma:** Allan log
> aracı (`imu_noise_log.py`) statik/motorsuz veri toplar; canlı IMU izleme için
> `plot_angles.py` (repo kökü, 5-panel canlı grafik) ayrı bir araçtır — rolleri farklı.
