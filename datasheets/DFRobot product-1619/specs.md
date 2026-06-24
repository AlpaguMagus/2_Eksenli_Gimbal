# DFRobot Metal DC Geared Motor w/Encoder — 6V 300RPM (FIT0520 / product-1619)

> **Kaynak:** dfrobot.com/product-1619.html (SKU **FIT0520**); WebFetch 2026-06-13.
> Çapraz-kontrol: core-electronics, robot-italy, utmel (FIT0520 datasheet PDF).

| Özellik | Değer |
|---|---|
| Model | Metal DC Geared Motor w/Encoder, 6V 300RPM 3.6 kg·cm (FIT0520) |
| **Nominal voltaj** | **6 V** (motor); enkoder besleme 3.3/5 V |
| Redüktör | 20:1 (efektif ~20.4) |
| Boşta hız (çıkış şaftı) | 300 RPM @ 6V |
| **Stall akımı** | **2.7 A @ 6V** |
| Stall tork | 3.6 kg·cm |
| Maks verim noktası | 0.4 A @ 245 RPM (0.7 kg·cm) |
| **Enkoder** | Entegre kuadratür; **44 sayım/dev motor şaftı** (11 PPR × 4) → **224.4 PPR çıkış** |
| Şaft / gövde | 4 mm D-şaft, 8 mm; gövde 50 × Φ24.4 mm; 96 g; JST 6-pin |

## ⚠ Bu projeye uyumsuzluk riskleri

Mevcut firmware + Aşama-1 karakterizasyonu **12V Pololu + 48 CPR** üzerine kurulu. FIT0520:
1. **6 V nominal** (12V değil) → 12V besleme doğrudan motoru yakar; LM2596 ile ~6V'a düşürme veya sıkı duty-sınırı gerekir.
2. **Enkoder 48 CPR DEĞİL** — motor şaftı 44 sayım/dev (çıkış 224.4 PPR) → `encoder.h` CPR/466 sabitleri + ölçek + karakterizasyon yeniden gerekir.
3. **Pololu 25D gearbox uyumu DOĞRULANMADI** — DFRobot kendi 20:1 entegre redüktörlü ünitesi (4mm D-şaft çıkış); Pololu 25D gearbox bu motora takılmayabilir (fiziksel uyumu varsayma).

**Sonuç:** Gimbal'in 2-eksen çözümünde **birincil aday DEĞİL** (6V + farklı enkoder + gearbox belirsiz). İleride farklı bir alt-sistem / 3.+ eksen için saklanabilir.
