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

> 📐 **Tam bağlantı şeması + master pin tablosu + renk-renk kablolama → [`00_donanim_semasi.md`](00_donanim_semasi.md)**
> (tek yaşayan donanım kaynağı — ACS712 Faz-2 rezervi dahil). Bu bölüm yalnız **motor-2 pin
> seçim gerekçelerini** tutar (gerekçe fazda, veri donanım belgesinde — tek doğruluk kaynağı).

**Motor-2 pin gerekçeleri:** Encoder-2 → **TIM1 (PA8/PA9)** — TIM2 enc-1'de dolu, TIM3 PWM'de
dolu, TIM4 PB6/7=I2C ✗, TIM5 PA0=KEY ✗ → tek temiz quadrature timer; PWM-2 → **PB1=TIM3_CH4**
(motor-1 ile aynı timer, aynı 20 kHz ARR, bağımsız CCR — ekstra timer harcamaz); AIN1/AIN2 →
**PB4/PB5** (PB4=JTRST yalnız SW-DP modunda serbest kalır, `[RM0383]` §23.3; PB5 zaten JTAG
pini değil → genel-amaçlı IO olarak baştan serbest); STBY-2 → **PB10 ayrı** (eksen-bağımsız
acil kesme; paylaşımlı-PB14 reddedildi — bir eksenin stall'ı diğerini söndürmesin, kullanıcı
kararı 2026-06-07). ACS712 → **PA1/PA2 (ADC1) rezerv** (Faz-2, henüz bağlı değil — donanım §5).

**Kaveat:** TIM1 **16-bit** (enc-1'in TIM2'si 32-bit'ti) → 466 count/devirde ±70 çıkış devrinde
sarar → encoder-2'de **yazılım count-genişletme** (int16 delta extension) — `src/encoder.c`
`Encoder2_GetCount` (3.2'de eklendi).

### 12.3. Sistem tanımlama planı (3.3–3.4)

*(SISO↔MIMO veri toplama: her motoru ayrı sür, diğer ekseni ölç; eleman-bazlı `tfest`.)*

### 12.4. Açık konular

- ✅ Pin planı (3.1) — KARAR verildi, kablolama tamamlandı (2026-06-08); §12.2 şema
- ⬜ Encoder-2 firmware: TIM1 16-bit quadrature + **yazılım count-genişletme** (3.2)
- ⬜ Motor-2 sürücü katmanı (2. TB6612 — PB1/PB4/PB5/PB10) + iki-kanal yön/duty (3.2)
- ⬜ ACS712 Faz-2 entegrasyonu (duty %100 gevşetme ön koşulu)
