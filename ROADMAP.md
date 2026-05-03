# ROADMAP — Aşama 2 Yol Haritası

> **Bu doküman canlıdır.** Her milestone tamamlandığında Claude Code güncelleyecek.
>
> - **Son güncelleme:** 2026-05-03
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

- [ ] **2A.1** — Encoder TIM2 implementasyonu (`Encoder_Init`, `Encoder_GetCount`, `Encoder_Reset`, `Encoder_GetSpeed`). PA15+PB3 GPIO_PULLUP, AF1, encoder mode TI12, both edges. Build kontrol.
- [ ] **2A.2** — USB CDC formatına `EC:%ld` (encoder count) eklenmesi. `plot_angles.py` 5. paneli (encoder count) eklenecek şekilde güncelle.
- [ ] **2A.3** — TB6612 PWM implementasyonu (`Motor_Init` TIM3 + GPIO, `Motor_Enable`, `Motor_Disable`). PB0 AF2, PB12-14 GPIO out (başlangıç LOW). 20 kHz PWM doğrulanır.
- [ ] **2A.4** — TB6612 temel sürücü (`Motor_SetDir`, `Motor_SetDuty`). `MOTOR_MAX_DUTY = 0.50f` hard cap içeride. Naive AIN1/AIN2 set (donanım dead-time yeterli).
- [ ] **2A.5** — Soft-start (`Motor_SoftStart` 200 ms / 40 step, `Motor_SetDuty` içinde |Δduty| > 0.10 ise otomatik 10 ms / 0.01 step rampa).
- [ ] **2A.6** — `Motor_Stop` (PWM=0, dir=STOP) ve `Motor_EmergencyStop` (STBY=L + duty=0 + AIN=0).
- [ ] **2A.7** — `Motor_StallCheck()` 50 Hz ana döngüden çağrılır. Tetik koşulu: |encoder_speed| < 5 rad/s VE |duty| > 0.20 VE 200 ms süre. Tetiklenince: `Motor_EmergencyStop()` + USB CDC'ye `STALL_DETECTED` + LED 5 Hz.
- [ ] **2A.8** — 5 sn lock-out: stall sonrası `Motor_Enable`/`Motor_SetDuty` çağrıları reddedilir; süre dolunca otomatik açılır VEYA kullanıcı reset atana kadar kilitli kalır (karar: kullanıcı reset, `Motor_ResetLockout()` API'si).
- [ ] **2A.9** — LED durum kodları: normal=500 ms toggle, soft-start aktif=250 ms toggle, stall=100 ms toggle (5 Hz).
- [ ] **2A.10** — README §8.6 koruma katmanları bölümü → "implementasyon tamamlandı" notu.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2A.T1 | **Encoder mekanik** — Motor şaftını elle 1 tam tur çevir | ~1862 count (192 × 9.7), CW/CCW yön tutarlı | ☐ |
| 2A.T2 | **PWM duty linearitesi** — %20, %30, %40, %50 duty | Encoder hızı kabaca lineer artar (sanity check) | ☐ |
| 2A.T3 | **Yön kontrolü** — `Motor_SetDir(CW)`, `(CCW)`, `(BRAKE)` | Encoder yönü ve durma davranışı beklendiği gibi | ☐ |
| 2A.T4 | **Soft-start** — `Motor_SoftStart(0.40)` | Encoder hızı 0'dan ~200 ms içinde lineer artar | ☐ |
| 2A.T5 | **Stall detection (KRİTİK)** — Şaftı elle sıkıca tut, `Motor_SoftStart(0.40)` | ~200 ms içinde stall tetiklenir, motor keser, `STALL_DETECTED` USB'den, LED 5 Hz, 5 sn lock-out. Multimetre ile akım <0.9 A doğrulansın | ☐ |
| 2A.T6 | **Watchdog hazırlığı** | API yazılı, 2A'da bypass — 2B'de aktive | ☐ |

### Riskler / Açık Sorular

- **R1**: Pololu enkoder pull-up gerçekten gerekli mi? GPIO_PULLUP zarar vermez ama push-pull ise çıkış akımı artar (~50 µA, ihmal). 2A.T1 başarısızsa pull konfigürasyonu gözden geçirilecek.
- **R2**: TB6612 modülünün üzerindeki gömülü kapasitörlerin değeri biliniyor mu? Datasheet 10 µF + 0.1 µF tipik diyor; modül üreticisi (Robotistan/Direnç) sayfasında belirtilmemiş. Stall sırasında VM voltajı düşerse harici kapasitör eklenebilir.
- **R3**: Mervesan 36 W (3 A) adaptör motor stall altında 12 V tutabilir mi? Aşama 2B.T2'de ölçülecek; droop > %10 ise modele dahil edilecek.
- **R4**: Stall lock-out süresi 5 sn yeterli mi yoksa kullanıcı reset zorunlu olmalı mı? İki yaklaşım da implemente edilebilir; varsayılan: 5 sn otomatik açılma + `Motor_ResetLockout()` API'si erken açmak için.
- **R5**: Aşama 2A boyunca komut girişi yok (sabit duty test). Watchdog 2B'de aktive olduğunda mevcut sabit-duty testleri etkilenmez (tek yönde duty komutu zaten 1 sn'den kısa).

### Tamamlanma Kanıtı

> _Aşama tamamlandığında doldurulacak._

- Commit hash'leri: _(her adım için 2A.X)_
- Encoder mekanik test screenshot: _(plot_angles.py 5. panel)_
- Stall detection test logu/video: _(USB CDC çıktısı + LED gözlemi)_
- README §8.6 sigortasız çalışma testi geçti notu: _(commit hash)_

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
- [ ] **2B.4** — Veri toplama: 30%, 40%, 50% duty (50% MOTOR_MAX_DUTY üst sınırı, üzeri çıkma). Her duty için ~5 sn kayıt, 0'dan başlatılarak.
- [ ] **2B.5** — Python fitting (`scripts/fit_motor.py`): `ω(t) = K·V·(1 − e^(−t/τ))`, Vsat=0.5V düzeltmesi. Üç duty'den parametre konsistens kontrolü.
- [ ] **2B.6** — Ölü-bant tespiti: %5'lik step'lerle minimum hareket eden duty.
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

## Aşama 2D — Pozisyon Kontrolü + IMU Stabilizasyon

### Hedef
Dış döngü pozisyon kontrolcüsü ile motor ekseninde "kamera kolu" sabit duracak; tabanı eğmek motoru ters yönde ezzaman süreceği için kol açısı bozulmayacak.

### Önkoşul
- ✅ Aşama 2C hız döngüsü stabil

### Adımlar

- [ ] **2D.1** — Dış döngü P kontrolcü; setpoint başlangıçta sabit 0°. Ölçü: encoder pozisyon (count → derece, 1862 count/devir × 9.7 redüktör).
- [ ] **2D.2** — Cascade: dış döngü P çıkışı → iç döngü hız setpoint'i.
- [ ] **2D.3** — IMU bağlantısı: setpoint = `−fused_pitch`. Tabanı eğdiğimde motor tersine süreceği için kol yatay kalacak.
- [ ] **2D.4** — **Duty cap gevşetme kararı**: 2C testleri geçer ve sistem akım davranışı stabilse, MOTOR_MAX_DUTY %50 → %70'e çıkarılabilir. Karar bu aşamada test sonuçlarına göre verilir; ROADMAP güncellemesi gerektirir.

### Test ve Doğrulama

| # | Test | Beklenen | Tamamlandı |
|---|---|---|---|
| 2D.T1 | Sabit setpoint disturbance | Şaftı elle bozmaya çalış, geri 0°'ye döner | ☐ |
| 2D.T2 | IMU stabilizasyon (KRİTİK) | Tabanı ±30° eğ, kol açısı ±5° aralığında kalır | ☐ |
| 2D.T3 | Disturbance rejection oranı | (kol açısı RMS) / (taban açısı RMS) < 0.2 | ☐ |

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
