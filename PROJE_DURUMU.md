# 2 Eksenli Gimbal — Proje Durum Raporu
> Claude Code'a handoff belgesi

---

## DONANIM

| Bileşen | Model | Durum |
|---|---|---|
| MCU Kartı | WeAct Studio STM32F411CEU6 (BlackPill V2.0) | ✅ Çalışıyor |
| IMU | MPU6050 6-DOF | ✅ I2C üzerinden okunuyor |
| Programlayıcı | ST-Link V2 (20-pin JTAG tipi) | ✅ Çalışıyor |
| Bağlantı | Type-C → USB CDC (Virtual COM Port) | ✅ Aktif |
| Motor sürücü | TB6612FNG modülü (Robotistan/Direnç) | ⏳ Plan onaylı, entegrasyon başlıyor |
| Motor | Pololu 25Dx63L LP 12V, 48 CPR enkoderli | ⏳ Plan onaylı, entegrasyon başlıyor |
| 12V kaynak | Mervesan 12V/3A 36W duvar adaptörü | ⏳ Hazırlanacak (sigorta planlı) |

### ST-Link → BlackPill Pin Bağlantısı (mevcut)
```
ST-Link VTref (pin 1) → BlackPill 3V3
ST-Link SWDIO (pin 7) → BlackPill DIO  (PA13)
ST-Link SWCLK (pin 9) → BlackPill CLK  (PA14)
ST-Link GND   (pin 8) → BlackPill GND
```

### MPU6050 → BlackPill Pin Bağlantısı (mevcut)
```
MPU6050 VCC → BlackPill 3V3
MPU6050 GND → BlackPill GND
MPU6050 SCL → BlackPill PB6   (I2C1_SCL)
MPU6050 SDA → BlackPill PB7   (I2C1_SDA)
```

### Pin Atama (Aşama 2 — onaylı plan)

| İşlev | Pin | Çevre birimi |
|---|---|---|
| I2C1 SCL | PB6 | I2C1_SCL |
| I2C1 SDA | PB7 | I2C1_SDA |
| USB DM | PA11 | OTG_FS_DM |
| USB DP | PA12 | OTG_FS_DP |
| LED | PC13 | GPIO |
| SWD IO / CLK | PA13 / PA14 | SWJ-DP |
| **Encoder A** | **PA15** | TIM2_CH1 (32-bit) |
| **Encoder B** | **PB3** | TIM2_CH2 (32-bit) |
| **Motor PWM** | **PB0** | TIM3_CH3 (20 kHz) |
| **AIN1 (yön)** | **PB12** | GPIO |
| **AIN2 (yön)** | **PB13** | GPIO |
| **STBY (enable)** | **PB14** | GPIO |

Pin seçim gerekçeleri ve datasheet referansları için → `README.md §8`.

### TB6612FNG → BlackPill / Motor Bağlantısı (planlanan)

```
TB6612 Vcc  ← BlackPill 3V3       (lojik beslemesi)
TB6612 VM   ← Mervesan 12V/3A     (motor beslemesi, sigorta planlı)
TB6612 GND  ↔ Ortak GND           (BlackPill + 12V kaynak yıldız topology)
TB6612 STBY ← BlackPill PB14
TB6612 AIN1 ← BlackPill PB12
TB6612 AIN2 ← BlackPill PB13
TB6612 PWMA ← BlackPill PB0       (TIM3_CH3, 20 kHz)
TB6612 AO1  → Motor +              (kırmızı kablo)
TB6612 AO2  → Motor -              (siyah kablo)
```

### Pololu Enkoder Bağlantısı (planlanan)

```
Encoder Vcc  ← BlackPill 5V       (mavi kablo, datasheet min 3.5V → 5V'tan beslenir)
Encoder GND  ↔ Ortak GND          (yeşil kablo)
Encoder A    → BlackPill PA15     (sarı kablo, 5V tolerant FT pin)
Encoder B    → BlackPill PB3      (beyaz kablo, 5V tolerant FT pin)
```

> Pololu enkoder çıkış tipi (push-pull / open-collector) datasheet'te net değil. STM32 internal `GPIO_PULLUP` aktif edilecek (emniyet payı).

---

## YAZILIM ORTAMI

| Araç | Versiyon | Açıklama |
|---|---|---|
| OS | Ubuntu (Linux) | alpagumagus@AlpaguMagus |
| IDE | Google Antigravity | VS Code fork |
| AI Kodlayıcı | Claude Code | Terminal tabanlı |
| Build/Flash | PlatformIO Core CLI 6.1.19 | pipx kurulum |
| Framework | STM32Cube (HAL) | baremetal |
| Debug | OpenOCD + ST-Link | pio entegre |

### Proje Dizini

```
~/workspace/2_Eksenli_Gimbal/
├── src/
│   ├── main.c            ← firmware ana giriş
│   ├── usbd_cdc_if.c     ← USB CDC arayüzü
│   ├── usbd_conf.c       ← USB HAL konfigürasyonu
│   └── usbd_desc.c       ← USB cihaz descriptor'ları
├── include/
│   ├── usbd_cdc_if.h
│   ├── usbd_conf.h
│   └── usbd_desc.h
├── datasheets/           ← Donanım PDF/şematik belgeleri
├── platformio.ini        ← build konfigürasyonu
├── add_usb_middleware.py ← USB CDC middleware build scripti
├── plot_angles.py        ← PC tarafı, gerçek zamanlı grafik
├── screenshots/          ← otomatik kaydedilen IMU PNG'leri (gitignored)
├── PROJE_DURUMU.md       ← bu dosya
└── README.md             ← teknik rapor
```

> Aşama 2'de `src/encoder.c`, `src/motor.c` ve karşılık gelen header'lar eklenecek.

### Temel Komutlar
```bash
cd ~/workspace/2_Eksenli_Gimbal

pio run                                          # build
pio run -t upload                                # ST-Link ile flash
pio device monitor --port /dev/ttyACM0          # USB CDC izle (115200)
python3 plot_angles.py /dev/ttyACM0             # gerçek zamanlı grafik
```

---

## NE YAPILDI

### ✅ Aşama 1 — IMU Füzyon ve Veri İletimi (tamamlandı, `main` branch)

1. **PlatformIO altyapısı** — pipx ile CLI, stm32cube framework, ST-Link integrate
2. **Blink testi** — PC13 LED 500ms doğrulama
3. **I2C1 + MPU6050** — PB6/PB7 üzerinden ham accel/gyro okuma
4. **USB CDC (Virtual COM Port)** — Type-C üzerinden 115200 baud veri
5. **Açı hesabı** — `atan2` ile pitch ve roll
6. **Complementary filter** — α=0.98, gyro işaret kalibrasyonu (pitch=−gy, roll=+gx)
7. **Python görselleştirme** — matplotlib, 4 panel (ham + füzyon), 30s screenshot, max 50 PNG

**Bilinen sınırlama:** ±90° singülarite. Madgwick veya quaternion ile çözülebilir, şu an demo için yeterli.

---

## ŞU ANKİ AŞAMA — AŞAMA 2

### 🟡 Tek Motor + Encoder + IMU Stabilizasyon Demosu

**Branch:** `feature/motor-encoder-tb6612`

**Plan onaylı, donanım entegrasyonu başlıyor.**

### Yapılacaklar (sıralı)

#### A — Dokümantasyon güncellemesi ✅
- [x] Pololu 25D LP datasheet inceleme — stall akımı 1.6 A doğrulandı
- [x] README §8 yeni bölüm: motor sürücü ve encoder mimarisi
- [x] Sistem diyagramı, pin tablosu, akım/güç bütçesi, decoupling notları

#### B — Kod İskeleti (henüz implementasyon yok, BUİLD edilebilir olmalı)
- [ ] `src/encoder.c` + `include/encoder.h` — TIM2 enkoder API (init + count okuma)
- [ ] `src/motor.c` + `include/motor.h` — TB6612 sürücü API (set_duty, set_dir, soft-start, brake, stop, standby)
- [ ] `src/main.c` güncellenmiş init sırası:
  1. HAL_Init
  2. SystemClock_Config
  3. I2C1_Init
  4. MPU6050_Init
  5. Encoder_Init (TIM2)
  6. Motor_Init (TIM3 + GPIO, STBY=LOW)
  7. USB CDC init
  8. HAL_Delay(2000)
  9. **Motor_Enable() → STBY=HIGH (en son)**

> Skeleton commit'i build edilebilir olacak (linker hatasız), TODO yorumlarla implementasyon boş kalacak.

#### C — Implementasyon (skeleton onayından sonra, küçük commit'lerle)
- [ ] Encoder TIM2 init implementasyon
- [ ] Encoder count okuma + hız hesabı (rad/s)
- [ ] Motor TIM3 PWM init implementasyon
- [ ] TB6612 sürücü API — set_duty, set_dir, soft-start
- [ ] main.c entegrasyon — IMU veri + encoder count + motor PWM döngüsü
- [ ] USB CDC çıktıya encoder/motor verisi ekleme

#### D — Test ve Doğrulama
- [ ] Encoder count'un mekanik dönüşle doğrulanması (1 tam motor turu = 192 olay × 9.7 = ~1862 olay)
- [ ] PWM frekansının osiloskopla doğrulanması (20 kHz @ PB0)
- [ ] Yön kontrolü (AIN1/AIN2 ile CW/CCW)
- [ ] Soft-start tepkisi (200ms rampa)
- [ ] Stall davranışı (1.5 A PSU akım sınırına temas)

#### E — Kontrol Döngüsü (İleri Aşama)
- [ ] Sistem tanımlama scripti (Python, Vsat düzeltmeli)
- [ ] PID kazanç ayarı
- [ ] IMU pitch/roll hatasını motor PWM'e haritalama (1 eksen demo)

---

## PROJE HEDEFİ (Uzun Vadeli)

2 eksenli gimbal stabilizasyon sistemi:

```
[MPU6050 - Harici IMU]         [MPU6050 - Dahili IMU]
Platform hareketini ölçer       Kamera açısını ölçer
(feedforward)                   (feedback)
         ↓                              ↓
    [STM32F411]  ←——— Complementary Filter ———→  [PID Kontrolcü]
         ↓
    [TB6612FNG × 2 (her eksen için)]
         ↓
    [Pololu 25D × 2 (pitch + roll motorları)]
```

Aşama 2 demosu (şu anki) bu mimarinin tek motor + tek IMU ile mini doğrulamasıdır.

---

## REFERANSLAR

- **Donanım datasheet'leri**: `datasheets/` klasörü
- **Datasheet okuma**: `~/.claude/skills/datasheet-reader/render` (PyMuPDF + vision)
- **Donanım belgeleri** (link): WeAct GitHub, STM32-Base — README.md §Referanslar
