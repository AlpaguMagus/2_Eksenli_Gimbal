# ROADMAP — İki Eksenli Gimbal Geliştirme Yol Haritası

> **Bu doküman canlıdır.** Her milestone tamamlandığında güncellenir.
>
> - **Son güncelleme:** 2026-06-13 (**Yüklü tek-eksen sürtünme/gravite feedforward** 🧪 bench PASS — `docs §12.8`: serbest-mil cascade yük altında stick-slip limit-cycle; computed-torque FF bastırdı, sim doğrulandı; Coulomb FF transfer-edilebilir, gravite rig-spesifik; `STALLEN` toggle + watchdog-heartbeat fix. Önceki: **Kontrol Yöntemleri Merdiveni** + donanımsız ön-tasarımlar)
> - **Aktif aşama:** **Aşama 3 (İki Motor MIMO Model) 🟡 AKTİF** — branch `feature/asama-3-mimo-model`; **3.3 tek-eksen (K0) ✅ bench PASS** (cascade/mirror/stab, motor-2) + **yüklü sürtünme FF 🧪 bench PASS** (`§12.8`); ⚠ motor-1 kurtarılamaz → **redüktörsüz yedek siparişte, tek sağlam motorla ilerleme**; sıradaki: tez düzeltmeleri, yeni motorla K1 (2-eksen) + 3.4 MIMO ID
> - **Dokümantasyon:** Aşama-bazlı `docs/` ekosistemi (README vitrin + `docs/asama_<N>_*.md` derin içerik)
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
| `README.md` | **Vitrin:** proje tanıtımı, mimari şema, hızlı başlangıç, repo + doküman haritası, "şu an neredeyiz" | Davranış/yapı değişikliği |
| `docs/00_genel_bakis.md` | Vizyon + ortak kontrol teorisi primer'i (aşamalar-arası temel) | Vizyon/teori-primer değişikliği |
| `docs/00_donanim_semasi.md` | **Tek yaşayan donanım şeması** (pin haritası + kablolama + güç + ACS712 rezerv); faz belgeleri atıf verir | Donanım/pin/kablolama değişikliği |
| `docs/asama_<N>_*.md` | **Derin akademik içerik:** teori, türetme, tasarım gerekçesi, alternatifler, deney sonucu (ne/neden/nasıl/nerede/sonuç) | İlgili aşama ilerleyince |
| `ROADMAP.md` (bu dosya) | Yol haritası, aşamalar, adımlar, testler, tamamlanma kanıtı | Her adım/aşama bitiminde |
| `PROJE_DURUMU.md` | "Şu an neredeyiz?" 5-10 satır özet + ROADMAP linki | Aşama geçişlerinde |
| `CLAUDE.md` | **Proje-spesifik** AI standartları/bağlar (genel disiplinler kullanıcı-global `~/.claude/CLAUDE.md`'de — 2026-05-31 taşındı) | Yeni kural eklendiğinde |
| `KAYNAKCA.md` | Etiketli akademik referanslar + datasheet'ler | Her yeni teknik karar |
| `matlab/<aşama>/README.md` | Aşama-spesifik MATLAB workflow | Aşama açılışında |

**README'ye yol haritası/TODO veya derin türetme girmez** — vitrin kalır; teknik derinlik `docs/asama_<N>_*.md`'ye, plan ROADMAP'e gider.

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

- **2A.T5-B (gerçek motor stall testi):** ✅ **KAPANDI (2026-06-07, count-tabanlı dedektörle)** — eldivenle gerçek kilitleme: 3/3 tespit; yüklü-ama-dönen (u=0.50 doyumda ~11 s kavrama) tetiklemedi; engel sürerken kes→1 sn→dene döngüsü; bırakınca **+1.0–1.25 s oto-devam**. `artifacts/2/stall_fix/20260607_174743/`. (KEY simülasyonu Aşama A daha önce PASS. Multimetre akım ölçümü yapılmadı — bütçe `[Pololu_25D]` duty %50'de ~0.55 A öngörür; ampirik ölçüm ACS712 Faz-2'de.)
- ~~**R6 (CW%20 ölü-bant değişkenliği)**~~ ✅ **ÇÖZÜLDÜ 2026-05-18 (artifact: `artifacts/1/stiction_test/20260518_111200/`):** Önce stiction hipotezi ile açıklandı (Aşama 1.3), sonra deneysel test ile **stiction reddedildi** (cold-start dahil tüm duty'lerde motor başlıyor). T7 ham log yeniden analizi: motor T7'de aslında dönmüş (ΔEC ≈ 1750 her cycle, ω ≈ 76 rad/s). Anomalinin nedeni: o dönem firmware OMEGA alanını göndermiyordu, Python analizi varsayılan 0.0 raporladı. **R6 fiziksel değil, analiz/parsing artefaktıydı.**

---

## ✅ Aşama 1 — Tek Motor Sistem Tanımlama  *(KAPALI 2026-05-18)*

> **Branch:** `feature/asama-1-tek-motor-model` → main (tag `asama-1-kapali`)
> **MATLAB:** `matlab/asama_1_model/`
> **Veri:** `artifacts/1/step_response/20260518_011926/`
> **Sonuçlar:** `matlab/asama_1_model/results/20260518_011926/`
> **docs/asama_1_model.md** — el kitapçığı disipliniyle akademik kapanış

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

- **1.1 — Veri toplama altyapısı:** `scripts/step_response.py` Python tarafı (handshake_test.py temel alınarak). 9 duty × 2 yön = 18 step (drive). USB telemetri ~36 Hz örnekleme (TX throttle 40 Hz nominal; gerçekleşen 4497 örnek / 126 s — aşağıdaki test tablosu). Çıktı: `artifacts/1/step_response/<test_id>/raw/data.csv.gz` + meta.json + summary.md.
- **1.2 — Step bazlı 1. derece fit:** MATLAB'da her step için `tfest` veya `lsqcurvefit`. Her step → (K_i, τ_i, ω_ss_i).
- **1.3 — Dead-band tespiti:** ω_ss vs V_eff lineer regresyon, x-intercept = V_dead. R6 (CW%20 değişkenliği) bu adımda nicelendirildi → V_dead ≈ 0, dead-band yok. (2026-05-18 stiction doğrulama testi ile bağımsız teyit edildi, R6 ölçüm artefaktı çıktı.)
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
- **docs/asama_1_model.md** — el kitapçığı disipliniyle akademik kapanış

### Akademik Bulgular (özet — detay docs/asama_1_model.md §10.7)

1. **Dinamik dead-band yok** (V_dead ≈ 0). İlk hipotez "stiction" 2026-05-18 deneysel testi ile reddedildi. R6 anomalisi T7 dönemindeki firmware'in OMEGA alanı eksikliğinden kaynaklanan **analiz/parsing artefaktı** — motor T7'de gerçekten dönmüş, biz yanlış ölçmüşüz.
2. **V_sat etkisi modelle uyumlu** — K_apparent profil 60 → 50 rad/s/V (TB6612 datasheet `V_sat=0.5 V`).
3. **τ duty bağımlılığı** (43 ms → 134 ms) — 1. derece varsayımının sınırı; gerçek DC motor 2. derece.
4. **Test 1.T5 U-eğrisi** — tek (K, τ) ile validation NRMSE |duty|≈0.18'de minimum.

---

## 🎛 Aşama 2 — Tek Motor Kontrol (PI / PID / Cascade)  *(KAPALI 2026-05-27)*

### Vizyon

Aşama 1'de çıkarılan modelle (K=53.89 rad/s/V, τ=60.5 ms, V_dead≈0):
- **Hız iç döngü PI** — pole placement (analitik) + `pidtune` (otomatik) karşılaştırma
- **Pozisyon dış döngü P/PI** — cascade, iç döngüden 5× yavaş
- **IMU mirror** — encoder pozisyon setpoint = +fused_pitch (taklit, gimbal değil)
- **Anti-windup** — back-calculation (`[AstromMurray2008] §10.4`)

**MATLAB:** `matlab/asama_2_kontrol/`

### Sokratik Kararlar (kullanıcı onaylı)

| # | Karar | Gerekçe |
|---|---|---|
| **S1** | **C — Pole placement + pidtune ikisi de** | Akademik açıdan zengin; klasik analitik tasarım (`[Franklin2010] §6.4`) ile modern auto-tune (`pidtune`) yan yana sunulur, robustluk + performans karşılaştırılır |
| **S2** | **B — Back-calculation anti-windup** | Akademik standart (`[AstromMurray2008] §10.4`), basit clamp'ten daha iyi recovery; T_b = T_i ile başlangıç |
| **S3** | **5× iç/dış oran** | `[Franklin2010] §6.4` cascade kuralı; ihtiyatlı seçim, coupling riskini minimize eder. Hız τ_cl ≈ 12 ms, pozisyon τ_cl ≈ 60 ms |

### Önkoşul
- ✅ Aşama 1 motor parametreleri (`motor_params.json`) — K=53.89 rad/s/V, τ=60.5 ms
- ✅ Aşama 0 USB komut altyapısı (DUTY: zaten var; SP_W: ve SP_POS: eklenecek)
- ✅ MATLAB Control System Toolbox + Simulink (zaten kurulu)

### Hedef Performans

| Metrik | Hedef | Kaynak |
|---|---|---|
| Hız döngüsü settling time | < 5×τ_ol = 300 ms (konservatif, kapalı döngü 4×τ_cl = 48 ms olur) | `[Franklin2010] §6.4` |
| Hız overshoot | < %10 (ζ=0.707, Butterworth) | `[Franklin2010] §3.6` |
| Hız steady-state error | < %2 | PI integral aksiyonu |
| Pozisyon overshoot | < %10 | `[Franklin2010] §4` |
| Mirror takip RMS | < 5° (yavaş eğme ~10°/s) | proje hedefi |
| Gain margin | ≥ 6 dB | `[Franklin2010] §6.7` |
| Phase margin | ≥ 45° | `[Franklin2010] §6.7` |

### Alt-Aşamalar

- **2.1 — Hız PI tasarımı (MATLAB)** *(BAŞLAYACAK)*
  - Pole placement (analitik): ζ=0.707, ω_n=83 rad/s (τ_cl=12 ms)
  - `pidtune` (otomatik): Robust + Balanced + Fast varyasyonlar
  - Bode + step response + gain/phase margin karşılaştırma
  - Simulink kapalı döngü simülasyonu (`speed_loop_a2_1.slx`)
  - Çıktı: `matlab/asama_2_kontrol/results/<test_id>/speed_pi_params.json`

- **2.2 — Firmware hız PI implementasyonu** *(implementasyon tamamlandı, test bekleniyor)*

  Sokratik kararlar (kullanıcı onaylı):
  | # | Karar | Gerekçe |
  |---|---|---|
  | 2.2.A | **Tustin (bilinear)** | s-domain özelliklerini en iyi koruyor, Ts=5 ms / τ=60 ms oran için emniyetli |
  | 2.2.B | **T_t = T_i = Kp/Ki** | Aström-Murray varsayılan tracking time (T_t = 28.75 ms) |
  | 2.2.C | **Açık MODE komutu** | `MODE:DUTY\n` ve `MODE:SP_W\n` — temiz akademik, geriye uyumlu |
  | 2.2.D | **A+C: saf step + anti-windup'a güven** | Step response testi için saf step, slew rate 2.5'te ekle |

  Yeni firmware modülleri:
  - `include/speed_pi.h` + `src/speed_pi.c` — Paralel form PI (P + I), Tustin
    integration `i[k] = i[k-1] + Ki·Ts/2·(e[k] + e[k-1])`, back-calculation
    `i += (Ts/T_t)·(u_sat − u_unsat)` (`[AstromMurray2008] §10.2-§10.4`)
  - `include/cmd_parser.h` + `src/cmd_parser.c` — `MODE:DUTY`, `MODE:SP_W`,
    `SP_W:<float>` komutları + `CmdParser_GetMode()` accessor
  - `src/main.c` — SpeedPI_Init (2.2'de Kp=0.1163, Ki=4.0447, Ts=5ms, T_t=28.75ms
    — **2.3'te analitik düzeltilmiş Kp=0.002, Ki=0.1, T_t=20ms ile değiştirildi**
    (doyum-kısıtı + doğru-plant pole placement, §11.11.3); conservative bang-bang
    verdi, bkz. §2.3 altında), SP_W modda her tick'te SpeedPI_Step,
    USB TX formatına `SP:` (setpoint) + `U:` (kontrol çıkışı) alanları
  - Stall event'inde SpeedPI_Reset (integrator wind-up önleme)

  Build: PASS, RAM 3.6%, Flash 7.8% (Aşama 2.1 öncesi 3.5% / 7.6%).

- **2.3 — Hız PI gerçek motor tuning** *(BÜYÜK BULGU — sim-to-real gap)*

  Aşama 2.1 conservative kazancı (Kp=0.1163) gerçek motorda **BANG-BANG limit
  cycle** verdi (motor titredi, dönmedi). Sistematik tanı:
  - İzolasyon: açık döngü ω_std=7 (temiz), kapalı döngü ω_std=105 (çöp) → limit cycle
  - Ad-hoc denemeler (dt→DWT, filtre, 5 kazanç, slew, Motor_Tick bypass) → hepsi çözmedi
  - **Setpoint taraması:** SP=280'de oturuyor, düşük SP'de bang → setpoint-saturation uyumsuzluğu
  - **Düşük kazanç taraması:** **Kp=0.002, Ki=0.1 → motor temiz oturdu** (50/120/30 rad/s, hata %0)

  **Kök neden:** Simulink ideal ölçüm + farklı plant varsaydı; gerçekte serbest
  mil çok hızlı (0.5 duty≈280 rad/s) + encoder kuantize + yüksek Kp her error'da
  saturation'a fırlatıp limit cycle yaratıyordu. Doğru kazanç ~58× düşük.

  Firmware değişiklikleri (commit `<bu seans>`):
  - main.c: default kazanç Kp=0.002, Ki=0.1 (analitik: doyum-kısıtı + doğru-plant pole placement, §11.11.3)
  - main.c: dt→DWT µs (ms jitter giderme)
  - main.c: SP_W'de Motor_Tick bypass, Motor_SetDutySigned doğrudan PWM
  - encoder.c: Encoder_FilterSpeed moving-avg (WINDOW=5)
  - speed_pi.c: SpeedPI_SetGains + setpoint slew rate
  - cmd_parser.c: KP:/KI:/SLEW: runtime tuning komutları
  - motor.c: Motor_SetDutySigned (rampasız kapalı döngü PWM)

  Artifact: `artifacts/2/T2_3_speed_pi_tuning/` + `speed_gain_sweep/` + `slew_sweep/`
  Detay: docs/asama_2_kontrol.md §11.11

  Kalan: çalışan kazancı 2b Simulink'te teorik doğrula. Sonra programatik
  `scripts/speed_step_test.py` ile resmi step response metrikleri (settling/OS/ss).

- **2.4 — Disturbance rejection testi**
  - Sabit setpoint (50 rad/s), elle motor şaftını yavaşla
  - Kontrolcü recovery'i ölçülür

- **2.5 — Pozisyon P tasarımı + cascade** ✅ (2026-05-24)
  - Cascade + P dış döngü + çıkış mili açısı (3 sokratik karar onaylandı)
  - `Kp_pos=2.0`, dış ω_c≈1.93 rad/s = iç ω_n/5 (`design_position_p.m`)
  - Gerçekçi sim limit-cycle uyarısı verdi (sürtünmesiz, kötümser) + 5V sim hatası yakalandı/düzeltildi

- **2.6 — Firmware cascade implementasyonu** ✅ (2026-05-24)
  - `src/position_p.c` (dış döngü P), `MODE:POS` + `POS_DEG:`/`KPP:` komutları
  - Encoder count → derece dönüşümü (θ_out = EC × 360/466)
  - ⚠ Watchdog güvenlik düzeltmesi: kapalı-döngü modlarında artık etkili (eskiden mod sürüşü Motor_Stop'u eziyordu)
  - **Test 2.5 gerçek motorda PASS — limit-cycle YOK (sürtünme söndürdü, sim kötümserdi)**

- **2.6.5 — Cascade Simulink + sürtünme modeli** ✅ (2026-05-24)
  - `create_cascade_simulink.m` → resmi cascade blok diyagramı (`cascade_pos_a2_5.slx`); firmware-uyumlu model analitik Vsupply sadeleştirmesini ortaya çıkardı (iç ω_n~33 → Kp_pos=2.0 ~16× ayrımla daha güvenli)
  - `verify_realistic_cascade.m` Coulomb/stiction sürtünme (eşik Aşama 1 V_dead'den) → sürtünmeli sim θ_std=0° = gerçek Test 2.5 ile uyumlu → **sim-to-real gap kapandı**
  - Detay: docs/asama_2_kontrol.md §11.13.7

- **2.7 — IMU mirror bağlantısı** ✅ (2026-05-26)
  - `MODE:MIRROR`: θ_ref = clamp(fused_pitch−pitch₀, ±60°), slew 90°/s → cascade
  - Kp_pos=6 **ANALİTİK** (deneme-yanılma değil): tip-1 Kv=Kp_pos, e_ss=ω_in/Kv, ω_in=30°/s, <5° → Kp_pos≥6 (`[Franklin2010] §4.2`, `design_mirror_tracking.m`)
  - Güvenlik: STOP/RESET→DUTY, watchdog hedef sıfırla; complementary filter mod sürüşü öncesine taşındı

- **2.8 — Mirror takip testi** ✅ (Test 2.T6, 2026-05-26)
  - Gimbal-hızı: Kp_pos=6 firmware default RMS 4.02° (gerçek motor, span 95.4°) PASS — analitik 4.63° üst sınırını doğruladı; Kp=5 sweep 4.68°
  - Hızlı el (~80°/s): bant genişliği limiti (~10° RMS, beklenen — cascade ~0.3 Hz)
  - Detay: docs/asama_2_kontrol.md §11.13.8

- **2.9 — Akademik rapor + Simulink karşılaştırma**
  - docs/asama_2_kontrol.md — el kitapçığı disipliniyle Aşama 2 sonuç bölümü
  - 4 yöntem karşılaştırma tablosu (pole placement / pidtune robust / balanced / fast)

### Test ve Doğrulama (iskelet)

| # | Test | Beklenen | Durum |
|---|---|---|---|
| 2.T1 | Kararlılık marjı (çalışan kazanç) | Gain margin ≥ 6 dB, phase margin ≥ 45° | ✅ PASS — çalışan Kp=0.002 firmware plant'ta **PM=60.2°, GM=∞** (analitik PM~58° + `margin` doğrulama, %4 uyum). Conservative ωc=1259>Nyquist 628 → sim-to-real gap'in margin-düzeyi kanıtı. `docs §11.11.8` |
| 2.T2 | Hız step response (firmware) | settling < 5τ, overshoot < %10, ss_error < %2 | ✅ PASS (Kp=0.002, 8/8 step temiz, ss_err çoğunlukla <%2, bang-bang yok. Settling/OS metrikleri düşük setpoint'te encoder kuantizasyonu ile sınırlı — `artifacts/2/speed_step/20260524_180610/`) |
| 2.T3 | Anti-windup recovery | recovery iyileşmesi | ✅ **PASS (sim + gerçek)** — sim: anti-windup ON 235 vs OFF 715 ms (3× hızlı), integratör 32× az şişme. **Gerçek motor: 637 ms** (450→50 saturation, < sim OFF 715 → anti-windup aktif; sim ON'dan yavaşlık = sim-to-real gap, coast+kuantizasyon). `docs §11.11.9`, `artifacts/2/antiwindup/20260528_203803/` |
| 2.T4 | Disturbance rejection | Yük sonrası setpoint'e dönüş | ✅ PASS — baseline 101 rad/s (=setpoint, PI sıfır ss-error), elle yük ω'yı 56'ya itti (%44 dip), PI duty 0.186→0.50 telafi, setpoint'e döndü. `artifacts/2/disturbance/20260524_192851/`. Recovery metriği encoder kuantizasyonu ile sınırlı. |
| 2.T5 | Cascade pozisyon step | Overshoot < %10, ss_error < 1° | ✅ PASS — 6/6 segment (30/90/45/0/-45/0°), ss_err <0.8°, OS <1°, **limit-cycle yok** (θ_std <0.7°). Gerçekçi sim limit-cycle öngördü ama gerçek motor sürtünmesi söndürdü (sim kötümserdi). `artifacts/2/position_step/20260524_212456/` |
| 2.T6 | Mirror takip (KRİTİK) | RMS < 5° | ✅ PASS — gimbal-hızı RMS **4.02°** (Kp_pos=6 firmware default, gerçek motor, span 95.4°; analitik 4.63° üst sınırını doğruladı). Kp=5 sweep 4.68°. Hızlı el (~80°/s) bant-genişliği limiti (~10°, beklenen). `artifacts/2/mirror/20260531_174740/` |

### Açık Sorular (alt-aşama açılışlarında)

- **2.1:** Pole placement için τ_cl hedef seçimi (12 ms / 20 ms / 30 ms tradeoff)? `pidtune` Robustness slider varsayılan mı, override mı?
- **2.5:** Dış döngü P vs PI? Pozisyon ss_error gerekiyorsa PI, ama integral wind-up artar — P ile başlayalım, gerekirse PI'a geç.
- **2.7:** IMU mirror gain (1.0 sabit mi yoksa ölçek faktörü mü)? Breadboard hareketi vs motor şaftı 1:1 mi yoksa 9.7:1 redüktör hesaba katılır mı?

---

## 🪜 Kontrol Yöntemleri Merdiveni — decentralized → en ileri  *(2026-06-12 kararı)*

> **İlke:** Kanıtlı **decentralized cascade PID**'den başlayıp her basamakta bir kademe
> yükseliriz; **her basamak kendi başına kapatılabilir bir kilometre taşıdır** — zaman/donanım
> kısıtında bulunulan basamakta *"elimizde bu var"* deyip projeyi tutarlı bir noktada
> kapatabiliriz. **Hiçbir basamak gerekçesiz eklenmez** (baseline-önce + analitik-önce): bir üst
> basamak ancak somut kazanç (kuplaj, gecikme, robustluk, kısıt, gürültü) **ölçülünce** devreye
> girer. Karar temeli: kontrol-yöntemleri taraması (7 aile, 30 yöntem, adversarial doğrulama).
>
> ⚠ Terminoloji: cascade PID **SISO'ya mahkûm değildir** — kontrolcü matrisi $K(s)$'nin **köşegen
> (decentralized) MIMO** hâlidir (`[Skogestad2005] §10.6.4`); çapraz-kuplajı *aktif* kompanze etmez,
> onu bozucuya bırakır. RGA ≈ birim ise (kuplaj zayıf) bu zaten optimale yakındır.

> **Olgunluk taksonomisi (atlamalı çalışmanın garantisi — sim ≠ validasyon):** 📐 tasarım/sim ·
> 🔧 firmware · 🧪 bench · ✅ validated (bench PASS) · ⛔ donanım/koşul bekliyor. Her basamak ULAŞTIĞI
> seviyeyi gösterir → fazla-iddia engellenir, hiçbir basamak unutulmaz, ders-kitabı (`§12.7` banner'lı
> sim bölümleri) bench gelince **eklemeli** büyür (sim türetmesi silinmez).

| # · olgunluk | Basamak | Ne ekler | Kapı (ne zaman gerekçeli) | "Elde" / sonuç | Faz |
|---|---|---|---|---|---|
| **K0** · ✅ validated | Decentralized cascade PID (tek eksen) | poz P → hız PI, per-eksen | — (kanıtlı) | mirror/stab bench PASS (`docs §12.4`) | 2–3.3 |
| **K1** · ⛔ donanım | 2-eksen decentralized cascade | 2. ekseni entegre | yeni motor (donanım) | 2-eksen cascade gimbal | 3.3 |
| **K2** · 🔧 firmware + 🧪 kısmi bench | + **Gyro feedforward** (2-DOF) | bozucuyu doğrudan ileri-besle (gy_dps) | bedava sinyal | sim 4.1× reddi-bant; firmware+gate; **FF-faydası belirsiz** (fast-rig bekler) `§12.7` | 3.8 |
| **K3** · 📐 sim | + **Gain scheduling** | çalışma-noktası kazanç tablosu | τ-bağımlılığı (43→134ms) | τ(duty)→Ki LUT; saturation tavizi → "default kapalı" `§12.7` | 3.9 |
| **K4** · 📐 çerçeve | Kuplaj karakterizasyonu (MIMO ID + **RGA**) | 2×2 $G(s)$, RGA, condition no. | 2 motor mekanik bağlı | **KARAR KAPISI**; sentetik doğrulandı, gerçek-veri bekler `§12.7` | 3.5 |
| **K5** · ⛔ koşullu | **Decoupling** ($D(s)$ / feedforward) | çapraz kuplajı iptal | RGA kuplaj gösterirse | decoupled MIMO cascade | 4 |
| **K6** · 📐 sim | LQR → **LQI** (optimal MIMO) | optimal centralized durum-geri-besleme | K4 kuplaj / akademik kıyas | sim: cascade'i ~6× geçer `§12.7` (`asama_4`) | 4 |
| **K7** · 📐 sim | Kalman → **LQG** | optimal kestirim (IMU+bias füzyonu) | IMU payload'a + gürültü | sim: complementary'yi 2.8× geçer `§12.7` (`asama_5`) | 5 |
| **K8** · ⛔ gelecek | İleri/robust/öngörülü | H∞·μ-synth, MPC, SMC/adaptif, DOB, notch | belirsizlik/kısıt/rezonans **ölçülünce** | tez zirvesi | 5+ |

> **Paralel kestirim izi:** complementary ✅ → Mahony/Madgwick (singülarite) → EKF/Kalman (bias/füzyon).
>
> **Şu an (2026-06-13):** K0 ✅ validated. **Donanımsız ön-tasarımlar TAMAM** (2026-06-12/13, hepsi
> analitik-önce + kaynaklı, `docs §12.7` banner'lı): K2 🔧 firmware+gate + 🧪 kısmi bench (FF-faydası
> belirsiz), K3 📐 sim (Ki-LUT), K4 📐 çerçeve (sentetik), K6 📐 sim (cascade'i 6× geçer), K7 📐 sim
> (complementary'yi 2.8× geçer). **Yüklü tek-eksen sürtünme/gravite FF 🧪 bench PASS** (`docs §12.8`):
> serbest-mil cascade yük altında stick-slip limit-cycle veriyordu; **computed-torque feedforward**
> ([Franklin2010] §7.5, [Olsson1998] §6) bastırdı ($20^\circ$ $\theta_{std}$ $1.41^\circ\to0.00^\circ$ — push'lanan firmware kanonik koşu; sim
> doğrulandı). Coulomb FF ($u_c{=}0.090$) **transfer-edilebilir**; gravite ($a{=}0.097$) rig-spesifik
> (dengesiz sarkaç). Bench iki firmware kusuru ortaya çıkardı: watchdog-heartbeat eksikliği + stall
> yük-altı yanlış-pozitifi (`STALLEN` toggle eklendi). **Donanım bekleyen:** K1 (2-eksen, yeni motor),
> K4 gerçek-veri (MIMO ID), K5 (RGA kuplaj gösterirse), stall kriteri yük-bilinçli yeniden-tasarım
> (Aşama 5), dengeli payload + gravite-yardımlı iniş kontrolü (Aşama 5). **Sıradaki:** tez düzeltmeleri;
> yeni motor gelince K1 + 3.4 MIMO ID.
>
> Kaynaklar: `[Skogestad2005] §10` (decentralized/RGA), `[Franklin2010] §6.4` (cascade),
> `[Anderson2007]` (LQR), `[Simon2006]` (Kalman). Tarama detayı: yöntem-bazlı gerekçe + verdict.

---

## 🟡 Aşama 3 — İki Motor MIMO Modelleme  *(AKTİF — 2026-06-07 açıldı)*

### Vizyon

İkinci motor + ikinci encoder eklenir. **Çapraz coupling** karakterize edilir:
- Motor 1 sürülürken Motor 2 ekseninde dönüş var mı? (mekanik bağ + IMU geri besleme)
- 2×2 transfer matrisi G(s)
- Relative Gain Array (RGA) analizi `[Skogestad2005] §10`

**Donanım eklemesi (pin planı ✅ ONAYLANDI 2026-06-07 — tam tablo: `docs/asama_3_mimo_model.md` §12.2):**
- İkinci TB6612 **modülü** (ayrı çip — termal gerekçe güç planında): AIN1=**PB4**, AIN2=**PB5**, STBY=**PB10** (ayrı — eksen-bağımsız kesme), PWM=**PB1** (TIM3_CH4, motor-1 ile aynı 20 kHz timer)
- Encoder-2: **TIM1 quadrature PA8/PA9** (eski adaylar elendi: TIM4 PB6/7=I2C ✗, TIM5 PA0=KEY ✗); TIM1 16-bit → yazılım count-genişletme (3.2)
- ACS712 rezervi: PA1/PA2 (ADC1_IN1/IN2, Faz-2)

**Güç & koruma planı (2026-05-31 datasheet denetimi — `[Pololu_25D]`, `[TB6612_DS]`, `[ACS712_DS]`):**

- **Tek 3A adaptör 2 motora YETERLİ** (karar: 5A alınmadı): ikisi stall @ duty %50 ≈ 1.6 A, @ tam 12V (en kötü) 2.2 A < 3.0 A. Şartlar: duty cap %50 korunur, soft-start'lar kademeli (eşzamanlı inrush yok), 12V hattına bulk kapasitör.
- **2 AYRI TB6612 modülü** (karar — ikisi de mevcut): tek çipte iki motor stall'da disipasyon ~1.2 W > PD limiti (0.78–0.89 W) → TSD riski; iki çipte ~0.6 W/çip güvenli (`[TB6612_DS]` sf 3/5).
- **Dar boğaz = SÜRÜCÜ** (adaptör değil): motor stall @12V 1.1 A > TB6612 sürekli 1.0 A; TB6612'de ayrık OCP YOK (yalnız TSD ~175°C) → sürücü koruması **yazılımdadır** (duty cap + stall detection; ileride ACS712 foldback).
- **ACS712 ±5A akım sensörü — planlı açık konu (karar kaydı):** duty %100 gevşetmenin **ön koşulu** (1.1 A > 1.0 A'yı foldback ile spec içinde tutar) + "elle müdahalede sistem durmasın" gereksinimi (orantısal güç kısma yalnız akım ölçümüyle olur). Eksen-başı 2 sensör (hangi motor stall bilgisi); ADC1 boş, PA1–PA7 serbest; ≤1.1 A aralığımızda çıkış 2.5±0.21 V → 3.3V ADC uyumlu; çözünürlük kaba (gürültü ~113 mA) ama koruma eşiği için yeterli (`[ACS712_DS]`). NOT: ACS712 pasif backstop'un (polyfuse) yerine geçmez — MCU çökerse yazılım limiti de ölür; katmanlar tamamlayıcıdır.

**MATLAB:** `matlab/asama_3_mimo_model/`

### Önkoşul
- Aşama 2 KAPALI (tek motor kontrol stabil)
- İkinci motor + encoder donanımı

### Alt-Aşamalar (iskelet)

- **3.1 — Pin planı** ✅ KARAR (2026-06-07): docs §12.2 — kablolama tamam
- **3.2 — Encoder-2 + motor-2 sürücü firmware**
  - 3.2a — encoder-2 (TIM1 PA8/PA9, 16-bit→32-bit) ✅ **PASS** (`artifacts/3/enc2_test/`)
  - 3.2b — motor-2 sürücü (PB1/PB4/PB5/PB10) — **firmware ✅ + bench PASS** (2026-06-09): `Motor2_*` minimal açık-döngü, `DUTY2:` + `U2` telemetri; `motor2_sign_test.py` → motor-2 ±0.30'da +1203/−1199 count/s, **polarite +duty→+count = motor-1 ile AYNI** → 3.3 cascade işaret çevirme YOK. `artifacts/3/motor2_sign/`. Motor-2 stall + shared-struct refactor → 3.3'e ertelendi.
    - ⚠ **Bench bulgusu:** rewire'da roller değişti — karakterize sağlıklı ünite şimdi **motor-2**; **motor-1 fiziksel ünitesinde yöne-bağlı mekanik kusur** (CCW serbest, CW'de 0.50 duty'de bile takılır, elle de zor — gearbox asimetri). Kullanıcı kararı: olduğu gibi devam → 3.4'te asimetrik $G_{11}$ karakterize.
- **3.3 — Baseline 2-eksen (yeniden kullan):** kanıtlı Aşama-2 cascade'ini her motora **bağımsız** uygula → 2-eksenli sistemi test et → çalışan referans + kuplajı **ampirik** gör
  - **Firmware ✅ (2026-06-11, `9def197`):** instance-based eksen mimarisi — `SpeedPI_t`/`PositionP_t`/`MotorCh_t` + `g_axis[2]`; cascade/MIRROR eksen-1'de (motor-2) bugün kullanılabilir (`MODE2:`/`POS_DEG2:`/`KPP2:` …); motor-2 stall kazandı; telemetri +`OMEGA2/SP2/TR2` (eski script regex'leri korunur). 21-ajan adversarial davranış-denetimi: 3 gerçek fark → 2 düzeltildi (RESET motor-Stop, geçersiz MODE watchdog), 1 bilinçli kabul (DUTY2 mod-şartı).
  - **Strateji (kullanıcı 2026-06-11):** motor-1 ünitesi kurtarılamaz (CW catch) → **redüktörsüz yedek sipariş edildi**; gelene kadar **tek sağlam motor (motor-2 ekseni) üzerinden proje tamamlanır**; yeni motor tak-çalıştır entegre (yalnız yön/kimlik testi).
  - ✅ **Motor-2 cascade/mirror/stab bench PASS (2026-06-12)** [merdiven K0 tek-eksen tamam]: `MODE2:POS` 6/6 (ss_err<1°, Test 2.5 ile birebir); `MODE2:MIRROR` RMS 5.53°; `MODE2:STAB` motor IMU'ya TERS döndü (stabilizasyon yasası demoland), RMS 6.72°. IMU sertleştirme (uyku auto-wake) `94a36e3`. `artifacts/3/{cascade,mirror,stab}_m2/`
  - ⬜ **K1 — 2-eksen cascade:** yeni motor gelince motor-1 ekseni entegre + 2-eksen mirror/stab
- **3.8 — K2: Gyro feedforward (aday, 2026-06-12 onaylı):** IMU gyro hızı (gy_dps, bedava sinyal) → motor hız-ref'e 2-DOF ileri-besle → yavaş (~0.3 Hz) cascade dış-döngüsünü atla, stabilizasyon gecikmesini düşür. Analitik $k_{ff}$=redüktör oranı (deneme-yanılma değil). **Donanımsız tasarlanır**; STAB ref'iyle çift-sayım önlenir; bench sıra gelince. Cascade'i bozmaz (üstüne eklenir).
- **3.9 — K3: Gain scheduling (kanıtla-sonra aday):** τ duty-bağımlılığı (43→134ms, Aşama-1 NRMSE U-eğrisi) tek-kazancın uçlarda sub-optimalliğini gösteriyor. **Önce** uçlarda before/after step ile somut kazanç ölç; kanıtlanırsa çalışma-noktası kazanç tablosu. Mevcut Aşama-1 verisiyle ön-tasarım donanımsız.
- **3.4 — K4/MIMO sistem tanımlama:** her motoru ayrı sür / diğer ekseni ölç → 2×2 $G(s)$ (`tfest`); $G_{22}$ = motor-2 modeli **bedavaya** çıkar (sıfırdan Aşama-1 kampanyası DEĞİL). ⚠ 2 motor mekanik bağlı olmadan çapraz terimler ~0 → anlamlı kuplaj yüklü gimbalda
- **3.5 — K4/RGA + condition number:** kuplajı **sayıyla** ölç → decoupling potansiyeli → **KARAR KAPISI**
- **3.6 — Kanıta-dayalı kontrolcü kararı:** RGA ≈ birim → decoupled SISO yeterli (K0/K1 kalır); güçlü kuplaj → decoupler/MIMO (K5/K6, Aşama 4'e devir)
- **3.7 — Coupling derecesinin akademik raporu**

> **Yöntem (Sokratik karar 2026-06-09 — baseline-önce, analitik iterasyon):** Bütün
> kontrolcüleri **önden** tasarlamak yerine **mimari seviyede iterasyon**: baseline (kanıtlı
> Aşama-2 kontrolcüsünü yeniden kullan) → kuplajı **ölç** (RGA) → karmaşıklığa **kanıtla** karar
> ver → her kontrolcüyü **analitik tasarla → dene → kıyasla**. Gerekçe: (1) kuplaj bilinmeden
> doğru kontrolcü (decoupled mi MIMO mu) seçilemez — önden bağlanma erken; (2) baseline zaten
> yeterli olabilir; (3) projenin kanıtlı dersi (sim-to-real, `asama_2_kontrol.md` §11.14) testin
> tasarımı açığa çıkardığıdır. ⚠ **Disiplin guard:** her adım **model-bazlı analitik** tasarım —
> knob-twiddling/deneme-yanılma DEĞİL (mirror Kp_pos dersi); iterasyon *analitik tasarımların*,
> tahminlerin değil. Motorlar nominal özdeş → Aşama-1 modeli (K≈54, τ≈60 ms) güçlü ön-kabul.

> Kaynaklar: `[Skogestad2005] §3, §10`, `[Ljung1999] §16`, `[Franklin2010] §6.4` (cascade yeniden-kullanım).

---

## 🚀 Aşama 4 — İki Motor Optimal Kontrol (Decoupling + LQR/LQI)  *(planlanan — merdiven K5–K6)*

### Vizyon

> **Merdiven konumu:** K5 (decoupling, kuplaj VARSA) + K6 (optimal MIMO state-feedback).
> **Kanıta-bağlı (2026-06-12 rafine):** bu aşamanın gerekçesi **Aşama 3.5 RGA ölçümüne** bağlıdır —
> RGA ≈ birim ise decentralized cascade zaten optimal (`[Skogestad2005] §10`), LQR/decoupling
> *akademik kıyas* değeri taşır; RGA anlamlı off-diagonal ise centralized optimal kontrol **net
> gerekçeli**. LQG/Kalman (K7) bu aşamada DEĞİL → gerçek değeri IMU payload'a taşınınca = **Aşama 5**
> (saf-encoder tam-durumda Kalman overkill; encoder-hızı kuantizasyonu Gauss değil).

MIMO sistemde:
- **Decoupling** (statik $D=G(0)^{-1}$ veya feedforward decoupling) — **yalnız RGA kuplaj gösterirse**
- **LQI** (LQR + integral durum genişletmesi) `[Anderson2007] §2` — saf LQR ss-error verir (cascade'den
  geri adım); **LQI doğru form**, tek K matrisi, doğal MIMO
- **Cascade ile sayısal kıyas** (ss-error, margin, bozucu reddi) — akademik omurga

**MATLAB:** `matlab/asama_4_mimo_kontrol/`
- ✅ `design_lqr_lqi_singleaxis.m` — 📐 **tek-eksen LQR/LQI ön-tasarım YAPILDI** (2026-06-13,
  donanımsız): Bryson Q/R + Riccati doğrulama + LQI + cascade kıyası → cascade'i ~6× geçer (`docs §12.7.4`)
- ⬜ `design_mimo_lqr.m` — 2×2 MIMO LQR (iki sağlam motor + RGA kuplaj gösterirse)
- ⬜ `design_decoupling.m` — $D=G(0)^{-1}$ statik/feedforward (yalnız RGA kuplaj gösterirse)

> ⚠ Eski `kalman_design.m` / `simulink_lqg.slx` Aşama 4 listesinden **ÇIKARILDI** — ladder'da
> Kalman/LQG **K7 = Aşama 5** (`matlab/asama_5_gimbal/`). Vizyon ile uyumlu hâle getirildi (2026-06-13).

### Önkoşul
- Aşama 3 MIMO modeli + RGA analizi
- Yazılım: float32 yeterli (STM32F411 FPU)

### Alt-Aşamalar (iskelet)

- **4.1 — Klasik vs LQR karşılaştırma** (akademik tartışma) — 📐 **tek-eksen ön-tasarım YAPILDI**
  (donanımsız, 2026-06-13): LQR/LQI cascade'i ~6× geçer (Riccati-doğrulama), `docs §12.7.4`.
  2-eksen MIMO + bench-validasyon donanım bekler.
- **4.2 — Q ve R matris tasarımı** — fiziksel anlam — 📐 **yapıldı** (Bryson kuralı, tek-eksen; §12.7.4)
- **4.3 — LQR firmware implementasyonu** (durum geri-besleme) — ⬜ donanım bekler (bench-validasyon sonrası)
- **4.4 — Akademik karşılaştırma raporu** — decentralized cascade vs decoupled-cascade vs LQI
  (ss-error, margin, kuplaj reddi, başarım)

> **NOT (2026-06-12):** Kalman/LQG (eski 4.4–4.7) **Aşama 5'e taşındı** (merdiven K7) — gerçek değeri
> IMU payload'a + gürültü/bozucu olunca doğar. Robust (H∞/μ), MPC, SMC, adaptif, DOB, notch (K8) =
> opsiyonel akademik zirveler, ihtiyaç/ölçüm doğunca Aşama 5+.
>
> Kaynaklar: `[Anderson2007]`, `[Friedland2005]`, `[Skogestad2005]`, `[Luenberger1971]`.

---

## 🎁 Aşama 5 — Gerçek 3D-Print Gimbal Entegrasyonu  *(planlanan)*

### Vizyon

Tüm yazılım altyapısı hazır → 3D-print gimbal şasisi + iki motor + IMU. **Gerçek gimbal** senaryosu (IMU **payload'da/motor çıkışında**, **ters çevirme** ile stabilizasyon — mirror değil). Bu kurulumda K0–K3'te demolanan stabilizasyon yasası **tam eylemsiz doğrulanır**.

> **Merdiven konumu:** K7 (**LQG/Kalman** — IMU payload'a taşınınca gerçek değeri doğar: gürültü/bias/füzyon)
> + K8 (**robust/öngörülü/nonlineer** opsiyonel zirveler: H∞·μ, MPC, SMC, adaptif, DOB, notch — yük
> belirsizliği/rezonans/kısıt **ölçülünce**) + **kestirim yükseltmeleri** (Mahony/Madgwick singülarite,
> EKF). Yük altında **K0–K6 kazançları yeniden-ID** (serbest-mil → yüklü plant değişir).
>
> 📐 **K7 tek-eksen ön-tasarım YAPILDI** (donanımsız, 2026-06-13): bias-augmented attitude Kalman
> complementary'yi 2.8× geçer (bias kestirir), `matlab/asama_5_gimbal/design_kalman_attitude.m`,
> `docs §12.7.5`. **LQG entegrasyonu** (Kalman ⊕ Aşama-4 LQR) + IMU-payload validasyonu Aşama 5'te kalır.

### Önkoşul
- Aşama 4 (K5–K6) tamam **veya** kanıta-bağlı atlandı (RGA decentralized'i doğruladıysa)
- K7 Kalman tek-eksen ön-tasarım ✅ (2026-06-13, §12.7.5: complementary'yi 2.8× geçer, bias kestirir); LQG entegrasyon sim (Kalman ⊕ Aşama-4 LQR) Aşama 5'te
- 3D-print şasi tasarımı (Fusion 360 / FreeCAD)
- Motor mount + IMU mount
- Slip-ring veya esnek kablo (kabloların kopmaması)

### ⚠ KRİTİK NOT — Kazanç Yeniden Ayarı (Aşama 2.3 bulgusundan)

**Aşama 2-4 kontrolcü kazançları SERBEST MİL (yüksüz motor) için ayarlandı.** Aşama
2.3'te keşfedildi ki serbest mil **worst-case**: yüksüz motor çok hafif/hızlı (0.5
duty ≈ 280 rad/s no-load), bu yüzden kazançlar çok düşük tutulmak zorunda kaldı
(Kp=0.002, conservative tasarımdan 58× düşük) — aksi halde limit cycle.

**Aşama 5'te gerçek gimbalda kamera + şasi yükü eklenince:**
- Efektif atalet (J) artar → plant yavaşlar → τ_m büyür
- No-load hızı düşer → saturation-setpoint uyumsuzluğu azalır
- **Kontrolcü kazançları YENİDEN AYARLANMALI** — yük ile sistem tanımlama (Aşama 1
  tekrarı, yük dahil) → yeni K, τ → yeni kazançlar
- Muhtemelen daha yüksek kazançlar mümkün olacak (yük plant'i kontrol edilebilir kılar)

Bu, "serbest milde çalışan kazanç gimbalda da çalışır" varsayımının **yanlış**
olduğu anlamına gelir. Aşama 5.2 (mekanik montaj) sonrası **5.x — yük ile yeniden
sistem tanımlama + kazanç ayarı** alt-adımı eklenmeli.

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

- **VM hattı sigorta entegrasyonu** — Tek motor döneminde 1.5 A polyfuse planlanmıştı; **2 motorda (Aşama 3+) ~2.5–3 A polyfuse** gerekir (normal 2-motor stall 1.6 A'yi taşımalı; oto-reset PTC "sistem ölü kalmasın" hedefine uygun). Kullanıcı temin edince aktif aşamaya alınır. ⚠ Polyfuse kabloyu/adaptörü korur, 1.0 A'lik sürücüyü KORUMAZ (o, yazılım katmanlarının işi — ROADMAP Aşama 3 güç planı).
- **Duty cap %50 → %100 gevşetme** — Ön koşul: **ACS712 akım foldback** (stall @12V 1.1 A > TB6612 sürekli 1.0 A — dar boğaz sürücü, Aşama 3 güç planı) + sigorta. Kontrolcü stabilse.
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
