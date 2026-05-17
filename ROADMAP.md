# ROADMAP — İki Eksenli Gimbal Geliştirme Yol Haritası

> **Bu doküman canlıdır.** Her milestone tamamlandığında güncellenir.
>
> - **Son güncelleme:** 2026-05-18 (Aşama 1 KAPALI — tek motor sistem tanımlama tamamlandı, K=53.89 rad/s/V, τ=60.5 ms, validation NRMSE ort %11.11)
> - **Aktif aşama:** Aşama 1 ✅ KAPALI → Aşama 2 (tek motor kontrol) açılışı
> - **Kapsam:** Aşama 0 (donanım entegrasyonu) → Aşama 5 (gerçek 3D-print gimbal MIMO stabilizasyon)

---

## Vizyon

İki eksenli kamera gimbal'ı için **akademik açıdan zengin**, kaynaklı, MATLAB destekli kontrol mühendisliği projesi:

1. **Tek motor** ile sistem tanımlama → modelleme disiplinini öğren
2. **Tek motor** üzerinde klasik PI/PID + cascade → kontrol teorisini uygula
3. **İki motor** MIMO sisteminde modelleme + decoupling → çok değişkenli sistem
4. **İki motor** üzerinde modern kontrol (LQR/LQG + Kalman) → akademik derinlik
5. **Gerçek 3D-print gimbal** entegrasyonu → uçtan uca demo + tez/sunum materyali

**Felsefe:** Her teknik karar için *kaynak + alternatif + trade-off + bilinçli seçim*. Ferhat'ın tezi kutsal değil; bağımsız literatür temeli (`KAYNAKCA.md`) bu projeyle birlikte kuruluyor.

**Paralel araçlar:** MATLAB (System Identification, Control System, Simulink, Optimization toolbox'ları) + STM32Cube HAL (C, bare-metal). Embedded Coder kullanılmaz; MATLAB çıktıları manuel transfer.

## Doküman Sözleşmesi

| Doküman | İçerik | Güncelleme tetiği |
|---|---|---|
| `ROADMAP.md` (bu dosya) | Yol haritası, aşamalar, adımlar, testler, tamamlanma kanıtı | Her adım/aşama bitiminde |
| `PROJE_DURUMU.md` | "Şu an neredeyiz?" 5-10 satır özet + ROADMAP linki | Aşama geçişlerinde |
| `README.md` | Kalıcı teknik bilgi (mimari, pin tablosu, tamamlanmış altyapı) | Davranış değiştiren teknik karar |
| `CLAUDE.md` | AI etkileşim kuralları + proje standartları | Yeni kural eklendiğinde |
| `KAYNAKCA.md` | Etiketli akademik referanslar + datasheet'ler | Her yeni teknik karar |
| `matlab/<aşama>/README.md` | Aşama-spesifik MATLAB workflow | Aşama açılışında |

**README'ye yol haritası veya TODO girmez.** Sadece "şu sistem nasıl çalışıyor" tarzı kalıcı doküman.

---

## ⚠ Açık Emniyet Uyarısı

**12V hattında donanım sigortası yok** (Mervesan 12V/3A adaptör, sigorta planlı ama henüz temin edilmedi). Tek koruma katmanları:

1. **Yazılım** — stall detection, duty cap %50, soft-start rampa, watchdog (Aşama 0'da implementasyon tamamlandı)
2. **TB6612 dahili termal shutdown** — 175°C tetik (datasheet sf 5)

> **Yazılım koruma katmanları aktif olmadan motor çalıştırılmamalı.**

Sigorta temin edildiğinde:
- Bu uyarı güncellenir
- "Kapsam Dışı"ndan *VM hattı sigorta entegrasyonu* yeni aşamaya alınır
- Duty cap %50 → daha yüksek değere gevşetilir

---

## ✅ Aşama 0 — Donanım Entegrasyonu, Koruma Katmanları, USB Komut Altyapısı  *(KAPALI 2026-05-17)*

> **Not (vizyon yenileme):** Bu aşama önceki yapıda "Aşama 2A + 2B.1-2" olarak bilinen kısmı kapsar. Yeni 5-aşamalı yapıda "Aşama 0 — temel altyapı" rolündedir. Bundan sonra modelleme = Aşama 1.

### Hedef (gerçekleşen)
- ✅ IMU pipeline (MPU6050 + complementary filter)
- ✅ Encoder TIM2 quadrature, Pololu 48 CPR konvansiyonu
- ✅ TB6612 PWM (20 kHz) + non-blocking rampa
- ✅ Beş yazılım koruma katmanı (stall + duty cap + soft-start + watchdog + LED)
- ✅ USB CDC iki yönlü (TX: telemetri, RX: DUTY/STOP/RESET/PING komutları)
- ✅ Watchdog 1 sn timeout
- ✅ Test artifact disiplini (`artifacts/<faz>/<test_id>/`)

### Tamamlanma Kanıtı

| Bileşen | Commit | Test artifact |
|---|---|---|
| Encoder TIM2 + 48 CPR | `5c9dc88`, `b75cee8` | `artifacts/2A/T1_encoder/` |
| TB6612 PWM + yön + duty | `60df499`, `320d1d0` | `artifacts/2A/T2_duty/` |
| Non-blocking rampa (200 Hz) | `85e03a9` | `artifacts/2A/T4_rampa/` |
| Stall detection + lockout + LED | `77899d7`, `bc504b5` | (KEY simülasyon PASS) |
| Entegrasyon 135 sn | `f8bf5c7` | `artifacts/2A/T7_integration/` |
| USB RX komut parser + OMEGA | `0f27dd3` | — |
| Watchdog 1 sn | `4d6d047` | — |
| Handshake sanity | `02bd1ee` | `artifacts/2B/F2_handshake/` |
| Logging disiplini | `94ab1db` | (CLAUDE.md güncellendi) |

### Açık Konu (Aşama 0 → 1'e taşınan)

- **2A.T5-B (gerçek motor stall testi):** KEY simülasyonu (Aşama A) PASS. Gerçek motor stall (eldivenle şaftı tut + multimetre <0.9 A) bağımsız donanım doğrulaması, sonraki seansa bırakıldı — Aşama 1'i engellemiyor.
- **R6 (CW%20 ölü-bant değişkenliği):** Test 2A.T2'de +107 rad/s, Test 2A.T7'de +0 rad/s. Aşama 1.3 (dead-band fitting) bu varyasyonu nicelendirecek.

---

## ✅ Aşama 1 — Tek Motor Sistem Tanımlama  *(KAPALI 2026-05-18)*

> **Branch:** `feature/asama-1-tek-motor-model`
> **MATLAB:** `matlab/asama_1_model/`
> **Veri:** `artifacts/1/step_response/20260518_011926/`
> **Sonuçlar:** `matlab/asama_1_model/results/20260518_011926/`
> **README §10** — el kitapçığı disipliniyle akademik kapanış

### Vizyon

Tek motor için **parametrik 1. derece + dead-band** model. Hocaya sunulabilir kalitede:
- Veri toplama scripti (`scripts/step_response.py`)
- MATLAB tabanlı fit (`tfest` veya `curve_fit`)
- Simulink doğrulama (model output vs ölçüm)
- Akademik rapor (`fit_report.md` + PNG'ler)

**Model:**
```
ω(t) = K · max(V_eff − V_dead, 0) · (1 − e^(−t/τ))
V_eff = V_supply · duty − V_sat,   V_supply=12.15 V,  V_sat=0.5 V
```

**Kaynaklar:** `[Ljung1999] §3, §16`, `[Franklin2010] §3`, `[TB6612_DS] §1`, `[Pololu_25D]`.

### Önkoşul
- ✅ Aşama 0 KAPALI
- ✅ USB CDC komut altyapısı çalışıyor
- ✅ MATLAB kurulu (`mcp__matlab__detect_matlab_toolboxes` ile doğrulanacak)

### Alt-Aşamalar (yüksek seviye)

> Alt-aşama detayları (adımlar + testler) **her alt-aşama açılışında** sokratik tartışma sonrası eklenecek. Şu an iskelet:

- **1.1 — Veri toplama altyapısı:** `scripts/step_response.py` Python tarafı (handshake_test.py temel alınarak). 6 duty × 2 yön = 12 step. 200 Hz örnekleme. Çıktı: `artifacts/1/step_response/<test_id>/raw/data.csv.gz` + meta.json + summary.md.
- **1.2 — Step bazlı 1. derece fit:** MATLAB'da her step için `tfest` veya `lsqcurvefit`. Her step → (K_i, τ_i, ω_ss_i).
- **1.3 — Dead-band tespiti:** ω_ss vs V_eff lineer regresyon, x-intercept = V_dead. R6 (CW%20 değişkenliği) bu adımda nicelendirilecek.
- **1.4 — CW/CCW simetri analizi:** K_cw vs K_ccw, V_dead_cw vs V_dead_ccw. Yön farkı kayıt altına alınır.
- **1.5 — Simulink doğrulama:** Model bloğu kurulur, aynı duty profil koşturulur, RMSE/NRMSE hesaplanır.
- **1.6 — Akademik rapor:** `matlab/asama_1_model/results/fit_report.md` + PNG'ler. Hocaya sunulabilir kalite.

### Test ve Doğrulama (gerçekleşen)

| # | Test | Beklenen | Ölçülen | Durum |
|---|---|---|---|---|
| 1.T1 | Veri toplama tutarlılığı | 18 step temiz, USB drop yok | 4497 örnek, hiç drop yok | ✅ PASS |
| 1.T2 | Step bazlı fit kalitesi | her step NRMSE < %5 | düşük duty %9-12, yüksek duty %3-5 | ⚠ PARTIAL |
| 1.T3 | CW/CCW simetri | \|K_cw − K_ccw\| / K_avg < %5 | %1.24 | ✅ PASS |
| 1.T4 | Dead-band cross-check | V_dead < 0.5 V | -0.24 / +0.24 V (ihmal) | ✅ PASS |
| 1.T5 | Model validation (lsim + Simulink) | ort NRMSE < %15, max < %20 | ort %11.11, max %14.77 | ✅ PASS |

> **Test 1.T2 PARTIAL açıklaması:** Düşük duty step'lerinde (0.12-0.18) transient çok hızlı (τ ~40-60 ms), 40 Hz örnekleme ile sadece 6-9 örnek/τ → fit kalitesi düşük. Yüksek duty'de NRMSE %3-5 mükemmel. Pratik sonuç (Aşama 2 girişi) için yeterli.

### Sokratik Kararlar (kullanıcı onaylı)

- **Fit yöntemi (Soru 1):** Hem `lsqcurvefit` hem `tfest` çalıştırıldı, daha düşük NRMSE veren seçildi (16/18 step'te lsqcurve)
- **Step profili (Soru 2):** 9 duty × 2 yön, dead-band çevresinde yoğun (%12, %14, %16, %18, %20, %25, %30, %40, %45)
- **Veri formatı (Soru 3):** Mevcut alanlar + DWT mikrosaniye T_US timestamp eklendi (`[ARM_DWT]`)
- **Validation eşiği:** ort NRMSE < %15, max < %20 (`[Ljung1999] §16` "good agreement"); tek (K, τ) parametre yeterliliği akademik trade-off olarak rapor edildi

### Tamamlanma Kanıtı

- **Veri toplama altyapısı:** commit `67db814` (T_US + step_response.py + MATLAB iskeleti)
- **Pipeline + sonuçlar:** commit `e67e0c2` (validate_model + create_simulink_model + plot_results + run_pipeline)
- **Motor parametreleri:** `K_cw=54.22`, `K_ccw=53.56`, `τ_median=60.5 ms`, `V_dead≈0`, `R²>0.9997`
- **Test artifact:** `artifacts/1/step_response/20260518_011926/` (summary.md + meta.json + raw/data.csv.gz)
- **Akademik çıktı:** `matlab/asama_1_model/results/20260518_011926/` (10 PNG + .slx + JSON + MD)
- **README §10** — el kitapçığı disipliniyle akademik kapanış

### Akademik Bulgular (özet — detay README §10.7)

1. **Dinamik dead-band yok** (V_dead ≈ 0). Önceki R6 anomalisi statik sürtünme (stiction) ile açıklanır.
2. **V_sat etkisi modelle uyumlu** — K_apparent profil 60 → 50 rad/s/V (TB6612 datasheet `V_sat=0.5 V`).
3. **τ duty bağımlılığı** (43 ms → 134 ms) — 1. derece varsayımının sınırı; gerçek DC motor 2. derece.
4. **Test 1.T5 U-eğrisi** — tek (K, τ) ile validation NRMSE |duty|≈0.18'de minimum.

---

## 🎛 Aşama 2 — Tek Motor Kontrol (PI / PID / Cascade)  *(planlanan)*

### Vizyon

Aşama 1'de çıkarılan modelle:
- **Hız iç döngü PI** — pole placement (`[Franklin2010] §6.4`)
- **Pozisyon dış döngü P/PI** — cascade
- **IMU mirror** — encoder pozisyon setpoint = +fused_pitch (taklit, gimbal değil)
- **Anti-windup** — back-calculation `[AstromMurray2008] §10.4`

**MATLAB:** `matlab/asama_2_kontrol/`
- `design_pi_speed.m` — pole placement
- `design_cascade.m` — iç/dış döngü bant genişliği oranı
- `simulink_closed_loop.slx` — kapalı döngü simülasyonu

### Önkoşul
- Aşama 1 motor parametreleri (K, τ, V_dead) JSON'da

### Hedef Performans

| Metrik | Hedef | Kaynak |
|---|---|---|
| Hız döngüsü settling time | < 5τ | `[Franklin2010] §6.4` |
| Pozisyon overshoot | < %10 | `[Franklin2010] §4` |
| Steady-state error | < %2 | PI integral aksiyonu |
| Mirror takip RMS | < 5° (yavaş eğme ~10°/s) | proje hedefi |
| İç/dış bant genişliği oranı | ≥ 5× | `[Franklin2010] §6.4` |

### Alt-Aşamalar (iskelet)

- **2.1 — Hız PI tasarımı (MATLAB)** → kazançlar
- **2.2 — Firmware'de hız PI implementasyonu** (200 Hz fixed sample)
- **2.3 — Hız step response testi** (USB SP_W:X.X komutu)
- **2.4 — Anti-windup**
- **2.5 — Pozisyon P/PI tasarımı + cascade**
- **2.6 — Firmware cascade implementasyonu**
- **2.7 — IMU mirror bağlantısı** (setpoint = +fused_pitch)
- **2.8 — Disturbance rejection testi** (elle motor şaftı bozulması)
- **2.9 — Akademik rapor + Simulink karşılaştırma**

> Alt-aşama detayları her açılışta sokratik tartışma sonrası eklenecek.

---

## 🔄 Aşama 3 — İki Motor MIMO Modelleme  *(planlanan)*

### Vizyon

İkinci motor + ikinci encoder eklenir. **Çapraz coupling** karakterize edilir:
- Motor 1 sürülürken Motor 2 ekseninde dönüş var mı? (mekanik bağ + IMU geri besleme)
- 2×2 transfer matrisi G(s)
- Relative Gain Array (RGA) analizi `[Skogestad2005] §10`

**Donanım eklemesi:**
- İkinci TB6612 kanalı veya ikinci modül (BIN1/BIN2/PWMB)
- TIM4 quadrature encoder (PB6/PB7 — I2C ile çakışıyor → revize: TIM5 PA0/PA1)
- ⚠ PA0 = KEY butonu, çakışma! → pin yeniden değerlendirme Aşama 3 açılışında

**MATLAB:** `matlab/asama_3_mimo_model/`

### Önkoşul
- Aşama 2 KAPALI (tek motor kontrol stabil)
- İkinci motor + encoder donanımı

### Alt-Aşamalar (iskelet)

- **3.1 — Pin yeniden değerlendirme** (ikinci encoder için)
- **3.2 — İkinci motor sürücüsü hazırlığı** (TB6612 B kanalı veya ikinci modül)
- **3.3 — SISO ↔ MIMO veri toplama** (her motoru ayrı sür, diğerini ölç)
- **3.4 — Transfer matrisi G(s) tahmini** (MATLAB)
- **3.5 — RGA + condition number** — decoupling potansiyeli
- **3.6 — Coupling derecesinin akademik raporu**

> Kaynaklar: `[Skogestad2005] §3, §10`, `[Ljung1999] §16`.

---

## 🚀 Aşama 4 — İki Motor Modern Kontrol (LQR/LQG + Kalman)  *(planlanan)*

### Vizyon

MIMO sistemde:
- **Decoupling** (basit P diagonal + RGA kompansatör)
- **LQR** durum geri-besleme `[Anderson2007] §2`
- **Kalman filter** state estimation `[Simon2006] §5` — IMU + encoder füzyonu
- **LQG = LQR + Kalman** kombinasyonu

**MATLAB:** `matlab/asama_4_mimo_kontrol/`
- `lqr_design.m` — Q, R tuning + Riccati çözümü
- `kalman_design.m` — 3 durum (`x = [θ, ω, gyro_bias]`)
- `simulink_lqg.slx` — kapalı döngü simülasyon

### Önkoşul
- Aşama 3 MIMO modeli + RGA analizi
- Yazılım: float32 yeterli (STM32F411 FPU)

### Alt-Aşamalar (iskelet)

- **4.1 — Klasik vs LQR karşılaştırma** (akademik tartışma)
- **4.2 — Q ve R matris tasarımı** — fiziksel anlam
- **4.3 — LQR firmware implementasyonu** (durum geri-besleme)
- **4.4 — Kalman filter tasarımı** (MATLAB) — Q ve R matrisleri MPU6050 datasheet'inden
- **4.5 — Kalman firmware implementasyonu** (3 durumlu, float)
- **4.6 — LQG kapalı döngü testi**
- **4.7 — Complementary vs Kalman karşılaştırma** (gürültü RMS)
- **4.8 — Akademik karşılaştırma raporu** — klasik PID vs LQG

> Kaynaklar: `[Anderson2007]`, `[Friedland2005]`, `[Simon2006]`, `[Luenberger1971]`.

---

## 🎁 Aşama 5 — Gerçek 3D-Print Gimbal Entegrasyonu  *(planlanan)*

### Vizyon

Tüm yazılım altyapısı hazır → 3D-print gimbal şasisi + iki motor + IMU. **Gerçek gimbal** senaryosu (IMU motor şaftında, **ters çevirme** ile stabilizasyon — mirror değil).

### Önkoşul
- Aşama 4 LQG simülasyonda stabil
- 3D-print şasi tasarımı (Fusion 360 / FreeCAD)
- Motor mount + IMU mount
- Slip-ring veya esnek kablo (kabloların kopmaması)

### Senaryo Değişimi

**Aşama 0-4: Senaryo B (Mirror)** — IMU breadboard'da sabit, motor IMU'yu taklit eder.
**Aşama 5: Senaryo A (Klasik gimbal)** — IMU motor şaftında, ters çevirme ile stabilizasyon. *"Kamera sabit kalsın."*

### Alt-Aşamalar (iskelet)

- **5.1 — Şasi tasarımı + 3D print**
- **5.2 — Mekanik montaj + statik denge**
- **5.3 — Senaryo A için kontrol kuralı uyarlama** (setpoint = −fused_pitch)
- **5.4 — Yatay/dikey eksen tuning**
- **5.5 — Performans testi** (kameranın sabit kalması, RMS hata)
- **5.6 — Demo video + akademik kapanış raporu**

---

## Kapsam Dışı (Sonraki İterasyonlar)

- **VM hattı sigorta entegrasyonu** — Kullanıcı 1.5 A polyfuse veya 2 A cam sigorta temin ettiğinde aktif aşamaya alınır. Duty cap %50 sınırı gevşetilir.
- **Duty cap %50 → %100 gevşetme** — Sigorta sonrası, kontrolcü stabilse.
- **Madgwick / quaternion füzyon** — ±90° singülarite çözümü. Mevcut complementary ±45° için yeterli; gerekirse Aşama 5+'ta eklenir.
- **µ-synthesis, H∞ kontrol** — `[Skogestad2005] §11`. Akademik olarak zengin ama proje kapsamı dışı.
- **Bluetooth gecikme analizi** — Ferhat'ın tezi tarafı, BLE/HC-05 üzerinden komut gecikmesi.
- **Embedded Coder ile MATLAB → C otomatik üretim** — Manuel transfer disiplini terk edilmez.

---

## Güncelleme Protokolü

ROADMAP.md aşağıdaki durumlarda güncellenir:

1. **Alt-aşama tamamlanınca:** kontrol kutusu işaretlenir, "Tamamlanma kanıtı" doldurulur (commit hash + ölçüm değerleri + artifact path).
2. **Aşama tamamlanınca:** aşama başlığına ✅ ve tarih damgası, "KAPALI <YYYY-MM-DD>".
3. **Plan değişiminde:** ilgili bölüm doğrudan güncellenir, üst kısımdaki "son güncelleme" tarihi yenilenir.
4. **Yeni alt-aşama açılışı:** sokratik tartışma sonrası adım/test detayları eklenir. Öncesinde sadece iskelet.
5. **Yeni teknik karar:** `KAYNAKCA.md`'ye etiketli giriş + ROADMAP'te ilgili adımda referans.
6. **Büyük yapısal değişiklik:** kullanıcıya danışılır.

`PROJE_DURUMU.md` 5-10 satır özet + ROADMAP linki tutar; detay ROADMAP'te.
`README.md` sadece kalıcı teknik bilgi tutar; yol haritası veya TODO girmez.
`KAYNAKCA.md` her teknik karar için etiketli giriş tutar.
