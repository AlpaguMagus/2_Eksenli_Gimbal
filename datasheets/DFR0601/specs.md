# DFRobot Dual-Channel DC Motor Driver-12A (DFR0601) — 2 kanal, 290 W

> **Kaynak:** `wiki.dfrobot.com/dfr0601` + `robotsepeti.com/dfrobot-2-kanal-h-kopru-dc-motor-surucu`; WebFetch 2026-06-17.
> Çapraz-kontrol: DigiKey 10279757, Farnell SC21013, JLCPCB C5711371.
> ⚠ Kullanıcı "2×15A" dedi; **resmi spec 12 A/kanal** (290 W aynı). Sipariş edildi 2026-06-17 (HP + LP için).

| Özellik | Değer |
|---|---|
| Model / SKU | **DFR0601** (Dual-Channel DC Motor Driver-12A) |
| Kanal | **2** (plan: HP → kanal-1, LP → kanal-2) |
| **Motor besleme (VM / P+)** | **6.5 – 37 V DC** (12 V kapsanır) |
| **Lojik / kontrol (VCC)** | **3 – 5 V** uyumlu (3.3 V STM32 doğrudan sürer; sinyal akımı ~15 mA @5V) |
| **Sürekli akım** | **12 A / kanal** (TB6612 1.2 A'nın ~10×'i; HW-039'a alternatif) |
| Tepe akım | **70 A**, ~100 ms |
| Maks güç | **290 W** |
| **PWM giriş frekansı** | **18 – 60 kHz** (min pulse 2 µs) |
| **Kontrol arabirimi (kanal başı)** | **PWM + INA + INB** (PWM = hız; INA/INB = yön mantığı) — TB6612 AIN1/AIN2/PWM şemasına benzer |
| Enable / STBY pini | **YOK** (kontrol PWM duty + INA/INB ile) |
| Koruma | Aşırı-gerilim (37.5 V), düşük-gerilim (6.3 V), termal kapatma (85–95°C) |
| Yön göstergesi | Mavi LED (ileri), Kırmızı LED (geri), STATE LED |
| Boyut / sıcaklık | 50 × 50 × 12.5 mm; −25…85°C |

## Terminal / pinout
| Pin | İşlev |
|---|---|
| 1, 6 | VCC (kontrol gücü 3.3/5 V) |
| 2, 7 | PWM1 / PWM2 |
| 3,4 / 8,9 | INA1/INB1 / INA2/INB2 (yön) |
| 5, 10 | GND |
| 11, 12 | M1 çıkış (M1_A / M1_B) |
| 13, 14 | M2 çıkış (M2_A / M2_B) |
| 15, 16 | P− / P+ (motor gücü 6.5–37 V) |

## Bu projeye uygunluk (✅ birincil sürücü adayı)
- **HEM HP HEM LP'yi tek kart sürer** (2 kanal) → asimetrik HW-039 + TB6612 ikilisi kalkar.
- **12 A/kanal** HP stall'ını (~5.6 A) ve LP'yi rahat karşılar (TB6612 1.2 A yetersizdi; HW-039 yavaştı, τ_eff≈450 ms).
- **6.5–37 V** 12 V beslemeyi kapsar; **3.3 V lojik** STM32'yi doğrudan sürer.
- **PWM + INA/INB** mevcut TB6612 firmware şemasına yakın → migrasyon temiz (INA/INB ≈ AIN1/AIN2; STBY gerekmez). Kanal başı 3 kontrol pini × 2 = 6 pin.
- **18–60 kHz** PWM bizim 20 kHz'i kapsar (işitme-üstü).
- ⚠ Sürücü-domeni τ (HW-039'da ~450 ms sorundu) DFR0601'de **gelince step-ID ile ölçülecek**; 2 µs min-pulse + yüksek-akım sürücü hızlı yanıt vaat eder.

> **Not (tez):** Tezde DFR0601, 2-eksen MIMO gimbalin **birincil sürücüsü** olarak (HP+LP tek kart) sunulur; donanım entegrasyonu **devam eden iş**, kontrol kıyası (Cascade/LQR/LQI/LQG) bu platform üzerinde simülasyon/tasarım çerçevesinde.
