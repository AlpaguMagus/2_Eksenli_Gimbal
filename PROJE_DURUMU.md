# 2 Eksenli Gimbal — Proje Durum Raporu
> Claude Code'a handoff belgesi

---

## DONANIM

| Bileşen | Model | Durum |
|---|---|---|
| MCU Kartı | WeAct Studio STM32F411CEU6 (BlackPill) | ✅ Flash edildi, çalışıyor |
| IMU | MPU6050 | ⏳ Breadboard'da, I2C henüz test edilmedi |
| Programlayıcı | ST-Link V2 (20-pin JTAG tipi) | ✅ Çalışıyor |
| Bağlantı | Type-C (güç + ileride USB CDC) | ⏳ CDC henüz aktive edilmedi |

### ST-Link → BlackPill Pin Bağlantısı
```
ST-Link VTref (pin 1) → BlackPill 3V3
ST-Link SWDIO (pin 7) → BlackPill DIO
ST-Link SWCLK (pin 9) → BlackPill CLK
ST-Link GND   (pin 8) → BlackPill GND
```

### MPU6050 → BlackPill Pin Bağlantısı (Breadboard)
```
MPU6050 VCC → BlackPill 3V3
MPU6050 GND → BlackPill GND
MPU6050 SCL → BlackPill PB6  (I2C1_SCL)
MPU6050 SDA → BlackPill PB7  (I2C1_SDA)
```

---

## YAZILIM ORTAMI

| Araç | Versiyon | Açıklama |
|---|---|---|
| OS | Ubuntu (Linux) | alpagumagus@AlpaguMagus |
| IDE | Google Antigravity | VS Code fork, kod editörü |
| AI Kodlayıcı | Claude Code | Terminal tabanlı, ana geliştirici |
| Build/Flash | PlatformIO Core CLI 6.1.19 | pipx ile kuruldu |
| Framework | STM32Cube (HAL) | stm32cube, baremetal |
| Debug | OpenOCD + ST-Link | pio ile entegre |

### Proje Dizini
```
~/workspace/2_Eksenli_Gimbal/
├── src/
│   └── main.c          ← firmware buraya
├── include/
├── lib/
└── platformio.ini      ← build konfigürasyonu
```

### platformio.ini (mevcut)
```ini
[env:blackpill_f411ce]
platform = ststm32
board = blackpill_f411ce
framework = stm32cube
upload_protocol = stlink
debug_tool = stlink
monitor_speed = 115200
```

### Temel Komutlar
```bash
cd ~/workspace/2_Eksenli_Gimbal

pio run              # build
pio run -t upload    # ST-Link ile flash
pio device monitor   # seri port izle (CDC aktif olunca)
```

---

## NE YAPILDI

### ✅ Tamamlanan Adımlar

1. **Linux USB tanıma** — ST-Link V2 (0483:3748) görünür hale getirildi
2. **udev kuralları** — PlatformIO udev rules kuruldu, kullanıcı dialout+plugdev grubuna eklendi
3. **PlatformIO CLI** — pipx ile kuruldu, sistem Python'ına dokunulmadı
4. **Proje iskeleti** — `pio init --board blackpill_f411ce` ile oluşturuldu, tüm toolchain indirildi
5. **STM32Cube framework** — stm32cube + ST-Link konfigürasyonu yapıldı
6. **Blink testi** — PC13 LED 500ms yanıp sönen firmware yazıldı, build edildi, flash edildi → **DOĞRULANDI**

### ⏳ Yapılmamış / Sıradaki Adımlar

1. **I2C + MPU6050 okuma** — Ham ivme ve gyro verisi okuma (öncelik #1)
2. **UART/USB CDC** — Verinin PC'ye gönderilmesi
   - Seçenek A: Type-C üzerinden USB CDC (Virtual COM Port) — ayrı dönüştürücü gerekmez
   - Seçenek B: UART1 (PA9/PA10) + harici USB-TTL dönüştürücü
3. **Complementary Filter** — Gyro + accelerometer füzyonu, açı hesabı
4. **Python tarafı** — PC'de gerçek zamanlı veri okuma + görselleştirme
5. **PID kontrolcü** — Motor sürme (motor henüz bağlı değil)

---

## PROJE HEDEFİ

2 eksenli gimbal stabilizasyon sistemi:

```
[MPU6050 - Harici IMU]         [MPU6050 - Dahili IMU]
Platform hareketini ölçer       Kamera açısını ölçer
(feedforward)                   (feedback)
         ↓                              ↓
    [STM32F411]  ←——— Complementary Filter ———→  [PID Kontrolcü]
         ↓
    [BLDC Motor Sürücü]
         ↓
    [Gimbal Motoru]
```

**Sensor Füzyon Algoritması:**
```
θ_fused = α × (θ_fused_prev + gyro × dt) + (1-α) × θ_accel
α ≈ 0.98  (gyro'ya %98, accel'e %2 ağırlık)
```

---

## HEMEN YAPILACAK (Sıradaki Oturum)

**Hedef:** MPU6050'den I2C üzerinden ham veri okuyup UART ile PC'ye göndermek.

**Adımlar:**
1. `src/main.c` içine I2C1 init + MPU6050 register okuma kodu yaz
2. UART2 (PA2/PA3) veya USB CDC init ekle
3. `pio run -t upload` ile flash'la
4. `pio device monitor` veya Python script ile veriyi gör

**MPU6050 I2C Adresi:** `0x68` (AD0 pini GND'ye bağlıysa)

**Okunacak Register'lar:**
```
0x3B → ACCEL_XOUT_H
0x3C → ACCEL_XOUT_L
0x3D → ACCEL_YOUT_H
0x3E → ACCEL_YOUT_L
0x43 → GYRO_XOUT_H
0x44 → GYRO_XOUT_L
0x45 → GYRO_YOUT_H
0x46 → GYRO_YOUT_L
0x6B → PWR_MGMT_1  (0x00 yaz → uyku modundan çıkar)
```
