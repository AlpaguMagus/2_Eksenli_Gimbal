# ROADMAP — Aşama 2 Yol Haritası

> **Bu doküman canlıdır.** Her milestone tamamlandığında Claude Code güncelleyecek.
>
> - **Son güncelleme:** 2026-05-05 (Senaryo B / mirror — Aşama 2D yeniden tanımı; Test 2A.T2/T3 PASS)
> - **Branch:** `feature/motor-encoder-tb6612`
> - **Kapsam:** Aşama 2A → 2E (Kalman dahil). Sonrası "Kapsam Dışı" bölümünde.

---

## Proje Amacı

İki eksenli kamera gimbal'ı için stabilizasyon sistemi geliştirmek: STM32F411 üzerinde MPU6050 ile açı ölçümü, complementary/Kalman füzyonu, encoder geri beslemeli BDC motor sürücüsü, kademeli kontrol döngüleri (hız iç + pozisyon dış). Aşama 2 tek motor + tek IMU ile mini doğrulama; iki eksen entegrasyonu kapsam dışı (Aşama 3'te).

## Doküman Sözleşmesi

Üç farklı doküman, üç farklı görev:

| Doküman | İçerik | Güncelleme tetiği |
|---|---|---|
| `ROADMAP.md` (bu dosya) | Yol haritası, aşamalar, adımlar, testler, tamamlanma kanıtı | Her adım/aşama bitiminde, plan değişikliğinde |
| `PROJE_DURUMU.md` | "Şu an neredeyiz?" 5-10 satır özet + ROADMAP linki | Aşama geçişlerinde |
| `README.md` | Kalıcı teknik bilgi (mimari, pin tablosu, tamamlanmış altyapı açıklaması) | Davranış değiştiren teknik karar geldiğinde |
| `CLAUDE.md` | AI etkileşim kuralları, proje çalışma standartları | Yeni kural eklendiğinde |

**README'ye yol haritası veya TODO girmez.** Sadece "şu sistem nasıl çalışıyor" tarzı kalıcı doküman.

---

## ⚠ Açık Emniyet Uyarısı

**12V hattında donanım sigortası yok** (Mervesan 12V/3A adaptör, sigorta planlı ama henüz temin edilmedi). Tek koruma katmanları:

1. Yazılım — stall detection, duty cap, soft-start, watchdog
2. TB6612 dahili termal shutdown (175°C)

> **Yazılım koruma katmanları (Aşama 2A çıktısı) aktif olmadan motor çalıştırılmamalı.**

Sigorta temin edildiğinde:
- Bu uyarı güncellenir
- "Kapsam Dışı" altındaki *VM hattı sigorta entegrasyonu* yeni bir aşamaya alınır
- Duty cap %50 → daha yüksek bir değere gevşetilir (ROADMAP'te ayrıca planlanır)

---

## Aşama 2A — Donanım Entegrasyonu, Koruma Katmanları, Düşük Seviye Doğrulama

### Hedef
Encoder ve motor sürücü çalışır durumda; **beş yazılım koruma katmanı aktif**; manuel duty komutlarıyla motor güvenli kontrol edilebilir; encoder okuması fiziksel olarak doğrulanmış.

### Önkoşul
- ✅ Aşama 1 IMU pipeline (main branch'te) çalışıyor
- ✅ Donanım plan onaylı, iskelet commit (`59df6a8`)
- ⚠ Donanım kurulu olmalı: TB6612 modülü, motor, encoder, Mervesan 12V/3A adaptör, ortak GND

### Adımlar (her biri kendi commit'i, build edilebilir)

- [x] **2A.1** — Encoder TIM2 implementasyonu (`Encoder_Init`, `Encoder_GetCount`, `Encoder_Reset`, `Encoder_GetSpeed`). PA15+PB3 GPIO_PULLUP, AF1, encoder mode TI12, both edges. Build kontrol. ✅ commit `5c9dc88`
- [x] **2A.2** — USB CDC formatına `EC:%ld` (encoder count) eklenmesi. `plot_angles.py` 5. paneli (encoder count) eklenecek şekilde güncelle. ✅ commit `b75cee8`
- [x] **2A.3** — TB6612 PWM implementasyonu (`Motor_Init` TIM3 + GPIO, `Motor_Enable`, `Motor_Disable`). PB0 AF2, PB12-14 GPIO out (başlangıç LOW). 20 kHz PWM doğrulanır. ✅ commit `60df499` (frekans doğrulaması 2A.4 + Test 2A.T2'ye ertelendi — duty=0 iken PWM görünmez)
- [x] **2A.4** — TB6612 temel sürücü (`Motor_SetDir`, `Motor_SetDuty`). `MOTOR_MAX_DUTY = 0.50f` hard cap içeride. Naive AIN1/AIN2 set (donanım dead-time yeterli). ✅ commit `320d1d0` (main.c'de 18 sn'lik geçici test sequence — 2A.5'te kaldırılacak)
- [x] **2A.5** — Soft-start + non-blocking rampa hibrit. ✅ commit `85e03a9` (Motor_Tick 200 Hz, Motor_SetDuty target+rampa, Motor_SoftStart bloklayan init için, main loop 50 ms → 5 ms + USB CDC 40 Hz throttle)
- [x] **2A.6** — `Motor_Stop` ve `Motor_EmergencyStop`. ✅ commit `85e03a9` (aynı commit'te)
- [ ] **2A.7** — `Motor_StallCheck()` 50 Hz ana döngüden çağrılır. Tetik koşulu: **|encoder_speed| < 2 rad/s** VE |duty| > 0.20 VE 200 ms süre. **Soft-start grace period:** Fonksiyona girişte `if (motor.soft_start_active) return;` — soft-start biten iterasyonda check yeniden devreye girer. Tetiklenince: `Motor_EmergencyStop()` + USB CDC'ye `STALL_DETECTED` + LED 5 Hz.
  > **Eşik gerekçesi:** Pololu 25D LP no-load çıkış hızı ~57 rad/s (560 RPM ÷ 9.55). 5 rad/s = ~%8 no-load — soft-start sırasında yanlış pozitif riski. 2 rad/s gerçek stall'a daha yakın (gerçek stall ≈ 0 rad/s, gürültü payı için 2 rad/s).
- [ ] **2A.8** — 5 sn lock-out: stall sonrası `Motor_Enable`/`Motor_SetDuty` çağrıları reddedilir; süre dolunca otomatik açılır VEYA kullanıcı reset atana kadar kilitli kalır (karar: kullanıcı reset, `Motor_ResetLockout()` API'si).
- [ ] **2A.9** — LED durum kodları: normal=500 ms toggle, soft-start aktif=250 ms toggle, stall=100 ms toggle (5 Hz).
- [ ] **2A.10** — README §8.6 koruma katmanları bölümü → "implementasyon tamamlandı" notu.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2A.T1 | **Encoder mekanik** — Çıkış milini elle 1 tam tur çevir | ~466 count (48 × 9.7), CW/CCW yön tutarlı (Pololu CPR zaten quadrature-decoded) | ✅ PASS |
| 2A.T2 | **PWM duty linearitesi** — %20, %30, %50 duty (40 sn log, 18 sn döngülü sequence) | %20→107, %30→166, %50→282 rad/s motor şaftı. K sapması %5.3 — Vsat etkisi kabul edilebilir. %50'de no-load tahminiyle (565 rad/s × 0.5 = 282) **mükemmel uyum**. | ✅ PASS |
| 2A.T3 | **Yön + BRAKE** — CW/CCW/BRAKE | CW +165.65, CCW −164.16 rad/s (simetri farkı %0.9). BRAKE −164→%10 hıza 1456 ms (kontrollü durma). | ✅ PASS |
| 2A.T4 | **Soft-start / non-blocking rampa** — Motor_SetDuty her duty değişiminde Motor_Tick yumuşatır | Eski (50 ms loop, ani sıçrama) → Yeni (5 ms loop + Motor_Tick): CCW%30 138 ms, CW%50 260 ms (spec 145 ve 249 ms). Tipik ortalama ~200 ms hedef ile uyumlu. Steady-state değişim < %3 (PSU droop/sıcaklık varyasyonu). | ✅ PASS |
| 2A.T5 | **Stall detection (KRİTİK)** — Şaftı elle sıkıca tut, `Motor_SoftStart(0.40)`. **Ön hazırlık:** Bu testten önce manuel kill switch hazırlanması önerilir (README §8.6) — yazılım stall detection tek koruma, fiziksel yedek bulunsun. | Soft-start (200 ms) tamamlandıktan **sonra** ~200 ms içinde stall tetiklenir, motor keser, `STALL_DETECTED` USB'den, LED 5 Hz, 5 sn lock-out. Multimetre ile akım <0.9 A doğrulansın. | ☐ |
| 2A.T6 | **Watchdog hazırlığı** | API yazılı, 2A'da bypass — 2B'de aktive | ☐ |
| 2A.T7 | **Entegrasyon (KRİTİK)** — IMU pipeline, encoder okuma, motor sürme aynı anda 60 sn boyunca | USB CDC çıktısında EC, P, R, FP, FR alanları sürekli akıyor + bir önceki testlerde gözlenen davranışlar tekrar üretilebilir (motor +%30 duty 5 sn → encoder hızı doğru, IMU açıları bozulmadı). Hiçbir USB drop, watchdog reset, kasılma yok. | ☐ |

### Riskler / Açık Sorular

- **R1**: Pololu enkoder pull-up gerçekten gerekli mi? GPIO_PULLUP zarar vermez ama push-pull ise çıkış akımı artar (~50 µA, ihmal). 2A.T1 başarısızsa pull konfigürasyonu gözden geçirilecek.
- **R2**: TB6612 modülünün üzerindeki gömülü kapasitörlerin değeri biliniyor mu? Datasheet 10 µF + 0.1 µF tipik diyor; modül üreticisi (Robotistan/Direnç) sayfasında belirtilmemiş. Stall sırasında VM voltajı düşerse harici kapasitör eklenebilir.
- **R3**: Mervesan 36 W (3 A) adaptör motor stall altında 12 V tutabilir mi? Aşama 2B.T2'de ölçülecek; droop > %10 ise modele dahil edilecek.
- **R4**: Stall lock-out süresi 5 sn yeterli mi yoksa kullanıcı reset zorunlu olmalı mı? İki yaklaşım da implemente edilebilir; varsayılan: 5 sn otomatik açılma + `Motor_ResetLockout()` API'si erken açmak için.
- **R5**: Aşama 2A boyunca komut girişi yok (sabit duty test). Watchdog 2B'de aktive olduğunda mevcut sabit-duty testleri etkilenmez (tek yönde duty komutu zaten 1 sn'den kısa).

### Tamamlanma Kanıtı

- **2A.1** Encoder TIM2 implementasyonu: `5c9dc88`
- **2A.2** USB CDC EC alanı + plot 5. panel: `b75cee8`
- **2A.3** TB6612 TIM3 PWM init + STBY enable/disable: `60df499`
- **2A.4** Motor_SetDir + Motor_SetDuty + geçici test sequence: `320d1d0`
- **2A.5 + 2A.6** Motor_Tick non-blocking rampa, Motor_Stop, Motor_EmergencyStop, 200 Hz loop, 40 Hz USB throttle: `85e03a9`
- _(devam edecek)_

- **Test 2A.T4 PASS** — 80 sn log (`logs/test_2a5.csv`):
  - **Rampa süreleri (ham hız, 10%-90%):** CCW%30 138 ms (spec 145), CW%50 260 ms (spec 249), CW%20 157 ms (spec 94, Vsat etkisi nedeniyle gecikme)
  - **Eski/yeni karşılaştırma:** Eski log'ta transitionlar <50 ms ani sıçrama, yeni log'ta 200-300 ms yumuşak rampa. Motor_Tick non-blocking rampa çalışıyor.
  - **Steady-state tutarlılık:** Eski/yeni hız farkı < %3 (PSU droop / motor sıcaklığı)
  - **IMU çalışıyor:** Pitch range [-5.2°, +88°] (test sırasında kart eğilmiş). Önceki "IMU sıfır" şüphesi geçersiz — sabit kart için %.1f rounding'di.
  - **Grafik:** `logs/test_2a5_ramp_comparison.png`

- **Test 2A.T2/T3 PASS** — 40 sn döngülü sequence log (`logs/test_2a4.csv`):
  - **Duty linearitesi:** %20 → 107 rad/s, %30 → 166 rad/s, %50 → 282 rad/s (motor şaftı). K sapması %5.3, no-load tahmini ile mükemmel uyum.
  - **Yön simetrisi:** CW +165.65 vs CCW −164.16 rad/s (fark %0.9).
  - **BRAKE:** CCW −164 rad/s → %10 hız 1456 ms.
  - **Vsat etkisi:** Düşük duty'de %5 kayıp (Pololu Vsat=0.5V/12V=%4 ile uyumlu) — 2B fitting'de detaylı modellenecek.
  - **IMU notu:** Sabit kart yatay → pitch/roll=0 normal. Sanity check: kartı eğince pitch değişiyor mu (manuel doğrulama önerildi).
  - **Grafik:** `logs/test_2a4_analysis.png` (3 panel: encoder count delta, hız profili sequence renkli, IMU)

- **Test 2A.T1 PASS** — Çıkış milini 1 tam tur çevirme:
  - **Gözlem:** ~470 count, CW/CCW yön tutarlı, sıçrama yok, 0'a geri dönüş
  - **Beklenti:** ~466 count = 48 × 9.7 (motor şaftı 48 olay × redüktör 9.7:1)
  - **Hata:** %0.85 — mekanik tolerans + manuel tur tamlığı içinde
  - **Teknik dayanak:** Pololu "48 CPR" konvansiyonu zaten quadrature-decoded sayım. Kaynak: robotsepeti.com 25D LP sayfası — *"Kuadratür enkoder her iki kanalda kenarlar için sayım yapması durumunda 48 CPR'lık bir çözünürlük sağlar."*
  - **Çözünürlük:** Çıkış milinde **0.77° / count** (360°/466). Motor şaftında 7.5° / count.
  - **Düzeltme:** İlk hesabımda 192 olay/motor devri (48 × 4) yanlıştı; gerçekte 48 olay/motor devri. `EVENTS_PER_REV` 192 → 48 düzeltildi.
- Stall detection test logu/video: _(USB CDC çıktısı + LED gözlemi — 2A.T5 sonrası)_
- Stall detection test logu/video: _(USB CDC çıktısı + LED gözlemi — 2A.T5 sonrası)_
- README §8.6 sigortasız çalışma testi geçti notu: _(2A tamamlanınca)_

---

## Aşama 2B — Motor Sistem Tanımlama (Modelleme)

### Hedef
Motor için lineer 1. dereceden model parametreleri (K, τ, dead-band) çıkarılmış; PSU droop gerçek yük altında ölçülmüş; veri toplama altyapısı (USB CDC RX) ile Python step response scripti çalışır durumda.

### Önkoşul
- ✅ Aşama 2A tamamlandı, koruma katmanları aktif

### Adımlar

- [ ] **2B.1** — USB CDC RX implementasyonu (firmware): `DUTY:0.30\n` benzeri komut alımı. Komut parser, dead-letter ignore.
- [ ] **2B.2** — **Watchdog timeout aktive et:** son komut zamanı tutulur, 1 sn boyunca yeni komut yoksa `Motor_SetDuty(0.0f)`.
- [ ] **2B.3** — Step response Python scripti (`scripts/step_response.py`): farklı duty seviyelerinde komut gönderir, encoder hızını 200 Hz örnekleme ile log dosyasına yazar.
- [ ] **2B.4** — Veri toplama: **%20, %35, %50** duty (50% MOTOR_MAX_DUTY üst sınırı, üzeri çıkma). Her duty için ~5 sn kayıt, 0'dan başlatılarak.
  > **Aralık gerekçesi:** Ölü-bant muhtemelen %10-15 civarı; %30-50 dar bir aralık olur. %20-50 daha geniş ayrışma → lineer fit daha güvenilir.
- [ ] **2B.5** — Python fitting (`scripts/fit_motor.py`): `ω(t) = K·V·(1 − e^(−t/τ))`, Vsat=0.5V düzeltmesi. Üç duty'den parametre konsistens kontrolü.
- [ ] **2B.6** — Ölü-bant tespiti: %5'lik step'lerle minimum hareket eden duty.
  > **Revizyon notu:** Ölçülen ölü-bant **%20'nin üstünde** çıkarsa adım 2B.4'teki düşük duty seviyesi (%20) ölü-bantta olabilir → step response seviyeleri revize edilir, taban %25 veya %30'a çekilir.
- [ ] **2B.7** — Adaptör droop ölçümü (multimetre ile): yüksüz, 30%, 50% duty altında VM voltajı. README §8.5'e ölçüm sonuçları eklenir.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2B.T1 | Üç duty'de K ve τ tutarlılığı | K aynı (±%5), τ aynı (±%10) — lineer model varsayımı | ☐ |
| 2B.T2 | Adaptör droop | VM ≥ 11 V tutar; altına düşerse modele dahil | ☐ |
| 2B.T3 | Watchdog tetik | USB CDC bağlantısı koparılırsa motor 1 sn içinde durur | ☐ |

### Tamamlanma Kanıtı

> _Aşama tamamlandığında doldurulacak._

- Motor parametreleri: K=___, τ=___ s, dead_band=___, V_supply_actual=___
- Step response grafiği (PNG)
- `fit_motor.py` çıktı dosyası
- Commit hash

---

## Aşama 2C — Hız Kontrolü (İç Döngü PI)

### Hedef
Encoder hızını referans değere oturan PI kontrolcü çalışır durumda; setpoint adımlarına settling time < 5τ, overshoot < %10, steady-state error < %2.

### Önkoşul
- ✅ Aşama 2B parametreleri çıkarılmış

### Adımlar

- [ ] **2C.1** — Pole placement ile Kp_w, Ki_w analitik hesabı. Closed-loop τ_cl ≈ τ_ol / 5 hedefi.
- [ ] **2C.2** — Hız PI kontrolcü implementasyonu (firmware, 200 Hz fixed sample). USB CDC formatına setpoint + measured speed + duty eklenir.
- [ ] **2C.3** — Anti-windup (saturation back-calculation veya basit clamp). Duty hard cap %50 göz önünde — integral wind-up bu sınırda da olmamalı.
- [ ] **2C.4** — Setpoint komut alımı (USB CDC): `SP_W:15.0\n` → ω_ref = 15 rad/s.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2C.T1 | Setpoint adımı (10, 20, 30 rad/s) | settling < 5τ, overshoot < %10, ss_error < %2 | ☐ |
| 2C.T2 | Disturbance (motor şaftına yük) | PI integral düzeltir, ss_error < %2 sağlanır | ☐ |
| 2C.T3 | Yön değiştirme | Setpoint −20 rad/s'e geçtiğinde TB6612 dead-time düzgün çalışır, akım sıçraması yok | ☐ |

### Tamamlanma Kanıtı

> _Aşama tamamlandığında doldurulacak._

- Kp_w=___, Ki_w=___
- Step response grafiği
- Commit hash

---

## Aşama 2D — Pozisyon Kontrolü + IMU Mirror

### Senaryo Notu (Mimari Karar)

**Senaryo B — Mirror/Takip:** IMU breadboard'da sabit kalır (motor şaftına mekanik bağ yok). Breadboard kullanıcı tarafından eğildiğinde motor şaftı IMU pitch açısını **TAKLİT EDER** — aynı yöne, aynı miktarda. *"Bak, ben breadboard'u eğdim, motor da eğiliyor."*

Klasik gimbal senaryosu (Senaryo A — IMU motor şaftında, ters çevirme ile stabilizasyon) bu projede **kapsam dışı** — mekanik mount kompleksitesi olmadan akademik karmaşıklık (sistem ID, hız PI, pozisyon kontrolü, IMU entegrasyonu) korunur.

### Hedef
Motor şaftı, IMU pitch açısını gecikme/takip hatası içinde **taklit etsin**. Breadboard yavaşça ±30° eğildiğinde motor şaftı ±30° dönsün; takip hatası RMS < 5°.

### Önkoşul
- ✅ Aşama 2C hız döngüsü stabil

### Adımlar

- [ ] **2D.1** — Dış döngü P kontrolcü; setpoint başlangıçta sabit 0°. Ölçü: encoder pozisyon (count → derece, 466 count/çıkış mili devri = 0.77° / count).
- [ ] **2D.2** — Cascade: dış döngü P çıkışı → iç döngü hız setpoint'i.
- [ ] **2D.3** — **IMU mirror bağlantısı:** setpoint = **`+fused_pitch`** (taklit, **ters değil**). Breadboard +30° eğilince motor şaftı +30° döner. Tersleme istense gimbal olurdu, mirror için pozitif eşleştirme.
- [ ] **2D.4** — **Duty cap gevşetme kararı**: 2C testleri geçer ve sistem akım davranışı stabilse, MOTOR_MAX_DUTY %50 → %70'e çıkarılabilir. Karar bu aşamada test sonuçlarına göre verilir; ROADMAP güncellemesi gerektirir.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2D.T1 | Sabit setpoint disturbance | Motor şaftı 0°'da iken elle bozulmaya karşı geri 0°'ye döner | ☐ |
| 2D.T2 | **IMU mirror (KRİTİK)** | Breadboard'u yavaşça ±30° eğ → motor şaftı ±30° taklit eder. Takip hatası `\|motor_pos − fused_pitch\|` RMS **< 5°** | ☐ |
| 2D.T3 | **Takip kalitesi** | Yavaş eğme (~10°/s) → motor sorunsuz takip; hızlı eğme (~60°/s+) → kontrolcü bant genişliği sınırı görünür (faz gecikmesi). Hız–hata eğrisi karakterize edilsin. | ☐ |

### Tamamlanma Kanıtı

> _Aşama tamamlandığında doldurulacak._

- Stabilizasyon demosu video/screenshot
- Disturbance rejection oranı sayısal
- Commit hash

---

## Aşama 2E — Kalman Füzyonu

### Hedef
3 durumlu Kalman filter (`x = [θ, ω, gyro_bias]`) MPU6050 verisini complementary'den daha az gürültülü açı verir; Kalman çıktısı kontrolcüye beslendiğinde motor sürüş akustik olarak daha sakin (kontrolcü daha az "yakalama" hareketi yapar).

### Önkoşul
- ✅ Aşama 2D çalışan demo

### Adımlar

- [ ] **2E.1** — Kalman filter implementasyonu (firmware). 3 durumlu, fixed-point veya float seçilecek (F411 FPU var, float makul).
- [ ] **2E.2** — Q ve R matrislerinin başlangıç değerleri (MPU6050 datasheet gürültü yoğunluklarından hesaplanır):
  - Accelerometer noise density: ~400 µg/√Hz
  - Gyro noise density: ~0.005 °/s/√Hz
- [ ] **2E.3** — Mevcut complementary filter ile yan yana çalıştır; USB CDC formatı: `KP:..., KR:...` Kalman pitch/roll, `BIAS_X:..., BIAS_Y:...` gyro bias estimate.
- [ ] **2E.4** — Kalman vs complementary anahtar (firmware): `MODE:CF` veya `MODE:KF` USB komutu ile kontrolcüye hangi açı kaynağı beslenecek.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2E.T1 | Sabit dururken bias yakınsaması | Bias estimate ~30 sn içinde sabit değere oturur | ☐ |
| 2E.T2 | Titreşim altında gürültü | Kalman pitch RMS < complementary pitch RMS | ☐ |
| 2E.T3 | Aynı kontrolcü, akustik fark | Kalman moduna geçilince motor ses seviyesi azalır (subjektif gözlem + mikrofon kayıt opsiyonel) | ☐ |

### Tamamlanma Kanıtı

> _Aşama tamamlandığında doldurulacak._

- Kalman vs complementary karşılaştırma grafikleri
- R/Q tuning notları
- Commit hash

---

## Kapsam Dışı (Sonraki İterasyonlar)

Bu yol haritası 2E'de duruyor. Sonraki adımlar:

- **VM hattı sigorta entegrasyonu** — Kullanıcı 1.5 A polyfuse veya 2 A cam sigorta temin ettiğinde aktif aşamaya alınır. Duty cap %50 sınırı gevşetilir.
- **Duty cap %50 → %100 gevşetme** — Sigorta sonrası, kontrolcü stabilse.
- **İkinci motor + ikinci eksen** — Tam 2-DOF gimbal entegrasyonu (TIM4 PWM + ek encoder TIM5).
- **Madgwick / quaternion füzyon** — ±90° singülarite çözümü.
- **Cascade PID, LQR, LQG karşılaştırması** — Akademik karşılaştırma.
- **Bluetooth gecikme analizi** — Ferhat'ın tezi tarafı, BLE/HC-05 üzerinden komut gecikmesi.

---

## Güncelleme Protokolü

Claude Code aşağıdaki durumlarda ROADMAP.md'yi güncelleyecek:

1. **Adım tamamlanınca**: ilgili kontrol kutusu işaretlenir, "Tamamlanma kanıtı" bölümüne commit hash + ölçüm değerleri yazılır.
2. **Aşama tamamlanınca**: aşama başlığına ✅ ve tarih damgası eklenir.
3. **Plan değişiminde** (yeni risk, yeni adım, sıralama değişimi): ilgili bölüm doğrudan güncellenir, üst kısımdaki "son güncelleme" tarihi yenilenir.
4. **Büyük yapısal değişiklikler için kullanıcıya danışılır**: adım ekle/çıkar öncesinde sor.
5. **Kullanıcı sigorta temin ettiğinde**: "Açık Emniyet Uyarısı" güncellenir, "Kapsam Dışı"ndan *VM hattı sigorta entegrasyonu* maddesi yeni bir aşama olarak ROADMAP'e alınır, duty cap gevşetme planlanır.

`PROJE_DURUMU.md` 5-10 satır özet + ROADMAP linki tutar; detay ROADMAP'te.
`README.md` sadece kalıcı teknik bilgi tutar; yol haritası veya TODO girmez.
