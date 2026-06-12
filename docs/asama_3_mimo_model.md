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

### 12.3. Firmware — Encoder-2 + Motor-2 sürücü + eksen mimarisi (3.2–3.3)

**3.2a — Encoder-2 (✅ bench PASS).** TIM1 (PA8/PA9) 16-bit quadrature + **yazılım 32-bit
genişletme** (int16 delta birikimi, wrap-safe): TIM1 16-bit'tir (enc-1'in TIM2'si 32-bit'ti),
466 count/devirde ±70 çıkış devrinde sarar; `Encoder2_GetCount` her okumada delta'yı 32-bit
akümülatöre ekler. Telemetri alanı **`EC2`**. Bench: EC2 her iki yönde 4843 count menzili,
çapraz-konuşma (motor-1 sürülürken EC2 kayması) 0 → `artifacts/3/enc2_test/`. Nerede:
`src/encoder.c` `Encoder2_Init/GetCount/Reset`.

**3.2b — Motor-2 sürücü (firmware ✅, bench testi bekliyor).**

- **Ne:** 2. TB6612'nin A-kanalı için **minimal açık-döngü** sürücü — `Motor2_Init/Enable/
  SetDutySigned/Stop/EmergencyStop` (`src/motor.c`). PWM **PB1=TIM3_CH4**, motor-1 ile **aynı
  `htim3`** üzerinde (bağımsız CCR, ekstra timer yok); yön **PB4/PB5** (GPIO), STBY-2 **PB10**.
- **Neden minimal (stall yok):** 3.2b yalnız yön/kimlik doğrulaması ister. Stall-detection +
  shared-struct refactor **3.3 baseline'a** ertelendi (motor-2 kapalı-döngüye geçince, her iki
  motor da stall'a ihtiyaç duyduğunda tek-kaynak refactor değerlendirilir). Sertifikalı motor-1
  kodu **dokunulmadı** (sıfır regresyon). Emniyet: watchdog (1 sn komutsuz → her iki motor durur)
  + duty-cap %50 (stall ≤0.8 A < TB6612 1.0 A, `[TB6612_DS]` sf 3) + denetimli kısa sürüş.
- **Nasıl kullanılır:** `DUTY2:<signed>` komutu (mod-bağımsız, rampasız, ±%50 clamp); telemetri
  alanı **`U2`** (motor-2 uygulanan signed duty) → EC2 ile yön korelasyonu. `STOP`/`RESET`/watchdog
  motor-2'yi de durdurur.
- **Doğrulama testi (kimlik/yön):** `scripts/motor2_sign_test.py` — motor-1'i referans sürer,
  motor-2'yi ±duty'de sürer, **polariteyi ampirik saptar** (motor-2 duty→encoder işareti motor-1
  ile **AYNI mı TERS mi**). Bu, 3.3 baseline'da Aşama-2 cascade'inin geri-besleme işareti için
  kritik: ters polarite → pozitif geri besleme → kaçış. PASS = motor-2 iki yönde döndü + işaretler
  zıt + ref döndü (FALSE-PASS önleme: ölü motor PASS vermez). Çıktı: `artifacts/3/motor2_sign/`.
- **Build:** PASS (Flash %8.4). **Bench (2026-06-09):** Motor-2 ✅ **PASS** — `DUTY2:±0.30`'da
  +1203 / −1199 count/s (simetrik, temiz), EC2 her iki yönde takip etti; **polarite +duty→+count
  = motor-1 ile AYNI** → 3.3 baseline'da Aşama-2 cascade'i motor-2'ye **işaret çevirmeden**
  yeniden kullanılabilir. `artifacts/3/motor2_sign/20260609_175520/`.

**3.3 — Instance-based eksen mimarisi (firmware ✅, 2026-06-11).** Tek-motor-ilerleme kararı
(aşağıdaki bulgu kutusu) üzerine tüm kontrol/güvenlik modülleri **instance-based** refactor edildi
(commit `9def197`): `SpeedPI_t`/`PositionP_t`/`SpeedFilter_t`/`MotorCh_t` + `axis.h` `g_axis[2]`
eksen demeti. **Cascade + MIRROR artık eksen-1'de (motor-2) bugün kullanılabilir** — komutlar
kök+`2` sonekiyle eksen-1'e yönlenir (`MODE2:POS`, `POS_DEG2:`, `KPP2:` …); eski komutlar
eksen-0'a (geriye uyumlu). Motor-2 böylece **stall-detection da kazandı** (3.2b'de ertelenen).
Telemetri eski alanları birebir korur + `OMEGA2/SP2/TR2` (10/10 script regex'i doğrulandı —
mevcut bench scriptleri değişmeden çalışır). Davranış-koruma: **21-ajanlı adversarial denetim**
(eski-HEAD vs yeni, her bulgu bağımsız doğrulama) 3 gerçek farkı yakaladı → 2'si düzeltildi
(RESET'te düşen motor-2 Stop; geçersiz `MODE:X`'in watchdog'u beslemesi), 1'i bilinçli kabul
(`DUTY2` artık eksen-1 DUTY-modu şartlı — `MODE2:POS`'tayken açık-döngü komutu cascade ile
çakışamaz; eski mod-bağımsız 3.2b semantiğinin güvenli daraltılması). Yeni motor entegrasyonu:
yalnız ünite değişir + yön/kimlik testi — **kod değişikliği gerekmez**.

> **⚠ Bench bulgusu — motorların karakteri farklı:** Rewire'da fiziksel roller değişti —
> Aşama 1-2'de karakterize edilen **sağlıklı ünite şimdi motor-2** (K=53.89, τ=60.5 ms; bench'te
> de iki yön simetrik). **Motor-1 fiziksel ünitesinde yöne-bağlı mekanik kusur var:** CCW serbest
> döner (−2065 count/s) ama **CW yönünde 0.50 duty'de bile periyodik takılır** (fit-fit, sürekli
> stall'a düşer; elle de bir yön belirgin zor). Görünür dış engel yok → gearbox-içi asimetri.
> Derin teşhis (2026-06-09/11): yüksek tork (0.8 duty) catch'i AŞMADI (tork↑ → CW rate↓:
> 165→40 count/s — stiction değil, sert mekanik blok); gearbox çıkarılınca da bind sürdü
> (motor-içi); dislodge/agitasyon çözmedi; CCW 2.5 sn'de 26.5 tur pürüzsüz → sargı/sürücü sağlam.
> **Kurtarılamaz — iki-yönlü kontrol için ünite değişmeli.**
>
> **Karar (kullanıcı, 2026-06-11):** Aynı motorun **redüktörsüzü sipariş edildi**; sağlam gearbox
> ona takılacak (eksen mekanik birebir korunur). O gelene kadar **proje TEK SAĞLAM MOTOR
> (motor-2 ekseni) üzerinden ilerletilip tamamlanır** — 3.3 instance-based mimari bunu sağlar.
> Yeni motor gelince: yön/kimlik testi (`motor2_sign_test.py` benzeri) + entegrasyon; kod değişmez.

### 12.4. Sistem tanımlama planı (3.4–3.5)

*(SISO↔MIMO veri toplama: her motoru ayrı sür, diğer ekseni ölç; eleman-bazlı `tfest`. Yöntem:
baseline-önce — 3.3'te Aşama-2 cascade'i iki eksene yeniden-kullanılır, sonra kuplaj ölçülüp
kanıta-dayalı MIMO kontrolcü, ROADMAP §3.)*

### 12.5. Açık konular

- ✅ Pin planı (3.1) — KARAR verildi, kablolama tamamlandı (2026-06-08); §12.2 şema
- ✅ Encoder-2 firmware (3.2a): TIM1 16-bit + yazılım count-genişletme — bench PASS
- ✅ Motor-2 sürücü (3.2b): firmware + bench PASS (polarite +duty→+count = motor-1 ile AYNI)
- ⚠ **Motor-1 ünitesi CW'de kurtarılamaz mekanik kusurlu** (teşhis tamam: motor-içi, tork/dislodge çözmedi) — **redüktörsüz yedek sipariş edildi** (sağlam gearbox ona takılacak); o gelene kadar **tek sağlam motor (motor-2 ekseni) ile ilerleme** (kullanıcı kararı 2026-06-11)
- ✅ Eksen mimarisi (3.3): instance-based `g_axis[2]` firmware + **motor-2 cascade bench PASS** (2026-06-12): `MODE2:POS` 6/6 segment temiz (ss_err<1°, OS<1°, limit-cycle yok — Test 2.5 ile birebir), refactor davranış-koruma gerçek-donanımda kanıtlandı. `artifacts/3/cascade_m2/20260612_115042/`
- ✅ **Tek-eksen MIRROR + STABILIZASYON bench PASS** (motor-2, 2026-06-12):
  - `MODE2:MIRROR` (taklit, +pitch): takip RMS **5.53°** (Aşama 2.7 4.02° ile mertebe-uyumlu), FP aralığı 159°. `artifacts/3/mirror_m2/20260612_120636/`
  - `MODE2:STAB` (stabilizasyon, −pitch): motor IMU eğimine **TERS** döndü (FP+57°→θ−28°, FP−47°→θ+62° …), takip RMS 6.72°, FP aralığı 123° → **stabilizasyon yasası gerçek-donanımda demoland**. `artifacts/3/stab_m2/20260612_121945/`
  - ⚠ IMU şu an base'de (payload'da değil) → yasa demosu; tam eylemsiz doğrulama Aşama 5 (IMU payload'a).
  - Donanım notu: jumper bağlantı breadboard'dan sağlıklı → IMU uyku sorunu (güç-glitch) çözüldü; firmware sertleştirmesi (`94a36e3`: uyku-tespiti auto-wake + non-blocking init) yedek koruma.
- ⬜ Yeni motor (redüktörsüz, siparişte) gelince: gearbox transferi + yön/kimlik testi + eksen-0 entegrasyon → 3.4 MIMO ID
- ⬜ ACS712 Faz-2 entegrasyonu (duty %100 gevşetme ön koşulu)
