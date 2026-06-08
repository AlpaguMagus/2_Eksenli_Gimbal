# Aşama 3 — İki Motor MIMO Modelleme

> **Durum:** 🟡 AKTİF (2026-06-07 açıldı, `feature/asama-3-mimo-model`).
> Bu belge ders-kitabı disipliniyle (Ne/Neden/Nasıl/Nerede/Sonuç — global CLAUDE.md)
> aşama ilerledikçe doldurulur. Ortak teori kavramları → [`00_genel_bakis.md`](00_genel_bakis.md).

## 12. Aşama 3 — İki Motor MIMO

### 12.1. Ne / Neden (vizyon)

İkinci motor + encoder eklenir; **çapraz kuplaj** (motor 1 sürülürken motor 2 ekseninde
etki) karakterize edilir: 2×2 transfer matrisi $G(s)$, RGA analizi (`[Skogestad2005] §10`),
condition number → decoupling potansiyeli. Aşama 4 (MIMO kontrol/LQG) bu modelin üzerine kurulur.

### 12.2. Donanım — Tam Sistem Şeması (3.1 ✅ ONAYLANDI 2026-06-07)

Bu bölüm **tüm 2-motor MIMO sisteminin** bağlantı şemasıdır (MCU + 2 sürücü + 2 motor +
IMU + güç). Tek-motor (Aşama 0–2) görünümü [`asama_0_altyapi.md`](asama_0_altyapi.md) §8.1'dedir
ama **güncel ve eksiksiz şema burasıdır.** Tüm eşleşmeler `STM32F411_functions_map.csv`
(`[STM32F411_DS]` sf 38-52 AF tablosu) ile teyitli. Kısıtlar: PA4–PA7 (SPI-flash footprint,
`[WeAct_BP]`), PA0 (KEY), PB2 (BOOT1), PA13/14 (SWD).

#### 12.2.1. Bağlantı şeması (iki eksen yan yana)

```
┌─ GÜÇ DAĞITIMI ───────────────────────────────────────────────┐
│ 12V/3A adaptör (+) → TB6612-1.VM  +  TB6612-2.VM  (motor gücü)│
│ BlackPill 5V       → enc-1.Vcc 🔵  +  enc-2.Vcc 🔵  (encoder) │
│ BlackPill 3.3V     → TB6612-1.VCC + TB6612-2.VCC + MPU6050.VCC│
│                      (lojik — IMU 3.3V! encoder'la KARIŞTIRMA)│
│ ORTAK GND ⏚ (TEK NOKTA) → BlackPill.GND + TB6612-1/2.GND      │
│                           + 12V(−) + enc-1/2.GND 🟢 + MPU.GND │
└──────────────────────────────────────────────────────────────┘

MOTOR-1 EKSENİ (mevcut, çalışıyor)            MOTOR-2 EKSENİ (yeni, Aşama 3)
──────────────────────────────────           ──────────────────────────────
PB0  ─PWM ─▶ TB6612-1 PWMA                    PB1  ─PWM ─▶ TB6612-2 PWMA
PB12 ─AIN1─▶ TB6612-1 AIN1                    PB4  ─AIN1─▶ TB6612-2 AIN1
PB13 ─AIN2─▶ TB6612-1 AIN2                    PB5  ─AIN2─▶ TB6612-2 AIN2
PB14 ─STBY─▶ TB6612-1 STBY                    PB10 ─STBY─▶ TB6612-2 STBY
             TB6612-1 AO1 ─🔴▶ Motor1 +                   TB6612-2 AO1 ─🔴▶ Motor2 +
             TB6612-1 AO2 ─⚫▶ Motor1 −                   TB6612-2 AO2 ─⚫▶ Motor2 −
PA15 ◀─enc A 🟡 sarı                          PA8  ◀─enc A 🟡 sarı
PB3  ◀─enc B ⚪ beyaz                         PA9  ◀─enc B ⚪ beyaz
  (TIM2, 32-bit)                                (TIM1, 16-bit → yazılım count-genişletme 3.2)

IMU — MPU6050
─────────────
PB6 ─SCL─▶ MPU6050 SCL     PB7 ◀─SDA─▶ MPU6050 SDA
3.3V ─▶ VCC   GND ─▶ GND   AD0 ─▶ GND   (I2C1 100 kHz, adres 0x68)
  ⚠ MPU6050 = 3.3V (encoder 5V ile karıştırma — asama_0 §8.5/satır 739 yetkili)
```

> 📌 `─▶` MCU **çıkışı**, `◀─` MCU **girişi**. Her Pololu 25D **tek gövdedir** (motor+encoder):
> tek kablodan 6 renkli tel çıkar — kalın 2'si (🔴🔴⚫) sürücü çıkışına, ince 4'ün 2'si güç
> rayına (🔵🟢), 2'si doğrudan MCU'ya (🟡⚪). **Sarı/beyaz asla sürücüye gitmez.**

#### 12.2.2. Master pin tablosu (her kullanılan pin)

| İşlev | Pin | Çevre | Yön | Bağlantı |
|---|---|---|---|---|
| Motor-1 PWM | PB0 | TIM3_CH3 | →çıkış | TB6612-1 PWMA |
| Motor-1 AIN1 / AIN2 | PB12 / PB13 | GPIO | →çıkış | TB6612-1 AIN1/AIN2 |
| Motor-1 STBY | PB14 | GPIO | →çıkış | TB6612-1 STBY |
| Encoder-1 A / B | PA15 / PB3 | TIM2_CH1/2 (32-bit) | ←giriş | M1 🟡 / ⚪ |
| **Motor-2 PWM** | **PB1** | TIM3_CH4 | →çıkış | TB6612-2 PWMA |
| **Motor-2 AIN1 / AIN2** | **PB4 / PB5** | GPIO | →çıkış | TB6612-2 AIN1/AIN2 |
| **Motor-2 STBY** | **PB10** | GPIO | →çıkış | TB6612-2 STBY (ayrı) |
| **Encoder-2 A / B** | **PA8 / PA9** | TIM1_CH1/2 (16-bit) | ←giriş | M2 🟡 / ⚪ |
| IMU SCL / SDA | PB6 / PB7 | I2C1 | ↔ | MPU6050 SCL/SDA |
| USB D− / D+ | PA11 / PA12 | OTG_FS | ↔ | USB-C |
| SWD IO / CLK | PA13 / PA14 | SWJ-DP | ↔ | ST-Link |
| LED | PC13 | GPIO | →çıkış | onboard |
| KEY (+ fake-stall debug) | PA0 | GPIO | ←giriş | onboard buton |
| ACS712-1 / -2 (Faz-2 rezerv) | PA1 / PA2 | ADC1_IN1/2 | ←giriş | rezerv |

**Motor-2 pin gerekçeleri:** Encoder-2 → **TIM1** (TIM2 enc-1'de dolu, TIM3 PWM'de dolu,
TIM4 PB6/7=I2C ✗, TIM5 PA0=KEY ✗ → tek temiz quadrature timer); PWM-2 → **PB1=TIM3_CH4**
(motor-1 ile aynı timer, aynı 20 kHz ARR, bağımsız CCR — ekstra timer harcamaz); AIN1 → **PB4**
(SW-DP'de JTRST serbest, `[RM0383]` §23.3); STBY-2 → **PB10 ayrı** (eksen-bağımsız acil kesme;
paylaşımlı-PB14 reddedildi — bir eksenin stall'ı diğerini söndürmesin, kullanıcı kararı).
**Kaveat:** TIM1 **16-bit** → 466 count/devirde ±70 çıkış devrinde sarar → encoder-2'de
**yazılım count-genişletme** (int16 delta extension) gerekir — 3.2'de implement edilir.

#### 12.2.3. Kablolama — renk renk (motor-1 ↔ motor-2 paralel)

Renk kodu `[Pololu_25D]` Page 2.

| Renk | İşlev | Motor-1 (mevcut) | **Motor-2 (yeni)** |
|---|---|---|---|
| 🔴 Kırmızı | Motor + | TB6612-1 AO1 | **TB6612-2 AO1** |
| ⚫ Siyah | Motor − | TB6612-1 AO2 | **TB6612-2 AO2** |
| 🔵 Mavi | Encoder Vcc | 5V | **5V** (PA8/PA9 FT, 5V-tol.) |
| 🟢 Yeşil | Encoder GND | GND | **GND** |
| 🟡 Sarı | Encoder A | PA15 | **PA8** |
| ⚪ Beyaz | Encoder B | PB3 | **PA9** |

⚠ **3 kritik kural:** **(1)** Tüm GND'ler ORTAK — BlackPill + iki TB6612 + 12V(−) + encoder
yeşiller tek noktada (yoksa encoder sinyali gürültüye boğulur). **(2)** Kırmızı/siyah AO1↔AO2
sırası **yön** belirler — ters dönerse iki ucu swap'la veya firmware'de yön çevir. **(3)**
Encoder Vcc = **5V**, sürücü VCC = **3.3V** (karıştırma).

Güç & koruma kararları → `ROADMAP.md` "Aşama 3 güç & koruma planı" (tek 3A adaptör yeterli,
2 ayrı TB6612 — termal, dar boğaz = sürücü, ACS712 eksen-başı rezervi).

### 12.3. Sistem tanımlama planı (3.3–3.4)

*(SISO↔MIMO veri toplama: her motoru ayrı sür, diğer ekseni ölç; eleman-bazlı `tfest`.)*

### 12.4. Açık konular

- ✅ Pin planı (3.1) — KARAR verildi, kablolama tamamlandı (2026-06-08); §12.2 şema
- ⬜ Encoder-2 firmware: TIM1 16-bit quadrature + **yazılım count-genişletme** (3.2)
- ⬜ Motor-2 sürücü katmanı (2. TB6612 — PB1/PB4/PB5/PB10) + iki-kanal yön/duty (3.2)
- ⬜ ACS712 Faz-2 entegrasyonu (duty %100 gevşetme ön koşulu)
