# ROADMAP — İki Eksenli Gimbal Geliştirme Yol Haritası

> **Bu doküman canlıdır.** Her milestone tamamlandığında güncellenir.
>
> - **Son güncelleme:** 2026-05-27 (Aşama 2 ✅ KAPALI — IMU mirror Test 2.T6 PASS + 2.9 akademik kapanış; main'e merge + asama-2-kapali tag)
> - **Aktif aşama:** Aşama 2 ✅ KAPALI → **Aşama 3 (İki Motor MIMO Model)** açılışı, yeni branch `feature/asama-3-mimo-model`
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
| `docs/00_genel_bakis.md` | Vizyon, sistem mimarisi, aşamalar-arası ortak teori | Mimari değişikliği |
| `docs/asama_<N>_*.md` | **Derin akademik içerik:** teori, türetme, tasarım gerekçesi, alternatifler, deney sonucu (ne/neden/nasıl/nerede/sonuç) | İlgili aşama ilerleyince |
| `ROADMAP.md` (bu dosya) | Yol haritası, aşamalar, adımlar, testler, tamamlanma kanıtı | Her adım/aşama bitiminde |
| `PROJE_DURUMU.md` | "Şu an neredeyiz?" 5-10 satır özet + ROADMAP linki | Aşama geçişlerinde |
| `CLAUDE.md` | AI etkileşim kuralları + proje standartları | Yeni kural eklendiğinde |
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

- **2A.T5-B (gerçek motor stall testi):** KEY simülasyonu (Aşama A) PASS. Gerçek motor stall (eldivenle şaftı tut + multimetre <0.9 A) bağımsız donanım doğrulaması, sonraki seansa bırakıldı — Aşama 1'i engellemiyor.
- ~~**R6 (CW%20 ölü-bant değişkenliği)**~~ ✅ **ÇÖZÜLDÜ 2026-05-18 (artifact: `artifacts/1/stiction_test/20260518_111200/`):** Önce stiction hipotezi ile açıklandı (Aşama 1.3), sonra deneysel test ile **stiction reddedildi** (cold-start dahil tüm duty'lerde motor başlıyor). T7 ham log yeniden analizi: motor T7'de aslında dönmüş (ΔEC ≈ 1750 her cycle, ω ≈ 76 rad/s). Anomalinin nedeni: o dönem firmware OMEGA alanını göndermiyordu, Python analizi varsayılan 0.0 raporladı. **R6 fiziksel değil, analiz/parsing artefaktıydı.**

---

## ✅ Aşama 1 — Tek Motor Sistem Tanımlama  *(KAPALI 2026-05-18)*

> **Branch:** `feature/asama-1-tek-motor-model`
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

- **1.1 — Veri toplama altyapısı:** `scripts/step_response.py` Python tarafı (handshake_test.py temel alınarak). 6 duty × 2 yön = 12 step. 200 Hz örnekleme. Çıktı: `artifacts/1/step_response/<test_id>/raw/data.csv.gz` + meta.json + summary.md.
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
  - `src/main.c` — SpeedPI_Init (Kp=0.1163, Ki=4.0447, Ts=5ms, T_t=28.75ms),
    SP_W modda her 200 Hz tick'te SpeedPI_Step → Motor_SetDir + Motor_SetDuty,
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
  - main.c: default kazanç Kp=0.002, Ki=0.1 (ampirik)
  - main.c: dt→DWT µs (ms jitter giderme)
  - main.c: SP_W'de Motor_Tick bypass, Motor_SetDutySigned doğrudan PWM
  - encoder.c: Encoder_FilterSpeed moving-avg (WINDOW=5)
  - speed_pi.c: SpeedPI_SetGains + setpoint slew rate
  - cmd_parser.c: KP:/KI:/SLEW: runtime tuning komutları
  - motor.c: Motor_SetDutySigned (rampasız kapalı döngü PWM)

  Artifact: `artifacts/2/T2_3_speed_pi_tuning/` + `speed_gain_sweep/` + `slew_sweep/`
  Detay: docs/asama_2_kontrol.md §11.12

  Kalan: ampirik kazancı 2b Simulink'te teorik doğrula. Sonra programatik
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
  - Gimbal-hızı (~25-30°/s): RMS 4.68° (Kp=5) PASS; Kp_pos=6 analitik 4.63°
  - Hızlı el (~80°/s): bant genişliği limiti (~10° RMS, beklenen — cascade ~0.3 Hz)
  - Detay: docs/asama_2_kontrol.md §11.13.8

- **2.9 — Akademik rapor + Simulink karşılaştırma**
  - docs/asama_2_kontrol.md — el kitapçığı disipliniyle Aşama 2 sonuç bölümü
  - 4 yöntem karşılaştırma tablosu (pole placement / pidtune robust / balanced / fast)

### Test ve Doğrulama (iskelet)

| # | Test | Beklenen | Durum |
|---|---|---|---|
| 2.T1 | Pole placement + pidtune kazançları | Gain margin ≥ 6 dB, phase margin ≥ 45° | ☐ |
| 2.T2 | Hız step response (firmware) | settling < 5τ, overshoot < %10, ss_error < %2 | ✅ PASS (Kp=0.002, 8/8 step temiz, ss_err çoğunlukla <%2, bang-bang yok. Settling/OS metrikleri düşük setpoint'te encoder kuantizasyonu ile sınırlı — `artifacts/2/speed_step/20260524_180610/`) |
| 2.T3 | Anti-windup recovery | Saturation sonrası recovery < 100 ms | ☐ |
| 2.T4 | Disturbance rejection | Yük sonrası setpoint'e dönüş | ✅ PASS — elle yük (7 müdahale), ω %82 düştü, PI duty 0.18→0.5 telafi, setpoint'e döndü. `artifacts/2/disturbance/20260524_192851/` (7 u piki grafiği). Recovery süresi metriği encoder kuantizasyonu ile sınırlı. |
| 2.T5 | Cascade pozisyon step | Overshoot < %10, ss_error < 1° | ✅ PASS — 6/6 segment (30/90/45/0/-45/0°), ss_err <0.8°, OS <1°, **limit-cycle yok** (θ_std <0.7°). Gerçekçi sim limit-cycle öngördü ama gerçek motor sürtünmesi söndürdü (sim kötümserdi). `artifacts/2/position_step/20260524_212456/` |
| 2.T6 | Mirror takip (KRİTİK) | RMS < 5° | ✅ PASS — gimbal-hızı (~25-30°/s) RMS **4.68°** (Kp_pos=5), analitik Kv tasarımı Kp_pos=6→4.63° doğruladı. Hızlı el (~80°/s) bant-genişliği limiti (~10°, beklenen). `artifacts/2/mirror/20260526_204240/` |

### Açık Sorular (alt-aşama açılışlarında)

- **2.1:** Pole placement için τ_cl hedef seçimi (12 ms / 20 ms / 30 ms tradeoff)? `pidtune` Robustness slider varsayılan mı, override mı?
- **2.5:** Dış döngü P vs PI? Pozisyon ss_error gerekiyorsa PI, ama integral wind-up artar — P ile başlayalım, gerekirse PI'a geç.
- **2.7:** IMU mirror gain (1.0 sabit mi yoksa ölçek faktörü mü)? Breadboard hareketi vs motor şaftı 1:1 mi yoksa 9.7:1 redüktör hesaba katılır mı?

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
