# Aşama 3 — İki Motor MIMO Modelleme

> **Durum:** 🟡 AKTİF (2026-06-07 açıldı, `feature/asama-3-mimo-model`).
> Bu belge ders-kitabı disipliniyle (Ne/Neden/Nasıl/Nerede/Sonuç — global CLAUDE.md)
> aşama ilerledikçe doldurulur. Ortak teori kavramları → [`00_genel_bakis.md`](00_genel_bakis.md).

## 12. Aşama 3 — İki Motor MIMO

### 12.1. Ne / Neden (vizyon)

İkinci motor + encoder eklenir; **çapraz kuplaj** (motor 1 sürülürken motor 2 ekseninde
etki) karakterize edilir: 2×2 transfer matrisi $G(s)$, RGA analizi (`[Skogestad2005] §10`),
condition number → decoupling potansiyeli. Aşama 4 (MIMO kontrol/LQG) bu modelin üzerine kurulur.

### 12.2. Donanım genişlemesi (3.1 — pin planı ✅ ONAYLANDI 2026-06-07)

Kısıtlar: PA4–PA7 (SPI-flash footprint, `[WeAct_BP]`), PA0 (KEY), PB2 (BOOT1), PA13/14 (SWD);
mevcut atamalar ([`asama_0_altyapi.md`](asama_0_altyapi.md) §8.1) sabit. Tüm eşleşmeler
`STM32F411_functions_map.csv` (`[STM32F411_DS]` sf 38-52 AF tablosu) ile teyitli.

| İşlev | Pin | Çevre birimi | Dayanak |
|---|---|---|---|
| Encoder-2 A | **PA8** | TIM1_CH1 (AF1) | TIM2 dolu (enc-1), TIM3 dolu (PWM), TIM4 PB6/7=I2C ✗, TIM5 PA0=KEY ✗ → tek temiz aday |
| Encoder-2 B | **PA9** | TIM1_CH2 (AF1) | " |
| Motor-2 PWM | **PB1** | TIM3_CH4 | Motor-1 ile aynı timer: aynı 20 kHz ARR, bağımsız CCR — ekstra timer harcamaz |
| Motor-2 AIN1 | **PB4** | GPIO | SW-DP modunda JTRST serbest (`[RM0383]` §23.3 — PA15/PB3 ile aynı dayanak) |
| Motor-2 AIN2 | **PB5** | GPIO | boş (TC tipi — çıkış yönünde önemsiz) |
| Motor-2 STBY | **PB10** | GPIO | **ayrı STBY** = eksen-bağımsız acil kesme; paylaşımlı-PB14 alternatifi reddedildi (bir eksenin stall'ı diğerini söndürmesin — kullanıcı kararı 2026-06-07) |
| ACS712-1 (Faz-2 rezerv) | PA1 | ADC1_IN1 | eksen-başı akım ölçümü — ROADMAP güç planı |
| ACS712-2 (Faz-2 rezerv) | PA2 | ADC1_IN2 | " |

**Bilinen kaveat:** TIM1 **16-bit** (enc-1'in TIM2'si 32-bit'ti) → 466 count/devirde ±70 çıkış
devrinde sarar → encoder-2 sürücüsünde **yazılım count-genişletme** (int16 delta extension)
gerekir — 3.2'de implement edilir.

#### Kablolama — renk renk (Pololu 25D tek gövde: motor+encoder, 6 telli tek kablo)

Pololu 25D'de motor ve encoder **ayrı değil, tek gövde** — kablodan **6 renkli tel** çıkar
ve 3 yere ayrılır: kalın 2 tel (motor gücü) sürücü çıkışına, ince 4 telin 2'si güç rayına,
2'si (sinyal) doğrudan MCU'ya. **Sarı/beyaz asla sürücüye gitmez — doğrudan işlemciye.**
Renk kodu: `[Pololu_25D]` Page 2.

| Renk | İşlev | Motor-1 (mevcut) | **Motor-2 (yeni)** |
|---|---|---|---|
| 🔴 Kırmızı | Motor + | TB6612-1 AO1 | **TB6612-2 AO1** |
| ⚫ Siyah | Motor − | TB6612-1 AO2 | **TB6612-2 AO2** |
| 🔵 Mavi | Encoder Vcc | 5V | **5V** (PA8/PA9 FT, 5V-tol.) |
| 🟢 Yeşil | Encoder GND | GND | **GND** |
| 🟡 Sarı | Encoder A | PA15 | **PA8** |
| ⚪ Beyaz | Encoder B | PB3 | **PA9** |

**MCU ↔ TB6612-2 kontrol jumper'ları** (motor kablosu değil): PWMA←PB1, AIN1←PB4,
AIN2←PB5, STBY←PB10, VCC←3.3V, VM←12V, GND←GND.

⚠ **(1)** Tüm GND'ler ORTAK (MCU + 2 sürücü + 12V adaptör − + encoder yeşiller tek nokta).
**(2)** Kırmızı/siyah AO1↔AO2 sırası yön belirler — ters dönerse swap veya firmware yön çevir.
**(3)** Encoder Vcc=5V, sürücü VCC=3.3V (karıştırma).

Güç & koruma kararları → `ROADMAP.md` "Aşama 3 güç & koruma planı" (tek 3A adaptör yeterli,
2 ayrı TB6612 — termal, dar boğaz = sürücü, ACS712 eksen-başı rezervi).

### 12.3. Sistem tanımlama planı (3.3–3.4)

*(SISO↔MIMO veri toplama: her motoru ayrı sür, diğer ekseni ölç; eleman-bazlı `tfest`.)*

### 12.4. Açık konular

- Pin planı onayı (3.1)
- 2. encoder 16-bit timer sayaç genişletme (TIM1 seçilirse — yazılım extended count)
- ACS712 Faz-2 entegrasyonu (duty %100 gevşetme ön koşulu)
