# 2 Eksenli Gimbal — Teknik Rapor

> **Platform:** STM32F411CEU6 (WeAct BlackPill V2.0)  
> **Sensör:** MPU6050 6-DOF IMU  
> **Mimari:** Bare-metal, STM32Cube HAL  
> **Build Sistemi:** PlatformIO  

---

## İçindekiler

1. [Sistem Mimarisi](#1-sistem-mimarisi)
2. [STM32 Gömülü Yazılım Altyapısı](#2-stm32-gömülü-yazılım-altyapısı)
3. [MPU6050 Sensör Arayüzü](#3-mpu6050-sensör-arayüzü)
4. [Sensör Verilerinin Matematiksel Temeli](#4-sensör-verilerinin-matematiksel-temeli)
5. [Complementary Filter — Sensör Füzyonu](#5-complementary-filter--sensör-füzyonu)
6. [±90° Singülarite Problemi](#6-90-singülarite-problemi)
7. [Veri İletimi ve Görselleştirme](#7-veri-iletimi-ve-görselleştirme)
8. [Motor Sürücü ve Encoder Entegrasyonu](#8-motor-sürücü-ve-encoder-entegrasyonu)
9. [Derleme ve Flash İşlemleri](#9-derleme-ve-flash-işlemleri)

---

## 1. Sistem Mimarisi

```
┌──────────────────────────────────────────────────────────────────────┐
│                        STM32F411CEU6                                 │
│                                                                      │
│  ┌──────────┐  I2C1   ┌───────────┐                                  │
│  │          │◄───────►│  MPU6050  │  açı/açısal hız sensörü          │
│  │          │ PB6/PB7 │  6-DOF    │                                  │
│  │   ARM    │         └───────────┘                                  │
│  │ Cortex-M4│                                                        │
│  │  96 MHz  │  TIM2    ┌──────────────────────┐                      │
│  │          │◄═════════│ Pololu 25D Encoder   │ 48 CPR kuadratür     │
│  │          │ PA15/PB3 │ (5V besleme)         │                      │
│  │          │          └──────────────────────┘                      │
│  │          │                                                        │
│  │          │  TIM3    ┌────────────┐  PWM   ┌──────────────┐        │
│  │          │═════════►│            │═══════►│              │        │
│  │          │ PB0      │  TB6612FNG │ AO1/2  │  Pololu 25D  │        │
│  │          │  GPIO    │   motor    │═══════►│  12V motor   │        │
│  │          │═════════►│  driver    │        └──────────────┘        │
│  │          │ PB12-14  │            │           ▲                    │
│  │          │ AIN1/2   │            │  VM 12V ──┤ (Mervesan 12V/3A)     │
│  │          │ STBY     └────────────┘                                │
│  │          │                                                        │
│  │          │ ──── USB CDC (Type-C) ────► PC (/dev/ttyACM0)          │
│  │          │ ──── PC13 ────► LED (durum)                            │
│  └──────────┘                                                        │
└──────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │   PC (Linux/Python)   │
                    │   matplotlib ile      │
                    │   gerçek zamanlı      │
                    │   görselleştirme      │
                    └───────────────────────┘
```

Sistem, işletim sistemi (RTOS) kullanmayan **bare-metal** bir gömülü yazılım mimarisi üzerine kuruludur. Ana döngü (`while(1)`) super-loop modeli ile çalışır: sensör oku → filtrele → USB'den gönder → tekrarla. Bu yaklaşım, düşük gecikme (latency) ve deterministik zamanlama sağlar.

---

## 2. STM32 Gömülü Yazılım Altyapısı

### 2.1. Başlatma Sırası (Boot Sequence)

Firmware, reset vektöründen itibaren aşağıdaki sırayı takip eder:

```
Reset Handler (startup_stm32f411xe.s)
  │
  ├─► HAL_Init()              → SysTick 1 ms, NVIC öncelik grubu
  ├─► SystemClock_Config()     → HSE → PLL → 96 MHz SYSCLK
  ├─► I2C1_Init()              → PB6/PB7, 100 kHz standart mod
  ├─► GPIO Init (PC13)         → LED çıkışı
  ├─► USB CDC Init             → Virtual COM Port başlatma
  ├─► HAL_Delay(2000)          → Host USB enumerasyonu bekleme
  ├─► MPU6050_Init()           → Uyku modundan çıkarma
  │
  └─► while(1) — Ana Döngü
        ├─► MPU6050_Read()     → 14 byte burst I2C okuma
        ├─► dt hesabı          → HAL_GetTick() farkı
        ├─► İvmeölçer açısı    → atan2 hesabı
        ├─► Gyro hızı          → Ham değer / 131 LSB/(°/s)
        ├─► Complementary      → α·gyro + (1-α)·accel
        ├─► CDC_Transmit_FS()  → Veri gönder
        └─► HAL_Delay(50)      → ~20 Hz örnekleme
```

### 2.2. Saat Konfigürasyonu (Clock Tree)

STM32F411 dahili PLL kullanılarak harici kristalden (HSE) yüksek frekanslı sistem saati üretilir:

```
HSE (25 MHz)
  │
  ├─► PLLM = 25  →  VCO giriş = 1 MHz
  ├─► PLLN = 192 →  VCO çıkış = 192 MHz
  ├─► PLLP = 2   →  SYSCLK = 96 MHz
  └─► PLLQ = 4   →  USB CLK = 48 MHz  (USB 2.0 Full-Speed gereksinimi)
```

Bus hızları:
- **AHB** = 96 MHz (HCLK, DMA, çekirdek)
- **APB1** = 48 MHz (I2C1, Timer'lar — max 50 MHz)
- **APB2** = 96 MHz (SPI, USART1)

Flash erişim gecikmesi **LATENCY_3** (3 wait state) olarak ayarlanmıştır, çünkü HCLK > 90 MHz'de bu gereklidir (datasheet Table 6).

### 2.3. SysTick Zamanlayıcı

```c
void SysTick_Handler(void) {
    HAL_IncTick();   // Her 1 ms'de global tick sayacını artırır
}
```

`HAL_GetTick()` bu sayaca erişerek milisaniye cinsinden zaman ölçümü sağlar. Complementary filter'daki `dt` hesabı bu mekanizmaya dayanır.

### 2.4. I2C1 Perifer Konfigürasyonu

| Parametre | Değer | Açıklama |
|---|---|---|
| SCL Pini | PB6 (AF4) | Alternate Function: I2C1_SCL |
| SDA Pini | PB7 (AF4) | Alternate Function: I2C1_SDA |
| Mod | Open-Drain | I2C standardı gereği |
| Pull-up | Harici | Breadboard üzerinde 4.7kΩ |
| Clock Speed | 100 kHz | I2C Standard Mode |
| Adresleme | 7-bit | MPU6050 adresi: 0x68 |

I2C open-drain topolojisi, hat üzerinde birden fazla slave cihazın bulunmasına izin verir. Pull-up dirençleri hattı lojik 1'e (VCC) çeker; master veya slave hattı GND'ye çekerek lojik 0 oluşturur.

---

## 3. MPU6050 Sensör Arayüzü

### 3.1. Sensör Özellikleri

MPU6050, tek bir çip üzerinde **3 eksen ivmeölçer** ve **3 eksen jiroskop** barındıran bir MEMS (Micro-Electro-Mechanical Systems) IMU'dur.

| Özellik | İvmeölçer | Jiroskop |
|---|---|---|
| Eksen | X, Y, Z | X, Y, Z |
| Varsayılan Aralık | ±2g | ±250°/s |
| Hassasiyet | 16384 LSB/g | 131 LSB/(°/s) |
| Çözünürlük | 16-bit (signed) | 16-bit (signed) |
| Gürültü | ~400 µg/√Hz | ~0.005 °/s/√Hz |

### 3.2. Başlatma (Wake-up)

MPU6050, power-on sonrası varsayılan olarak **uyku modundadır** (PWR_MGMT_1 register'ının SLEEP biti 1'dir). Aktif hale getirmek için bu register'a 0x00 yazılır:

```c
uint8_t data = 0x00;
HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, 0x6B,   // PWR_MGMT_1
                  I2C_MEMADD_SIZE_8BIT, &data, 1, HAL_MAX_DELAY);
```

Bu komut dahili 8 MHz osilatörü etkinleştirir ve tüm sensör eksenlerini aktive eder.

### 3.3. Burst Okuma (14 Byte)

MPU6050, register `0x3B`'den itibaren ardışık 14 byte veri sunar:

```
Adres   Veri               Byte
0x3B    ACCEL_XOUT_H       [0]  ─┐
0x3C    ACCEL_XOUT_L       [1]  ─┘ ax = (int16_t)(raw[0] << 8 | raw[1])
0x3D    ACCEL_YOUT_H       [2]  ─┐
0x3E    ACCEL_YOUT_L       [3]  ─┘ ay = (int16_t)(raw[2] << 8 | raw[3])
0x3F    ACCEL_ZOUT_H       [4]  ─┐
0x40    ACCEL_ZOUT_L       [5]  ─┘ az = (int16_t)(raw[4] << 8 | raw[5])
0x41    TEMP_OUT_H          [6]  ─┐
0x42    TEMP_OUT_L          [7]  ─┘ (kullanılmıyor)
0x43    GYRO_XOUT_H        [8]  ─┐
0x44    GYRO_XOUT_L        [9]  ─┘ gx = (int16_t)(raw[8] << 8 | raw[9])
0x45    GYRO_YOUT_H        [10] ─┐
0x46    GYRO_YOUT_L        [11] ─┘ gy = (int16_t)(raw[10] << 8 | raw[11])
0x47    GYRO_ZOUT_H        [12] ─┐
0x48    GYRO_ZOUT_L        [13] ─┘ gz = (int16_t)(raw[12] << 8 | raw[13])
```

Tek bir I2C transaction ile 14 byte okunarak sensör verisinin tutarlılığı (tüm eksenler aynı anda örneklenir) ve bus verimliliği sağlanır.

---

## 4. Sensör Verilerinin Matematiksel Temeli

### 4.1. İvmeölçer (Accelerometer) — Statik Açı Ölçümü

İvmeölçer, yerçekimi vektörünü (g⃗) üç bileşenine ayırarak ölçer. Sensör düz durduğunda:

```
                    Z ↑ (az ≈ +1g = 16384 LSB)
                    │
                    │
     Y ◄────────────┼────────────► X
    (ay ≈ 0)        │              (ax ≈ 0)
```

Sensör eğildiğinde yerçekimi vektörü eksenlere farklı projeksiyon yapar. Pitch (öne-arkaya eğim) ve Roll (sağa-sola eğim) açıları şu formüllerle hesaplanır:

```
                    ax
pitch = atan2( ─────────────── ) × (180/π)
               √(ay² + az²)

                    ay
roll  = atan2( ─────────────── ) × (180/π)
               √(ax² + az²)
```

**Neden `atan2(x, √(y²+z²))` kullanılıyor?**

- Basit `atan(ax/az)` formülü `az = 0` olduğunda (sensör 90° eğik) sıfıra bölme hatası verir.
- `atan2` fonksiyonu dört kadranı da doğru çözer.
- Payda olarak `√(y²+z²)` kullanmak, diğer eksenin etkisini izole eder ve pitch-roll çapraz bağımlılığını (cross-coupling) azaltır.

**İvmeölçerin güçlü ve zayıf yönleri:**

| ✅ Güçlü | ❌ Zayıf |
|---|---|
| Uzun vadede kararlı (drift yok) | Titreşim ve lineer ivmeye duyarlı |
| Mutlak referans (yerçekimi) | Gürültülü çıkış (~400 µg/√Hz) |
| Ek kalibrasyon gerektirmez | Yalnız statik konumda doğru |

### 4.2. Jiroskop (Gyroscope) — Açısal Hız Ölçümü

Jiroskop, her eksen etrafındaki **açısal hızı** (°/s) ölçer. Ham dijital değerden fiziksel birime dönüşüm:

```
              ham_değer (LSB)
ω (°/s) = ─────────────────────
            131 LSB/(°/s)
```

Açısal hız, sayısal entegrasyon ile açıya dönüştürülür:

```
θ(t) = θ(t-1) + ω × Δt
```

Burada `Δt`, iki ölçüm arası geçen süredir (firmwaredeki `dt`, `HAL_GetTick()` farkından hesaplanır).

**Jiroskobun güçlü ve zayıf yönleri:**

| ✅ Güçlü | ❌ Zayıf |
|---|---|
| Gürültüsüz, düzgün çıkış | Entegrasyon drift'i (zamanla birikir) |
| Dinamik hareketlerde doğru | Mutlak referansı yok |
| Titreşimden etkilenmez | Sıcaklığa bağlı bias kayması |

### 4.3. Neden Tek Sensör Yeterli Değil?

İvmeölçer ve jiroskop **tamamlayıcı (complementary) frekans karakteristiklerine** sahiptir:

```
       Hata
        ▲
        │
        │   İvmeölçer                   Jiroskop
        │   (kısa vadede               (uzun vadede
        │    gürültülü)                  drift'li)
        │      ╲                        ╱
        │       ╲                      ╱
        │        ╲      Füzyon        ╱
        │         ╲    (minimum)     ╱
        │          ╲     hata       ╱
        │           ╲   ╱─────╲   ╱
        │            ╲╱         ╲╱
        └──────────────────────────────► Frekans
              Düşük              Yüksek
```

- **İvmeölçer:** Düşük frekanslarda (uzun vadede) doğru, yüksek frekanslarda (kısa süreli hareketler) gürültülü
- **Jiroskop:** Yüksek frekanslarda doğru, düşük frekanslarda (uzun dönemde) drift'e maruz

Bu iki sensörün avantajlı frekans bölgelerini birleştirmek için **sensör füzyonu** gereklidir.

---

## 5. Complementary Filter — Sensör Füzyonu

### 5.1. Temel Denklem

Complementary filter, bir **yüksek geçiren filtre** (gyro için) ile bir **alçak geçiren filtre** (accelerometer için) birleşiminden oluşur:

```
θ_fused = α × (θ_fused_prev + ω_gyro × Δt) + (1 - α) × θ_accel
          ├──────────── Gyro ────────────┤   ├── Accelerometer ──┤
          │    Yüksek geçiren filtre     │   │ Alçak geçiren     │
          │    (kısa vadeli değişim)     │   │ (uzun vadeli ref)  │
```

Firmwaredeki implementasyon:

```c
// α = 0.98 → Gyro'ya %98, ivmeölçere %2 ağırlık
fused_pitch = 0.98f * (fused_pitch - gy_dps * dt) + 0.02f * pitch;
fused_roll  = 0.98f * (fused_roll  + gx_dps * dt) + 0.02f * roll;
```

### 5.2. α Parametresinin Fiziksel Anlamı

`α` değeri, iki sensör arasındaki güven dengesini belirler:

| α Değeri | Gyro Ağırlığı | Accel Ağırlığı | Zaman Sabiti | Davranış |
|---|---|---|---|---|
| 0.99 | %99 | %1 | ~5 s | Çok düzgün, drift düzeltmesi yavaş |
| **0.98** | **%98** | **%2** | **~2.5 s** | **Dengeli (mevcut ayar)** |
| 0.95 | %95 | %5 | ~1 s | Accel gürültüsü belirginleşir |
| 0.80 | %80 | %20 | ~0.25 s | Accel'e çok bağımlı, gürültülü |

Zaman sabiti yaklaşık olarak: `τ ≈ Δt × α / (1 - α)`. Mevcut ayarda `τ ≈ 0.05 × 0.98 / 0.02 ≈ 2.45 s`, yani gyro drift'i yaklaşık 2.5 saniye içinde ivmeölçer referansına doğru düzeltilir.

### 5.3. Gyro Eksen İşaret Yönleri

MPU6050 datasheet'inde tanımlanan eksen yönleri, sensörün fiziksel montaj yönüne göre firmware'deki işaret seçimini belirler:

```c
fused_pitch = α * (fused_pitch - gy_dps * dt) + ...   // negatif: GY ekseni ters
fused_roll  = α * (fused_roll  + gx_dps * dt) + ...   // pozitif: GX ekseni doğru
```

İşaret seçimi (`+` veya `-`), sensörün breadboard üzerindeki montaj yönüne bağlıdır. MPU6050'nin sağ-el kuralı konvansiyonu ile fiziksel pitch/roll tanımınız farklı olabilir. **Bu, deneme-yanılma ile kalibre edilmesi gereken bir parametredir** — algorithmic bir hata değil, fiziksel referans çerçevesi eşleştirmesidir.

### 5.4. Δt (Zaman Adımı) Hesabı

```c
uint32_t now = HAL_GetTick();                         // ms cinsinden mevcut zaman
float dt = (now - last_tick) / 1000.0f;               // saniyeye çevir
if (dt <= 0.0f || dt > 0.5f) dt = 0.05f;              // koruma: ilk döngü veya overflow
last_tick = now;
```

`HAL_Delay(50)` ile her iterasyonda ~50 ms beklenir, bu da `dt ≈ 0.05 s` ve **~20 Hz örnekleme frekansı** verir. Overflow koruması, ilk döngüdeki sıfır `dt` veya aşırı büyük değerlerin filtreyi bozmasını engeller.

---

## 6. ±90° Singülarite Problemi

### 6.1. Problemin Kökeni

İvmeölçer tabanlı açı hesabında kullanılan formül:

```
                    ax
pitch = atan2( ─────────────── )
               √(ay² + az²)
```

Bu fonksiyonun **çıktı aralığı matematiksel olarak [-90°, +90°] ile sınırlıdır**.

### 6.2. Neden 90°'yi Geçemiyor?

Düz durumdan başlayarak sensörü pitch ekseninde çevirdiğimizde yerçekimi bileşenleri şöyle değişir:

```
Gerçek Açı    ax          az         √(ay²+az²)    atan2 Sonucu
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   0°          0        +16384       16384           0°
  30°        +8192      +14189       14189          +30°
  45°        +11585     +11585       11585          +45°
  60°        +14189      +8192        8192          +60°
  90°        +16384         0        ≈ 0            +90°  ← TEPE
 120°        +14189      −8192        8192          +60°  ← GERİ!
 150°        +8192      −14189       14189          +30°  ← GERİ!
 180°         ≈0        −16384       16384           ≈0°  ← SIFIR!
```

**Kritik Gözlem:** 90°'yi geçtikten sonra `az` negatif olur, ancak `√(ay²+az²)` ifadesinde **karesini alıp karekök alıyoruz**, bu nedenle işaret bilgisi kaybolur. Sonuç olarak:
- **120° gerçek açı → atan2 60° hesaplar**
- **150° gerçek açı → atan2 30° hesaplar**
- **180° gerçek açı → atan2 ~0° hesaplar**

Fonksiyon 90° sonrası adeta bir **ayna gibi** geri yansıtır.

### 6.3. Complementary Filter'a Etkisi

90° aşıldığında filter, çelişkili bilgi alır:

```
                    ┌─────────────┐
  Gyro (%98):       │ "105°'e      │──► Sonuç: Füzyon yavaşça
  "Dönmeye devam    │  gidiyoruz"  │    accel tarafına çekilir
   ediyorum"        │              │    ve saçmalar
                    │              │
  Accel (%2):       │ "75°'deyiz"  │──► θ_fused yavaş yavaş
  "Hayır, geri      │              │    gerçek değerden uzaklaşır
   geldin"          └──────────────┘
```

Her iterasyonda %2'lik ivmeölçer düzeltmesi **yanlış yöne** çeker. Kısa sürede etkisi az gibi görünür (gyro hala dominant), ama birkaç saniye sonra drift belirginleşir ve açı değeri tutarsız hale gelir.

### 6.4. Gimbal Lock ile İlişkisi

Bu problem, 3D rotasyonlarda **Euler açılarının doğuştan gelen singülarite problemi** olan "gimbal lock" ile ilişkilidir. Pitch ±90°'ye ulaştığında:

- Roll ve Yaw eksenleri aynı fiziksel ekseni temsil etmeye başlar
- Bir serbestlik derecesi kaybolur
- Açılar sürekli tanımsız (degenerate) hale gelir

### 6.5. Olası Çözümler

#### Çözüm 1: `atan2(ax, az)` Formülü (Basit)

```c
float pitch = atan2f(fax, faz) * RAD2DEG;   // Aralık: [-180°, +180°]
```

- ✅ ±180° aralık sağlar
- ❌ Pitch ±90° civarında roll hesabı bozulur (problemin yerini değiştirir)
- ❌ Küçük açılarda lineerlik azalır

#### Çözüm 2: Madgwick Filtresi (Quaternion Tabanlı)

```
Quaternion: q = [w, x, y, z]   (4 boyutlu birim vektör)

Güncelleme: q(t) = q(t-1) + (½ × q(t-1) ⊗ ω_gyro - β × ∇f) × Δt
                                │                      │
                        Gyro entegrasyonu     Gradient descent
                                              (accel düzeltmesi)

Euler'e dönüşüm:
  pitch = asin(2(wx - yz))
  roll  = atan2(2(wy + xz), 1 - 2(x² + y²))
  yaw   = atan2(2(wz + xy), 1 - 2(y² + z²))
```

- ✅ Singülarite sorunu yok (quaternion'larda gimbal lock olmaz)
- ✅ Tam 360° kapsam
- ✅ Drift düzeltmesi gradient descent ile optimize edilmiş
- ❌ Daha fazla hesaplama yükü (STM32F411 FPU ile sorun değil)
- ❌ Implementasyonu daha karmaşık

#### Çözüm 3: Mahony Filtresi (PI Kontrol Tabanlı)

Madgwick'e benzer quaternion tabanlı yaklaşım, ancak gradient descent yerine **PI kontrolcü** ile hata düzeltmesi yapar:

```
Hata = accel_measured × accel_estimated   (çapraz çarpım)
Gyro_düzeltilmiş = ω_gyro + Kp × Hata + Ki × ΣHata
q(t) = q(t-1) + ½ × q(t-1) ⊗ Gyro_düzeltilmiş × Δt
```

- ✅ Madgwick'ten hesaplama olarak daha hafif
- ✅ PI kazançları (Kp, Ki) sezgisel olarak ayarlanabilir
- ❌ Optimal olmayabilir (gradient descent gibi matematiksel garanti yok)

#### Karşılaştırma Tablosu

| Özellik | Complementary | Madgwick | Mahony |
|---|---|---|---|
| Çalışma aralığı | ±90° | 360° | 360° |
| Gimbal lock | Var | Yok | Yok |
| Hesaplama yükü | Çok düşük | Orta | Düşük-orta |
| Parametre sayısı | 1 (α) | 1 (β) | 2 (Kp, Ki) |
| Implementasyon | ~5 satır | ~50 satır | ~40 satır |
| Gimbal uygulaması | Yeterli (±45° aralık) | İdeal | İdeal |

### 6.6. Pratik Değerlendirme

Bir gimbal stabilizasyon sistemi genellikle **±30°—45°** aralığında çalışır. Mevcut complementary filter bu aralıkta mükemmel performans sergiler. ±90° sınırlaması, gerçek kullanım senaryosunda sorun yaratmaz. Ancak, ileri aşamada PID kontrolcü ve motor sürme eklendiğinde, sistemin sağlamlığı için quaternion tabanlı bir filtreye geçiş değerlendirilebilir.

---

## 7. Veri İletimi ve Görselleştirme

### 7.1. USB CDC (Virtual COM Port)

STM32F411'in dahili USB 2.0 Full-Speed perifer bloğu kullanılarak, ek donanım (UART-USB dönüştürücü) gerekmeden veri iletimi sağlanır. Linux tarafında `/dev/ttyACM0` olarak görünür.

Veri formatı (ASCII, her satır bir ölçüm):
```
P:<pitch>,R:<roll>,GX:<gyro_x>,GY:<gyro_y>,FP:<fused_pitch>,FR:<fused_roll>\r\n
```

Örnek:
```
P:12.3,R:-5.7,GX:1.2,GY:-0.8,FP:11.9,FR:-5.2
```

### 7.2. Python Görselleştirme (plot_angles.py)

`matplotlib.animation` kullanarak 4 panelli gerçek zamanlı grafik:

| Panel | İçerik | Renk |
|---|---|---|
| Sol üst | Pitch: Ham ivme + Füzyon | Mavi tonları |
| Sağ üst | Roll: Ham ivme + Füzyon | Yeşil/teal tonları |
| Sol alt | Gyro-X açısal hız (°/s) | Turuncu |
| Sağ alt | Gyro-Y açısal hız (°/s) | Pembe |

Her 30 saniyede bir `screenshots/` klasörüne PNG kaydedilir (maksimum 50 dosya).

---

## 8. Motor Sürücü ve Encoder Entegrasyonu

> **Aşama:** Plan onaylı, donanım entegrasyonu `feature/motor-encoder-tb6612` branch'inde.  
> **Hedef:** Tek motor + encoder + IMU stabilizasyon demosu.

### 8.1. Pin Atama Tablosu (donanım entegrasyonu)

Tüm pin seçimleri STM32F411 datasheet alternate function tablosuyla doğrulanmıştır. WeAct BlackPill V2.0 schematic'i incelenerek SPI flash footprint çakışmaları (PA4-PA7) elimine edilmiştir.

| İşlev | Pin | Çevre birimi | Dayanak |
|---|---|---|---|
| I2C1 SCL (MPU6050) | PB6 | I2C1 | mevcut |
| I2C1 SDA (MPU6050) | PB7 | I2C1 | mevcut |
| USB DM | PA11 | OTG_FS | mevcut |
| USB DP | PA12 | OTG_FS | mevcut |
| LED | PC13 | GPIO | mevcut |
| SWD IO / CLK | PA13 / PA14 | SWJ-DP | mevcut |
| **Encoder A** | **PA15** | TIM2_CH1 | RM0383 §23.3: SW-DP modunda JTDI serbest |
| **Encoder B** | **PB3** | TIM2_CH2 | RM0383 §23.3: SW-DP modunda JTDO serbest |
| **Motor PWM** | **PB0** | TIM3_CH3 | SPI flash footprint dışı (PA6/PA7'den kaçınıldı) |
| **AIN1 (yön)** | **PB12** | GPIO | TIM1_BKIN alternatifi kullanılmıyor |
| **AIN2 (yön)** | **PB13** | GPIO | TIM1_CH1N alternatifi kullanılmıyor |
| **STBY (enable)** | **PB14** | GPIO | TIM1_CH2N alternatifi kullanılmıyor |

**Kullanılmayan pinler (gerekçe):**
- **PA0** — KEY butonuna bağlı (BlackPill schematic).
- **PA4, PA5, PA6, PA7** — SPI flash footprint pinleri. Eğer flash chip lehimliyse çakışma riski var; bu pinlerden kaçınıldı.

### 8.2. Encoder — Pololu 25D 48 CPR

Datasheet (Pololu): kırmızı/siyah motor güç, **mavi = encoder Vcc 3.5V – 20V**, yeşil = encoder GND, sarı = A çıkışı, beyaz = B çıkışı.

| Parametre | Değer |
|---|---|
| Çözünürlük | 48 CPR (kuadratür, 4× decoding ile 192 olay/devir) |
| Dişli oranı | 9.7:1 |
| **Encoder Vcc** | **3.5 V minimum → BlackPill 5V pininden beslenir** |
| Encoder çıkış seviyesi | 5 V (Vcc'ye eşit, push-pull veya open-collector) |
| STM32 GPIO 5V toleransı | PA15 ve PB3 **FT (5V tolerant)** ✓ — direkt bağlanabilir |

**TIM2 32-bit counter:** STM32F411 datasheet sf 28: TIM2 ve TIM5 32-bit auto-reload sayaçlardır. 48 CPR × 4× decoding = 192 olay/motor devri; 9.7:1 redüktör = 1862 olay/çıkış mili devri. 32-bit ile ~2.3 milyon tam çıkış devri taşma sınırı — pratikte sınırsız.

**Pull-up:** Pololu enkoder çıkış tipi (push-pull / open-collector) datasheet'te net değil. Emniyet için **STM32 internal pull-up** (`GPIO_PULLUP`) aktif edilecek. Push-pull bile olsa pull-up zarar vermez (sadece akım kayıbı ihmal edilebilir düzeyde).

### 8.3. Motor Sürücü — TB6612FNG

TB6612FNG datasheet (sayfa 3, 5, 7) inceleme sonuçları:

| Parametre | Spec | Bizim ayar | Notlar |
|---|---|---|---|
| Vcc (lojik) | 2.7 V – 5.5 V | 3.3 V (BlackPill 3V3) | sf 3 |
| VM (motor) | 4.5 V – 13.5 V | 12 V (lab PSU) | sf 3 |
| VIH (control) | min Vcc×0.7 = 2.31 V @ 3.3V | STM32 GPIO 3.3V | uyumlu, sf 5 |
| Iout (sürekli) | 1.2 A | Stall 1.6 A (kısa süreli) | margin yeterli, lab PSU 1.5 A limit |
| Iout (peak) | 3.2 A | — | 10 ms tek darbe limit |
| **fPWM max** | **100 kHz** | **20 kHz** | sf 3 |
| Vsat | 0.5 V @ 1 A | — | sistem tanımlamada hesaba katılır |
| **Dead-time (donanım)** | 50 ns (H→L), 230 ns (L→H) | — | sf 4-5: yön değişiminde yazılım dead-band GEREK YOK |

**H-SW kontrol mantığı (datasheet sf 4):**

| AIN1 | AIN2 | PWM | STBY | Çıkış | Mod |
|---|---|---|---|---|---|
| H | L | duty | H | AO1=H, AO2=L | CW (ileri) |
| L | H | duty | H | AO1=L, AO2=H | CCW (geri) |
| H | H | x | H | AO1=L, AO2=L | Short brake |
| L | L | H | H | AO1/AO2 = Hi-Z | Stop (free) |
| x | x | x | **L** | AO1/AO2 = Hi-Z | **Standby** |

**Decoupling (datasheet sf 7 typical application):** VM hattına **10 µF + 0.1 µF**. Robotistan/Direnç modülünde bu kapasitörler **yerleşik** — ek kapasitör eklemeye gerek yok, ancak motor uçlarında snubber arzu edilirse opsiyonel.

### 8.4. PWM Konfigürasyonu (TIM3_CH3 @ PB0)

Saat ağacı:
- SYSCLK = 96 MHz
- APB1 prescaler = 2 → PCLK1 = 48 MHz
- APB1 timer ×2 multiplier → **TIM3 input clock = 96 MHz**

```
fPWM = 96 MHz / ((PSC + 1) × (ARR + 1))
20 kHz = 96e6 / (1 × 4800)
```

**Seçim:** PSC = 0, ARR = 4799 → **20.000 kHz, 4800 step (≈12.23-bit) çözünürlük**.

```c
htim3.Init.Prescaler = 0;
htim3.Init.Period    = 4799;
htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
// Channel 3 → CCR3 ∈ [0, 4799], duty = CCR3 / 4800
```

20 kHz seçim gerekçeleri:
- Audible threshold üstünde (motor sirenlemesi duyulmaz)
- TB6612 100 kHz limitinin %20'si — geniş margin
- Motor inductance ile akım dalgalanması düşük

### 8.5. Akım ve Güç Bütçesi

**3V3 hattı (BlackPill AP7343, 300 mA limit):**

| Tüketici | Akım (typ) |
|---|---|
| BlackPill (STM32 + USB CDC + LED) | 50–80 mA |
| MPU6050 | 3.9 mA |
| TB6612FNG lojik (Vcc=3V3, max) | 2.2 mA |
| **Toplam** | **~85 mA** |
| **Margin** | **~215 mA** |

**5V hattı (USB direkt, 500 mA limit):**

| Tüketici | Akım |
|---|---|
| BlackPill 5V→3V3 regülatör girişi | ~100 mA |
| Pololu encoder (LED + IC) | ~25 mA |
| **Toplam** | **~125 mA** |

**12V hattı (Mervesan 12V/3A 36W duvar adaptörü):**

| Tüketici | Akım |
|---|---|
| TB6612FNG VM (lojik akım) | ~0.5 mA |
| Pololu motor — yüksüz | 75 mA |
| Pololu motor — stall (12V, açık döngü) | 1.6 A |
| Pololu motor — stall **duty cap %50** ile | **~0.8 A** |
| **Adaptör nominal kapasite** | **3.0 A** |

> **Donanım sigortası henüz yok.** Stall durumunda motor akımı yazılım katmanlarıyla sınırlanır (duty hard cap %50, stall detection 200 ms içinde STBY=L). Detaylı emniyet planı → `ROADMAP.md`.

### 8.6. Donanım Kurulum Notları

- **12V kaynak:** **Mervesan 12V/3A 36W duvar adaptörü.** Donanım sigortası planlı (henüz temin edilmedi).
  > **TODO:** VM hattına 1.5 A polyfuse veya 2 A cam sigorta eklenecek (kullanıcı temin edecek). Sigorta entegre edildiğinde ROADMAP.md'den "VM hattı sigorta entegrasyonu" maddesi aşamaya alınacak.
- **Manuel kill switch (önerilen, Aşama 2A test öncesi):** STBY hattı (PB14 → TB6612 STBY pini) üzerine seri normalde-açık basmalı buton. Buton basıldığında STBY GND'ye düşer, motor sürücü anında devre dışı kalır. Yazılım stall detection yedeği olarak fiziksel emniyet — özellikle ROADMAP § Test 2A.T5 (stall detection testi) öncesi hazırlanması önerilir.
- **Yazılım koruma katmanları (sigorta gelinceye kadar zorunlu) — Aşama 2A implementasyon durumu:**

  | # | Katman | Durum | Davranış |
  |---|---|---|---|
  | 1 | **Stall detection** | ✅ Aktif (2A.7) | `Motor_StallCheck()` 200 Hz çağrılır. Tetik: \|hız\| < 2 rad/s + current_duty > 0.20 + 200 ms. Rampa sırasında (current ≠ target) bypass. Tetiklenince `Motor_EmergencyStop()` (STBY=L + duty=0 + AIN=0). USB CDC'ye `STALL_DETECTED\r\n`. |
  | 2 | **Duty hard cap** | ✅ Aktif (2A.4) | `MOTOR_MAX_DUTY = 0.50f` motor.c iç sabiti. `Motor_SetDuty` clamp. Stall'da pik akım ~0.8 A, TB6612 1.2 A continuous altında. |
  | 3 | **Soft-start / rampa** | ✅ Aktif (2A.5) | Non-blocking: `Motor_SetDuty` target'ı set, `Motor_Tick()` 200 Hz'de 0.01 step yumuşatır. \|Δduty\| ≤ 0.10 anında uygulanır. Bloklayan `Motor_SoftStart()` init için. |
  | 4 | **5 sn lockout** | ✅ Aktif (2A.8) | Stall sonrası `Motor_SetDuty`/`Motor_Enable` sessizce reddedilir. Otomatik açılır, `Motor_ResetLockout()` erken kapatma (USB komut 2B). |
  | 5 | **LED durum kodu** | ✅ Aktif (2A.9) | Normal 500 ms, stall 100 ms (5 Hz) toggle — kullanıcı görsel uyarı. |
  | 6 | **Watchdog timeout** | ⏳ 2B'de aktive | USB CDC'den 1 sn komut yoksa PWM=0. |
  | 7 | **TB6612 dahili termal shutdown** | ✅ Sürücü içinde | 175 °C tetik, 20 °C histerezis (datasheet sf 5). Demo sırasında **manuel termal kontrol** (motora dokun). |

  **Debug aracı:** `PA0` KEY butonu basılı iken `Motor_DebugInjectFakeStall(true)` çağrılır — encoder hızı 0 sayılır, stall mantığı tetiklenir. Sıfır risk doğrulama (Test 2A.T5 Aşama A). Test 2A.T5 Aşama A ile yazılım mantığı PASS — gerçek motor stall (Aşama B) sonraki seansta eldivenle yapılacak.
- **Ortak GND:** BlackPill GND ↔ TB6612 GND ↔ 12V kaynak GND tek noktada birleşmeli (yıldız topology). Motor akımının dönüş yolu ve TB6612 lojik referansı bu hatta tutulmalı.
- **VM decoupling:** Modül üzerinde 10 µF + 0.1 µF kapasitörler yerleşik geliyor (Robotistan/Direnç). Harici eklemeye gerek yok.
- **Encoder beslemesi:** BlackPill 5V pininden (USB direkt). Datasheet'te 3.5 V minimum belirtildiği için 3V3 kullanılmaz.
- **Encoder pull-up:** STM32 internal `GPIO_PULLUP`. Harici direnç gerekmez.
- **STBY init sırası:** Tüm peripheral init'ler tamamlandıktan sonra (en son) STBY=HIGH yapılır. TB6612 input pinlerinde dahili 200 kΩ pull-down var (datasheet sf 2) — STM32 GPIO Hi-Z iken bile sürücü güvenli olarak kapalı kalır.

### 8.7. Donanım Bağlantı Şematiği

Aşama 2A donanım kurulumunun kalıcı referansı. Pin-pin bağlantı listesi ve sistem topolojisi.

#### 8.7.1. Bağlantı Tablosu

**MPU6050 ↔ BlackPill (I2C1):**

| MPU6050 pin | Kablo | BlackPill pin | Açıklama |
|---|---|---|---|
| VCC | kırmızı | **3V3** | Lojik besleme |
| GND | siyah | **GND** | Ortak referans |
| SCL | sarı | **PB6** | I2C1_SCL (AF4) |
| SDA | yeşil | **PB7** | I2C1_SDA (AF4) |
| INT | (boş) | — | Kullanılmıyor |
| AD0 | siyah | **GND** | I2C adresi 0x68 |

**TB6612FNG ↔ BlackPill (PWM + GPIO):**

| TB6612 pin | Kablo | BlackPill pin | Açıklama |
|---|---|---|---|
| Vcc | kırmızı | **3V3** | Lojik besleme (2.7–5.5 V) |
| GND | siyah | **GND** | Ortak referans |
| PWMA | mor | **PB0** | TIM3_CH3 (AF2), 20 kHz |
| AIN1 | turuncu | **PB12** | Yön kontrolü |
| AIN2 | sarı | **PB13** | Yön kontrolü |
| STBY | mavi | **PB14** | Sürücü enable (HIGH=aktif) |
| BIN1/BIN2/PWMB | (boş) | — | İkinci motor kullanılmıyor (Aşama 2'de) |

**TB6612FNG ↔ Pololu Motor:**

| TB6612 pin | Pololu kablo | Açıklama |
|---|---|---|
| **AO1** | kırmızı | Motor + (CW yönde) |
| **AO2** | siyah | Motor − (CW yönde) |
| **VM** | (12V kaynak +) | Motor besleme (4.5–13.5 V) |
| **GND** | (12V kaynak −) | **Ortak GND ile birleşmeli** |

**Pololu Encoder ↔ BlackPill (TIM2 quadrature):**

| Pololu kablo | BlackPill pin | Açıklama |
|---|---|---|
| Mavi (Vcc) | **5V** | Encoder besleme (3.5–20 V; 3V3 yetersiz) |
| Yeşil (GND) | **GND** | Ortak referans |
| Sarı (A) | **PA15** | TIM2_CH1 (AF1), GPIO_PULLUP |
| Beyaz (B) | **PB3** | TIM2_CH2 (AF1), GPIO_PULLUP |

#### 8.7.2. Güç Topolojisi (Yıldız GND)

```
                                    ┌───────────────┐
                                    │ Mervesan 12V/3A│
                                    │  Duvar Adaptör│
                                    └──┬─────────┬──┘
                                       │ 12V     │ GND
                                       │         │
                              VM ──────┘         │
                                       ┌─────────┘
                                       │
                              ┌────────┴────────────┐
                              │   TB6612FNG modülü  │
                              │                     │
        BlackPill 3V3 ────────► Vcc                 │
                              │ PWMA ◄────PB0       │
                              │ AIN1 ◄────PB12      │
                              │ AIN2 ◄────PB13      │
                              │ STBY ◄────PB14      │
                              │   AO1 ─► Motor +    │
                              │   AO2 ─► Motor −    │
                              │   GND ──┐           │
                              └─────────┼───────────┘
                                        │
                                        │
                                ┌───────┴────────┐
                                │  ⭐ YILDIZ GND  │ ←── BlackPill GND
                                │   (tek nokta)   │ ←── 12V adaptör GND
                                └────────────────┘ ←── Encoder GND (yeşil)
                                                    ←── MPU6050 GND

        BlackPill 5V ─────► Encoder Vcc (mavi)
        BlackPill PA15 ◄── Encoder A   (sarı)
        BlackPill PB3  ◄── Encoder B   (beyaz)

        BlackPill 3V3 ─────► MPU6050 VCC
        BlackPill PB6 ↔─── MPU6050 SCL (I2C1)
        BlackPill PB7 ↔─── MPU6050 SDA (I2C1)

        ST-Link V2 ──── SWD (PA13/PA14) — geliştirme için
        Type-C ──────── USB CDC (PA11/PA12) — veri akışı + 5V besleme
```

#### 8.7.3. Kritik Notlar

- **Ortak GND yıldız topology:** BlackPill GND, TB6612 GND, 12V adaptör GND, encoder GND, MPU6050 GND **tek noktada birleşir**. Motor akımı dönüş yolu için kritik; ground loop oluşmamalı.
- **VM ≠ Vcc:** TB6612'nin VM (motor 12V) ve Vcc (lojik 3.3V) **ayrı** beslenir. Karıştırma motoru yakar.
- **Encoder Vcc = 5V:** Pololu datasheet'inde min 3.5V belirtildiği için BlackPill 3V3 yetmez. USB direkt 5V kullanılır. STM32 PA15/PB3 **FT (5V tolerant)** olduğu için level shifter gerekmez.
- **Kill switch (opsiyonel):** STBY hattına seri NO buton — fiziksel emniyet katmanı, Aşama 2A.T5 öncesi önerilir.
- **Polyfuse (TODO):** VM hattında 1.5 A polyfuse veya 2 A cam sigorta planlı, henüz temin edilmedi. Sigortasız çalışmada yazılım koruma katmanları (stall detection, duty cap, soft-start, watchdog) zorunludur.

### 8.8. Motor Karakterizasyon — Vsat Düzeltmesi

PID kazanç ayarı için motor parametrelerinin (Kt, Ke, J, b) sistem tanımlamayla çıkarılması gerekir. TB6612'nin output saturating voltage'ı (Vsat ≈ 0.5 V @ 1 A) bu hesapta dikkate alınmalıdır:

```
V_motor_etkin = (duty × V_VM) − V_sat
              ≈ duty × 12 − 0.5     (12V besleme, 1A altı yük)
```

Bu formül Aşama 2'de kullanılacak Python sistem tanımlama scriptinde başlangıç eşiği (motor kalkış duty cycle'ı) hesabında kullanılacak.

---

## 9. Derleme ve Flash İşlemleri

### 9.1. Gereksinimler

- **PlatformIO Core CLI** (pipx ile kurulum önerilir)
- **ST-Link V2** programlayıcı (SWD bağlantısı)

### 9.2. Derleme

```bash
cd ~/workspace/2_Eksenli_Gimbal
pio run
```

PlatformIO otomatik olarak indirir:
- `toolchain-gccarmnoneeabi` (ARM cross-compiler, v7.2.1)
- `framework-stm32cubef4` (HAL kütüphaneleri, v1.28.1)
- `tool-openocd` (debug/flash aracı, v12.0)

`add_usb_middleware.py` scripti, build sırasında USB CDC Middleware kütüphanesini (STM32_USB_Device_Library) otomatik olarak derlemeye dahil eder.

### 9.3. Flash (ST-Link ile)

```bash
pio run -t upload
```

Bu komut:
1. Değişen kaynak dosyalarını yeniden derler
2. `.elf` dosyasını oluşturur
3. OpenOCD üzerinden ST-Link ile SWD protokolü kullanarak flash'lar
4. MCU'yu resetler ve firmware çalışmaya başlar

### 9.4. Seri Veri İzleme

```bash
# Yöntem 1: Ham veri (terminal)
pio device monitor

# Yöntem 2: Gerçek zamanlı grafik
python3 plot_angles.py /dev/ttyACM0
```

### 9.5. Bellek Kullanımı

```
RAM:    4,364 / 131,072 bytes  (  3.3%)
Flash: 31,108 / 524,288 bytes  (  5.9%)
```

Hem RAM hem de Flash kullanımı son derece düşüktür. PID kontrolcü, Madgwick filtresi ve ek sensör sürücüleri eklendiğinde bile yeterli kapasite mevcuttur.

---

## Dosya Yapısı

```
2_Eksenli_Gimbal/
├── src/
│   ├── main.c               ← Ana firmware: init, sensör okuma, filter, USB çıktı
│   ├── usbd_cdc_if.c        ← USB CDC interface (Tx/Rx callback'leri)
│   ├── usbd_conf.c          ← USB donanım konfigürasyonu (GPIO, IRQ, PCD)
│   └── usbd_desc.c          ← USB cihaz tanımlayıcıları (VID/PID, string desc)
├── include/
│   ├── usbd_cdc_if.h
│   ├── usbd_conf.h
│   └── usbd_desc.h
├── platformio.ini            ← Build konfigürasyonu
├── add_usb_middleware.py     ← PlatformIO pre-build: USB middleware dahil etme
├── plot_angles.py            ← PC tarafı: gerçek zamanlı matplotlib grafik
├── screenshots/              ← Otomatik kaydedilen IMU grafik PNG'leri
├── datasheets/               ← Donanım PDF/şematik belgeleri
│   ├── WeAct Black Pill V2.0 STM32F411CEU6/
│   ├── MPU6050/
│   ├── TB6612FNG/
│   └── Pololu 9.7:1 .../
├── PROJE_DURUMU.md           ← Proje durum takibi (handoff belgesi)
└── README.md                 ← Bu teknik rapor
```

---

## Referanslar

### Donanım Belgeleri

- **WeAct BlackPill — GitHub repo (şematik, pinout, örnek kodlar):**  
  <https://github.com/WeActStudio/WeActStudio.MiniSTM32F4x1>
- **WeAct BlackPill — STM32-Base sayfası (Power LED, BOOT0/RESET düğmeleri, USB pinout):**  
  <https://stm32-base.org/boards/STM32F411CEU6-WeAct-Black-Pill-V2.0.html#Power-LED>

### Datasheet'ler (yerel)

`datasheets/` klasöründe şu PDF/şema dosyaları bulunur:

| Bileşen | Dosyalar |
|---|---|
| STM32F411CEU6 | `STM32F411_datasheet.pdf`, `STM32F411CEU6_manual.pdf`, `STM32F411CEU6_schematics.pdf`, `STM32F411CEU6_pcb.pdf`, `STM32F411_functions_map.csv` |
| MPU6050 | `ps-mpu-6000a-00-...-datasheet.pdf`, `rm-mpu-6000a-00-...-register-map.pdf` |
| TB6612FNG | `TB6612FNG.pdf` |
| Pololu Motor | `25d-metal-gearmotor-dimension-diagram.pdf` |

### Donanım Çalışmaları İçin Kural

Donanımla ilgili herhangi bir değişiklik (pin atama, peripheral konfig, motor sürücü kurulumu, sensör register'ı) yapılırken **önce** ilgili datasheet/şematik **görsel olarak** incelenmelidir.  

PDF'ler text extraction ile değil, sayfa-PNG olarak okunmalı — pinout tabloları, register haritaları, timing diyagramları ve şematikler text dökümünde bozulur. Bu iş için `/datasheet-reader` skill'i kullanılır (PDF → PyMuPDF ile PNG → görsel okuma).