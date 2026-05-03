---
name: flash-test
description: STM32 firmware build + ST-Link flash + Python plot başlatma (test akışı)
disable-model-invocation: true
---

# flash-test

STM32F411 BlackPill firmware'ini derler, ST-Link üzerinden flash'lar ve gerçek zamanlı IMU plot scriptini başlatır.

## Akış

1. **Build** — `pio run` çalıştır.
   - Hata varsa burada dur, hatayı kullanıcıya net göster, sonraki adımlara geçme.

2. **Flash** — `pio run -t upload` ile ST-Link üzerinden yükle.
   - "Verified OK" görmeden devam etme.

3. **USB CDC enumeration için bekle:**
   ```bash
   sleep 3 && ls /dev/ttyACM* 2>/dev/null
   ```
   - `/dev/ttyACM0` gözükmüyorsa kullanıcıya: "Type-C bağlantısını kontrol et" de, dur.

4. **Plot başlat** — arka planda çalıştır:
   ```bash
   python3 plot_angles.py
   ```
   - `run_in_background: true` ile başlat ki kullanıcı plot ile etkileşime girebilsin.

## Notlar

- ST-Link bağlı olmalı (BlackPill SWD pinlerine).
- Type-C MPU6050'den veri akışı için bağlı olmalı.
- Plot 30 sn'de bir `screenshots/` klasörüne PNG kaydeder, maks 50 dosya.
