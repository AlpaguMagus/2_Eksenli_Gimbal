# Kaynakça

> Akademik referanslar, datasheet'ler, kütüphane dokümantasyonu.
> Her giriş **etiketli** (`[Yazar+Yıl]`), commit mesajlarında, kod yorumlarında
> ve ROADMAP'te bu etiketle referans verilir.
>
> **Son güncelleme:** 2026-06-24 (Aşama-5 yüklü plant ID — atıf+yol düzeltmeleri)
>
> Bu dosya canlıdır — her yeni teknik karar için ek girişler eklenir.
> BibTeX/LaTeX yok (gerekirse sonra dönüşüm).

---

## Sistem Tanımlama

- **[Ljung1999]** L. Ljung, *"System Identification: Theory for the User"*, 2nd ed., Prentice Hall, 1999. ISBN 978-0-13-656695-3.
  - §3: parametrik model yapıları (ARX, output-error, state-space)
  - §4: prediction error methods, lineer 1. derece fit
  - §16: model validation (residual analysis, K-fold cross-validation)

- **[Soderstrom1989]** T. Söderström, P. Stoica, *"System Identification"*, Prentice Hall, 1989. ISBN 0-13-881236-5.
  - Daha eski ama kapsamlı; least-squares fit derivation için temel

- **[Olsson1998]** H. Olsson, K.J. Åström, C. Canudas de Wit, M. Gäfvert, P. Lischinsky, *"Friction Models and Friction Compensation"*, European Journal of Control, vol. 4, no. 3, pp. 176-195, 1998. DOI: <https://doi.org/10.1016/S0947-3580(98)70113-X>
  - Coulomb + viskoz + stiction (statik) sürtünme modelleri; LuGre dinamik model
  - Aşama 2.6.5: cascade gerçekçi simde Coulomb/stiction (Karnopp minimal hali) — sürtünme limit-cycle'ı söndürdü, sim-to-real gap kapandı
  - §6: friction compensation/feedforward — §12.8 yüklü Coulomb FF (u_c=0.090) + §12.12 HP stick-slip Coulomb FF (kff_coul=0.14) + §12.13.4 yön-bağımlı FF (rijit-ölçülen 0.14 fwd/0.20 rev)
- **[Karnopp1985]** D. Karnopp, *"Computer Simulation of Stick-Slip Friction in Mechanical Dynamic Systems"*, ASME Journal of Dynamic Systems, Measurement, and Control, vol. 107, no. 1, pp. 100-103, 1985. DOI: <https://doi.org/10.1115/1.3140698>
  - Stick-slip sürtünme sim modeli (dur/kay durum-makinesi: yapışıkken \|u\|>u_s ise kop, hareketteyken sıfır-geçişte yapış)
  - §12.13.4 HP cascade redesign nonlineer sim (`hp_cascade_redesign.m`): limit-cycle'ı ÜRETTİ + option-B'yi (pozisyon-integrali) eledi

## Klasik Kontrol (PID, Cascade)

- **[Franklin2010]** G. Franklin, J.D. Powell, A. Emami-Naeini, *"Feedback Control of Dynamic Systems"*, 6th ed., Pearson, 2010. ISBN 978-0-13-601969-5.
  - §3: dinamik model çıkarımı
  - §4-6: root locus + PID design (root-locus pole placement — frekans/s-düzlemi tasarım; §9 state-space pole placement'tan AYRI)
  - §4.2: system type & error constants (tip-1 $K_v$, ramp takip hatası $e_{ss}=\omega/K_v$ — mirror $K_{p,pos}$; §4.2/§4.3 ayrıca §12.12 HP cascade dış-P $K_{p,pos}=2.0$ tip-1 dayanağı)
  - §6.1: reference tracking (kapalı-çevrim $T(s)$ ile takip hatası — Aşama 3.3 sim-to-real RMS doğrulama, docs §12.4.4)
  - §6.4: cascade kontrol, iç döngü en az 5× daha hızlı kuralı (§12.12.2 HP cascade iç/dış ayrımı, ωc≤ωn/5)
  - §9: durum uzayı + pole placement (state-space; §6 root-locus pole placement'tan ayrı — MIMO/LQR tasarımına temel)

- **[Ogata2010]** K. Ogata, *"Modern Control Engineering"*, 5th ed., Prentice Hall, 2010. ISBN 978-0-13-615673-4.
  - Daha klasik yaklaşım, Türkçe çevirisi de var
  - §5: PID tuning yöntemleri (Ziegler-Nichols, Cohen-Coon)

- **[AstromMurray2008]** K.J. Åström, R.M. Murray, *"Feedback Systems: An Introduction for Scientists and Engineers"*, Princeton University Press, 2008.
  - Açık erişim PDF: <https://fbswiki.org/>
  - §10: PID derinlemesine, anti-windup, integrator wind-up
  - §11: cascade ve gain scheduling

## Modern / Optimal Kontrol (LQR, LQG)

- **[Anderson2007]** B.D.O. Anderson, J.B. Moore, *"Optimal Control: Linear Quadratic Methods"*, Dover, 2007 (orig. Prentice Hall, 1989). ISBN 978-0-486-45766-6.
  - §2: LQR formülasyonu ve Riccati denklemi
  - §3: closed-loop özellikleri, stability margin
  - §6: LQG kombinasyonu

- **[Friedland2005]** B. Friedland, *"Control System Design: An Introduction to State-Space Methods"*, Dover, 2005. ISBN 978-0-486-44278-5.
  - State-space yaklaşımına giriş, MIMO için temel

## State Estimation (Kalman, Luenberger)

- **[Simon2006]** D. Simon, *"Optimal State Estimation: Kalman, H∞, and Nonlinear Approaches"*, Wiley, 2006. ISBN 978-0-471-70858-2.
  - §5: Kalman filter ayrıntılı derivation
  - §6: extended Kalman filter (EKF)
  - §13: H∞ filter

- **[Luenberger1971]** D.G. Luenberger, *"An introduction to observers"*, IEEE Trans. Automatic Control, vol. 16, no. 6, pp. 596-602, 1971. DOI: <https://doi.org/10.1109/TAC.1971.1099826>
  - Klasik Luenberger observer makalesi (Kalman'ın deterministik alternatifi)

## MIMO Sistemler

- **[Skogestad2005]** S. Skogestad, I. Postlethwaite, *"Multivariable Feedback Control: Analysis and Design"*, 2nd ed., Wiley, 2005. ISBN 978-0-470-01168-3.
  - §3: MIMO sistemler giriş
  - §10: decoupling, condition number, RGA (Relative Gain Array)
  - §10.6.4: decentralized (diyagonal) kontrol — cascade PID = MIMO $K(s)$'in köşegen formu (Aşama 3.3 K0, docs §12.4.1)
  - §11: H∞ ve µ-synthesis (ileri seviye)

## Gimbal / Kamera Stabilizasyonu

- **[Hilkert2008]** J.M. Hilkert, *"Inertially Stabilized Platform Technology — Concepts and Principles"*, IEEE Control Systems Magazine, vol. 28, no. 1, pp. 26-46, Feb. 2008. DOI: <https://doi.org/10.1109/MCS.2007.910256>
  - Eylemsel olarak stabilize platform (ISP) kavramları ve prensipleri; gyro tabanlı taban-hareket reddi
  - §12.7.1 K2 gyro-FF dayanağı (taban açısal hızını ileri-besleme ile kompanze etme)

## Sensör Füzyonu

- **[Higgins1975]** W.T. Higgins, *"A Comparison of Complementary and Kalman Filtering"*, IEEE Trans. Aerospace and Electronic Systems, vol. AES-11, no. 3, pp. 321-325, 1975. DOI: <https://doi.org/10.1109/TAES.1975.308081>
  - Complementary filter ile Kalman filtresinin eşdeğerliği/karşılaştırması — sabit-katsayılı complementary filter'ın özel-durum Kalman olarak yorumu
  - §12.7.5 K7 dayanağı (complementary↔Kalman geçişi — mevcut Aşama 0 lineer complementary filter'ı Kalman çerçevesine bağlar)

- **[Mahony2008]** R. Mahony, T. Hamel, J.-M. Pflimlin, *"Nonlinear Complementary Filters on the Special Orthogonal Group"*, IEEE Trans. Automatic Control, vol. 53, no. 5, pp. 1203-1217, 2008. DOI: <https://doi.org/10.1109/TAC.2008.923738>
  - Madgwick ve quaternion füzyon için temel
  - Mevcut complementary filter (Aşama 0) lineer versiyon — bu makale nonlinear genişletmeyi anlatır

- **[Madgwick2010]** S.O.H. Madgwick, *"An efficient orientation filter for inertial and inertial/magnetic sensor arrays"*, Technical report, University of Bristol / x-io, 30 April 2010.
  - <https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/>
  - Madgwick filter — ±90° singülarite çözümü için (Aşama 5 sonrası opsiyonel)

- **[IEEE952]** IEEE Std 952-1997, *"IEEE Standard Specification Format Guide and Test Procedure for Single-Axis Interferometric Fiber Optic Gyros"*, Annex C: Allan variance. DOI: <https://doi.org/10.1109/IEEESTD.1998.86153>
  - Overlapping Allan deviation ile gyro gürültü karakterizasyonu: angle random walk (ARW, slope −1/2), bias instability (minimum, /0.664)
  - Aşama 0: MPU6050 statik logundan (`imu_noise_log.py`) ARW=1.09°/√hr, bias instab.≈3°/hr ölçüldü → complementary filter α=0.98 robustluk gerekçesi (`analyze_allan_variance.m`)

## Donanım — Datasheet'ler ve Üretici Belgeleri

- **[TB6612_DS]** Toshiba, *"TB6612FNG — Dual-channel motor driver"* datasheet.
  - Resmi: <https://toshiba.semicon-storage.com/info/TB6612FNG_datasheet_en_20141001.pdf>
  - Yerel: `datasheets/TB6612FNG/TB6612FNG.pdf`
  - §1.3: VM=2.5-13.5V, Vcc=2.7-5.5V (Aşama 0'da 3V3+12V seçildi)
  - §1.5: dead-time 50ns/230ns (yön değişim yazılım dead-band gerekmez)
  - §4: H-SW kontrol tablosu (Motor_SetDir mantığı)

- **[MPU6050_DS]** InvenSense (TDK), *"MPU-6050 6-axis MotionTracking Device"* datasheet.
  - Ürün sayfası: <https://invensense.tdk.com/products/motion-tracking/6-axis/mpu-6050/>
  - Yerel: `datasheets/MPU6050/ps-mpu-6000a-00-mpu-6000-and-mpu-6050-datasheet.pdf`

- **[MPU6050_RM]** InvenSense, *"MPU-6050 Register Map and Descriptions"*.
  - Yerel: `datasheets/MPU6050/RS-MPU-6000A-00 - rm-mpu-6000a-00-mpu-6000-register-map.pdf`
  - Register 0x6B: PWR_MGMT_1 (uyandırma)
  - Register 0x3B-0x48: ACCEL + TEMP + GYRO burst okuma adresleri

- **[STM32F411_DS]** STMicroelectronics, *"STM32F411xC/xE Datasheet"*.
  - Resmi: <https://www.st.com/resource/en/datasheet/stm32f411ce.pdf>
  - Yerel: `datasheets/WeAct Black Pill V2.0 STM32F411CEU6/STM32F411_datasheet.pdf`
  - Sf 28: TIM2/TIM5 32-bit, TIM3/TIM4 16-bit
  - Sf 38-52: Alternate function tablosu

- **[RM0383]** STMicroelectronics, *"RM0383 — STM32F411xC/E Reference Manual"*.
  - Resmi: <https://www.st.com/resource/en/reference_manual/rm0383-stm32f411xce-advanced-armbased-32bit-mcus-stmicroelectronics.pdf>
  - Yerel: `datasheets/WeAct Black Pill V2.0 STM32F411CEU6/STM32F411CEU6_manual.pdf`
  - §13.3.12 (sf 340-342): Encoder Interface Mode, Tablo 52
  - §23.3 (sf 808): SWJ debug port — PA15/PB3 SWD modunda serbest

- **[ARM_DWT]** ARM, *"Cortex-M4 Devices Generic User Guide"*, ARM DUI 0553.
  - <https://developer.arm.com/documentation/dui0553/latest/>
  - §11.3: Data Watchpoint and Trace Unit — DWT.CYCCNT 32-bit cycle counter
  - Aşama 1 T_US alanı: `DWT->CYCCNT / 96` → mikrosaniye (SYSCLK 96 MHz). 32-bit ≈ 44.7 sn wrap; fark hesabı unsigned subtraction ile her zaman doğru

- **[Pololu_25D]** Pololu Corp., *"25D mm Metal Gearmotors with 48 CPR Encoders"*.
  - <https://www.pololu.com/category/116>
  - Robotsepeti Türkçe sayfa: <https://www.robotsepeti.com/971-metal-gearmotor-25dx63l-mm-lp-12v-with-48-cpr-encoder>
  - Yerel: `datasheets/Pololu 9.7_1 Metal Redüktörlü Motor 25Dx63L mm LP 12V, 48 CPR Enkoderli/Datasheet/Page 1.png` + `Page 2.png` (klasör adı NTFS uyumu için `9.7_1`; ürün adı 9.7:1)
  - **LP 12V 9.68:1 elektriksel değerler (Page 1, amper bütçesi dayanağı):** stall 1100 mA @12V / 550 mA @6V; yüksüz 100 mA @12V; 560 rpm @12V; redüktör 9.68:1 (ürün adı 9.7:1 yuvarlama)
  - **48 CPR konvansiyon kararı:** Robotsepeti sayfası — *"Kuadratür enkoder her iki kanalda kenarlar için sayım yapması durumunda 48 CPR'lık bir çözünürlük sağlar"* → 48 zaten 4× decoded sayım (Aşama 0 Test 2A.T1'de doğrulandı)

- **[Pololu_25D_HP]** Pololu Corp., *"HP 12V 25D Motor, 48 CPR Enkoderli"* (PL-4840) — **yeni yedek motorlar (2026-06-13), LP'den FARKLI**.
  - Robotsepeti: <https://www.robotsepeti.com/pololu-hp-12v-motor-48-cpr-enkoderli-25d-reduktorlerle-uyumlu-pl-4840>
  - Yerel: `datasheets/Pololu HP 12V 25D 48CPR (PL-4840)/specs.md` + `25d-metal-gearmotor-dimension-diagram.pdf`
  - **HP 12V değerler:** boşta 10200 rpm, boşta 150 mA, **stall 5600 mA @12V**, stall tork 0.396 kg·cm; 48 CPR (LP ile aynı enkoder); K≈89 rad/s/V. **LP'nin ~5× stall akımı** → TB6612 (3.2A pik) AŞILIR, yüksek-akım sürücü (HW-039/BTS7960) gerekir. K=53.89 (LP) HP'de geçersiz.

- **[BTS7960_DS]** Infineon, *"BTS7960B — NovalithIC Half-Bridge"*; modül: **HW-039** (çift BTS7960 = tek tam H-köprü, modül başına 1 motor).
  - Yerel: `datasheets/BTS7960 (HW-039)/BTS7960-module-HW039-handsontec.pdf`
  - ~10-15A sürekli (43A pik), giriş 6-27V, arayüz **RPWM/LPWM + R_EN/L_EN** (TB6612 IN1/IN2/PWM'den FARKLI → firmware sürüş katmanı değişir). HP Pololu (5.6A stall) için yeterli; aşırı-büyük → IS akım-okuma çözünürlüğü kaba; klon güvenilirlik uyarısı.
  - **Çip dinamiği (DS Rev1.1, §12.11):** switch-delay ~3-25 µs, slew 1.6-11 V/µs, giriş Schmitt-trigger (RC YOK), p-kanal HS (charge-pump YOK) → çip **µs-mertebe hızlı**; gözlenen 450ms yavaşlık çipten DEĞİL (firmware-ramp confound'uydu, §12.11).
  - **UVLO/koruma (§12.11.6):** V_UV(OFF) ≤5.4 V — **Vs (B+ güç rayı, 8-18V)** izler, 5V VCC lojik DEĞİL → dropout için 12V'un ≤5.4V'a (6.6V sag) düşmesi gerekir, imkânsız (kablo yapamaz). Gözlenen aralıklı dropout = **adaptör OCP-hiccup** (`[Sagemcom_PSU]`), çip değil; **fix bench-DOĞRULANDI (2026-06-23):** ~940µF (2×470µF/25V) bulk B+/B− → 0.50 dropout YOK, τ63=76ms.

- **[DFR0601_DS]** DFRobot, *"Dual-Channel DC Motor Driver-12A"* (SKU DFR0601) — **kalıcı sürücü, 2-eksen (HP+LP) için sipariş edildi 2026-06-17**.
  - Resmi: <https://wiki.dfrobot.com/dfr0601/> · Yerel: `datasheets/DFR0601/specs.md`
  - **2 kanal × 12A sürekli** (70A pik 100ms), **290W**, VM 6.5–37V, lojik 3–5V (3.3V STM32 doğrudan), PWM 18–60kHz; arayüz **PWM + INA/INB** (kanal başı; TB6612 AIN1/AIN2/PWM'e benzer, STBY yok → migrasyon temiz). OV/UV/termal koruma. **HEM HP HEM LP'yi tek kart sürer** → asimetrik HW-039+TB6612 kalkar; 12A/kanal HP stall'ını (5.6A) rahat karşılar. **⚠ REVİZE (2026-06-22, docs §12.11):** "HW-039 yavaşlığına çözüm" gerekçesi DÜŞTÜ — 450ms firmware-ramp confound'uydu, HW-039 aslında HIZLI (τ≈70-100ms). DFR0601'in kalan değeri yalnız **12A akım başlığı + 2-kanal entegrasyon** (hız değil); aciliyet yok.

- **[Sagemcom_PSU]** Sagemcom CS50001 güç adaptörü = **Salcomp OEM switching** (P/N 191211367-XX / TT Electronics T7810RW; 60W varyant **ATS065T-P120**) — kullanıcının 12V beslemesi (set-top-box/router adaptörü).
  - **12V/5A/60W** (5A KATI tavan, headroom YOK); regülasyon 11.4-12.6V (±5%), yük-reg ~0.35V, ripple 60-65mV.
  - **⚠ OCP ~6A → hiccup** (komple kapanır + ~1s reset, akım-LİMİTLEMEZ — bench supply'ın CC'sinin aksine). HP inrush 5.6A bunu aşar → **aralıklı dropout kök-nedeni** (docs §12.11.6). **Fix bench-DOĞRULANDI (2026-06-23):** ~940µF (2×470µF/25V paralel) low-ESR bulk B+/B− geçici inrush'ı yutar → 0.50 dropout YOK; ⚠ sürekli akım tavanını yükseltmez, tam zarf/stall için ideali ≥6-7A/CC-capable kaynak. Kaynak: `motor-noise-dropout-literatur` workflow (Digikey-host ATS065 DS, 2016).
  - Yerel kopya yok — yalnız çevrimiçi (Digikey-host ATS065T-P120 DS, 2016)

- **[L298N_DS]** STMicroelectronics, *"L298 — Dual Full-Bridge Driver"*.
  - Yerel: `datasheets/L298N/L298N-datasheet.pdf`
  - ~1A gerçekçi sürekli (2A maks, heatsink), ~1.8-2.5V düşüm @1A → verim/ısı sorunu; HP (5.6A) SÜREMEZ; LP sürebilir ama TB6612 üstün. Atıl yedek.

- **[LM2596_DS]** Texas Instruments, *"LM2596 — Simple Switcher Power Converter 3A Step-Down"*.
  - Resmi: <https://www.ti.com/lit/ds/symlink/lm2596.pdf> · Yerel: `datasheets/LM2596/LM2596-TI-datasheet.pdf`
  - Ayarlı buck, giriş 4.5-40V, çıkış 1.5-37V, ~2A güvenli sürekli (3A maks). Lojik beslemesi (5V/3.3V) veya HP'yi ~6V'ta sürme (stall 2.8A, TB6612 pikine sığar ama buck 2A limiti stall'da dar boğaz).

- **[DFRobot_FIT0520]** DFRobot, *"Metal DC Geared Motor w/Encoder — 6V 300RPM 3.6Kg·cm"* (product-1619).
  - <https://www.dfrobot.com/product-1619.html> · Yerel: `datasheets/DFRobot product-1619/specs.md`
  - **6V** nominal, 20:1, stall 2.7A @6V, enkoder **44 sayım/dev motor şaftı (224.4 PPR çıkış — 48 CPR DEĞİL)**. Gimbal'de birincil aday değil (6V + farklı enkoder + Pololu gearbox uyumu doğrulanmadı).

- **[ACS712_DS]** Allegro MicroSystems, *"ACS712 — Fully Integrated, Hall-Effect-Based Linear Current Sensor IC"* datasheet (varyant: ACS712ELCTR-05B, ±5A).
  - Resmi: <https://www.allegromicro.com/-/media/files/datasheets/acs712-datasheet.pdf>
  - Yerel: `datasheets/ACS712/acs712-datasheet.pdf`
  - ±5A varyant (x05B): sensitivity 185 mV/A (sf 5); Vout(0A) = Vcc/2 (sf 4); bant genişliği 80 kHz (sf 4); toplam hata ±%1.5 (sf 5); gürültü 21 mV pp ≈ 113 mA (sf 5); izolasyon 2.1 kVRMS (sf 2); iletken direnci 1.2 mΩ (sf 4)
  - Aşama 3+ planlı kullanım: eksen-başı akım ölçümü + duty %100 gevşetmenin foldback ön koşulu (ROADMAP "Aşama 3 güç & koruma planı"); ≤1.1 A aralığımızda çıkış 2.5±0.21 V → 3.3V ADC doğrudan uyumlu

- **[WeAct_BP]** WeAct Studio, *"BlackPill V2.0 STM32F411CEU6"*.
  - GitHub: <https://github.com/WeActStudio/WeActStudio.MiniSTM32F4x1>
  - STM32-Base: <https://stm32-base.org/boards/STM32F411CEU6-WeAct-Black-Pill-V2.0.html>
  - SPI flash footprint pinleri (PA4-PA7), KEY butonu (PA0), PWR LED

## Yazılım / Kütüphaneler

- **[STM32_HAL]** STMicroelectronics, *"UM1725 — Description of STM32F4 HAL and low-layer drivers"*.
  - Resmi: <https://www.st.com/resource/en/user_manual/um1725-description-of-stm32f4-hal-and-lowlayer-drivers-stmicroelectronics.pdf>
  - PlatformIO `framework-stm32cubef4` v1.28.1 ile geliyor
  - `HAL_TIM_Encoder_Init`, `HAL_TIM_PWM_Start`, vb. API'ler

- **[Hunter2007]** J.D. Hunter, *"Matplotlib: A 2D graphics environment"*, Computing in Science & Engineering, vol. 9, no. 3, pp. 90-95, 2007. DOI: <https://doi.org/10.1109/MCSE.2007.55>
  - Python görselleştirme (plot_angles.py, analiz grafikleri)

- **[pyMuPDF]** Artifex Software, *"PyMuPDF (fitz)"*.
  - <https://pymupdf.readthedocs.io/>
  - `datasheet-reader` skill için (`~/.claude/skills/datasheet-reader/`)

- **[NumPy_SciPy]** SciPy ekosistemi (NumPy, SciPy, pandas).
  - `scipy.optimize.curve_fit` — Aşama 1.3 motor model fitting

- **[MATLAB]** MathWorks MATLAB R2024b. <https://www.mathworks.com/products/matlab.html>
  - Control System Toolbox, System Identification Toolbox, Simulink, Optimization Toolbox
  - Aşama 1-4: modelleme, kontrolcü tasarımı, simülasyon

## Standartlar / Pratik Notlar

> Bu bölüm, projede **fiilen kullanılan/dayanak olan** standartları toplar (genel-teorem şişirmesi yok — her giriş somut kod/donanım/karar çapasıyla). Sensör-füzyonu ve klasik-kontrol bölümlerindeki standartlar burada **tekrar edilmez**, yalnız çapraz-referans verilir.

### İletişim / Arayüz Standartları

- **[I2C_UM10204]** NXP Semiconductors, *"UM10204 — I²C-bus specification and user manual"*, Rev. 7.0, 1 October 2021. URL: <https://www.nxp.com/docs/en/user-guide/UM10204.pdf> (NXP doğrudan link bot-bloklu olabilir; resmi PDF Pololu mirror <https://www.pololu.com/file/0J435/UM10204.pdf> üzerinden de erişilebilir)
  - I²C = projenin **tek sensörü** MPU6050 IMU için fiili taşıma katmanı; STM32F411 I2C1 üzerinden okunuyor
  - **Projede kullanım:** `src/main.c:21` `MPU6050_ADDR (0x68<<1)` (7-bit slave adresleme, AD0=GND; spec §3.1.10); `src/main.c:523` `ClockSpeed=100000` (Standard-mode 100 kHz; spec §3.1.1); `:526` `AddressingMode=I2C_ADDRESSINGMODE_7BIT`; `:530` `NoStretchMode=I2C_NOSTRETCH_DISABLE` (clock stretching, spec §3.1.5 / Tablo 3); `:512-519` PB6/PB7 `GPIO_MODE_AF_OD` + `GPIO_PULLUP` — open-drain bus + pull-up zorunluluğu (spec §3.1.1) §12.13 BUSY-stuck fix'inin fiziksel dayanağı (pull-up'sız float → bus BUSY-stuck); `:601-616` 0x68/0x69 AD0-kayma + `WHO_AM_I=0x75` bus-tarama

- **[USB_CDC120]** USB Implementers Forum (USB-IF), *"Universal Serial Bus Class Definitions for Communication Devices"*, Revision 1.2, 3 November 2010. URL: <https://www.usb.org/document-library/class-definitions-communication-devices-12>. İlişkili taşıma spec'i: USB-IF, *"Universal Serial Bus Specification"*, Revision 2.0, 27 April 2000 (<https://www.usb.org/document-library/usb-20-specification>).
  - PC ↔ gimbal telemetri/komut kanalı **USB CDC-ACM** (sanal COM port) ile
  - **Projede kullanım:** `src/usbd_desc.c:41` `bDeviceClass=0x02` (Communications base class) + `:40` `bcdUSB 2.0`; VID `0x0483` / PID `0x5740` (`:6-7`, ST Virtual ComPort default); `src/usbd_cdc_if.c:17` `USBD_Interface_fops_FS` arayüz struct'ı (`CDC_Init/DeInit/Control/Receive_FS` üyeleri) + public `CDC_Transmit_FS` helper'ı (`:54`); `src/cmd_parser.c:3` `#include "usbd_cdc_if.h"`, `:289-290` host komutu (`CDC_Receive_FS`→parser) PING→PONG yanıtı `CDC_Transmit_FS` ile; `platformio.ini:14` `monitor_speed=115200`

- **[ARM_ADIv5]** Arm Ltd., *"Arm Debug Interface Architecture Specification ADIv5.0 to ADIv5.2"*, ARM IHI 0031 (güncel issue: 0031H, <https://developer.arm.com/documentation/ihi0031/h/>; önceki issue 0031G © 2006–2022). Serial Wire Debug (SWD) fiziksel protokolü ve SW-DP / SWJ-DP programlama modeli bu spec'te tanımlanır. URL: <https://developer.arm.com/documentation/ihi0031/latest/>
  - Firmware flash + debug yolunun upstream protokol spec'i (ST-Link V2 → SWD); MCU tarafını `[RM0383] §23.3` belgeler — bu giriş protokol-tarafı tamamlayıcı
  - **Projede kullanım:** `platformio.ini:5-6` `upload_protocol=stlink` / `debug_tool=stlink`; `:7-13` SWD adapter clock düşürmesi `adapter speed 200` (200 kHz — 2-motor rewire sonrası jumper güç-bütünlüğü gerekçesi, OpenOCD ile doğrulandı); `docs/00_donanim_semasi.md:65` `SWD IO/CLK | PA13/PA14 | SWJ-DP | ST-Link`; `docs/asama_0_altyapi.md:800` (OpenOCD + ST-Link SWD flash); `src/main.c:99` `CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk` (DWT/debug-core enable). STM32 SWJ-DP = ADIv5'in SW-DP/SWJ-DP implementasyonu

### Ayrık-Zaman / Örnekleme Standartları (klasik birincil kaynaklar)

- **[Shannon1949]** C. E. Shannon, *"Communication in the Presence of Noise"*, Proceedings of the IRE, vol. 37, no. 1, pp. 10-21, Jan. 1949. DOI: <https://doi.org/10.1109/JRPROC.1949.232969>
  - Örnekleme teoremi (sampling theorem) birinci formal ispatı → ayrık-zaman kontrol kararının margin-düzeyi dayanağı
  - **Projede kullanım:** `docs/asama_2_kontrol.md:325` (`ω_n=33 rad/s`, "Nyquist'in 14× altı, ayrık-güvenli"); `:411` (conservative kazancın `ω_c=1259` ile Nyquist'i aşması → bang-bang kök-nedeni; `f_Nyq=f_s/2` tanımı); `:415` (Şekil 11.11a); `ROADMAP.md:308` (2.T1 PASS gerekçesi: conservative `ω_c=1259 > Nyquist`). Kavram önce yalnız `[Franklin2010] §8`'e gevşek atıflıydı — Shannon klasik birincil kaynak

- **[Nyquist1928]** H. Nyquist, *"Certain Topics in Telegraph Transmission Theory"*, Transactions of the AIEE, vol. 47, no. 2, pp. 617-644, Apr. 1928. DOI: <https://doi.org/10.1109/T-AIEE.1928.5055024>
  - "Nyquist frekansı" ($f_{Nyq}=f_s/2$) teriminin eponim isim-kaynağı
  - **Projede kullanım:** `docs/asama_2_kontrol.md §11.11.8` (satır 411) literal tanım kutusu ("bir ayrık sistemin temsil edebileceği en yüksek frekans; üstündeki dinamik aliasing'e uğrar") + $\omega_c \ll \omega_{Nyq}$ tasarım kuralı margin analizinde uygulanıyor. Firmware örnekleme: `src/main.c:155` `Ts=0.008f` (8 ms / 125 Hz gerçek loop). Not: §11.11.8'in türettiği $\omega_{Nyq}$ sayıları tarihsel 140 Hz / 32 ms / 200 Hz vakalarına aittir; çekirdek iddia (terim adlandırması + $\omega_c \ll \omega_{Nyq}$ uygulaması) gerçek loop'ta da geçerli

> **Gyro gürültü standardı (overlapping Allan deviation):** Sensör gürültü karakterizasyonu IEEE Std 952-1997 Annex C'ye dayanır → bkz. **[IEEE952]** ("Sensör Füzyonu" bölümü). Standartlar bölümüne taşınmadı (duplikasyon önleme). Somut kullanım orada: Aşama 0 MPU6050 statik logundan ARW=1.09°/√hr, bias instab.≈3°/hr → complementary filter α=0.98 gerekçesi.

### Sayısal Temsil

- **[IEEE754]** IEEE Std 754-2019 (Revision of IEEE Std 754-2008), *"IEEE Standard for Floating-Point Arithmetic"*, Institute of Electrical and Electronics Engineers, 22 July 2019. DOI: <https://doi.org/10.1109/IEEESTD.2019.8766229>. ISBN 978-1-5044-5924-2.
  - binary32 (single-precision) formatı, yuvarlama modları, aritmetik işlem semantiği
  - **Projede kullanım — firmware kontrol hesapları tek-precision (binary32) `float` ile koşar:** complementary filter `alpha=0.98f` füzyonu (`src/main.c:235`, `:343-344` `atan2f`/`sqrtf`), `dt=cyc_diff/96000000.0f` (`:300`), gravite/Coulomb FF `sinf` (`LoadFF_Apply`, `:66`), gyro-FF LPF (`:428-430`); PI/P kontrolcü durum değişkenleri `float` (`include/speed_pi.h:52-57`; `include/position_p.h:35-44`). STM32F411 Cortex-M4F donanım FPU'su (FPv4-SP) IEEE 754 binary32 uyumlu → `float` aritmetik donanımda. Tasarım gerekçesi: `docs/asama_0_altyapi.md:438` (M4F double-precision HW içermez; `double` soft-float olur → binary32 bilinçli mühendislik tercihi). ⚠ Not: ARM Cortex-M4 FPU resmen IEEE Std 754-**2008**'e uyumlu belgelenir (ARM TRM); 754-2019, 2008'in geriye-uyumlu minör revizyonu olduğundan binary32 formatı/yuvarlama/temel aritmetik değişmez — en güncel sürüme atıf geçerlidir. ⚠ `platformio.ini:17` `-Wl,-u,_printf_float` flag'i newlib float-printf rutini link'ine dayanır (binary32 formatına değil) → ikincil/marjinal kanıt; birincil dayanak FPU + float aritmetiktir

---

## Etiket Kullanım Şablonu

> Aşağıdaki örnekler **çalışan firmware ile tutarlı tutulur** (bayat değer örnek-olarak bırakılmaz; güncelleme tetiği: firmware kazanç/loop/Ts değişikliği). Gerçek değerler: iç hız PI `Kp=0.002, Ki=0.10`, çalışan `ω_n=2/τ=33 rad/s`, doğan `ζ=0.58`; gerçek loop `Ts=8 ms / 125 Hz` (eski "200 Hz / 5 ms" yalnız nominal-varsayımdı — loop hiç koşmadı, docs §12.14.1); anti-windup `Tt=Kp/Ki=0.02 s`.

Kod yorumlarında:
```c
/* PWM frekansı 20 kHz seçildi:
 *   - TB6612 max ~100 kHz [TB6612_DS §1.3]
 *   - Audible threshold üstü → motor sesi minimum
 *   - Kontrol bant genişliği için yeterli (loop Ts=8 ms ≫ üstünde) [Franklin2010]
 */
```

Commit mesajında:
```
feat(control): cascade hız iç döngü PI implementasyonu

İç hız döngüsü ayrık PI (Tustin), gerçek loop Ts=8 ms (125 Hz;
eski "200 Hz/5 ms" yalnız nominal-varsayımdı, §12.14.1). Kp/Ki analitik:
  doyum-kısıtı  Kp ≈ duty_max/ω_max = 0.002
  doğru-plant pole placement: ω_n = 2/τ = 33 rad/s (Kg=K·Vs=654.8)
    → Ki = ω_n²·τ/Kg = 0.10  (doğan ζ=0.58, margin PM≈60°)
  [Franklin2010 §6 — pole placement; §6.4 cascade hızlık oranı]

Kazançlar matlab/asama_2_kontrol/design_speed_pi_corrected.m'de hesaplandı.
Anti-windup back-calculation, Tt=Kp/Ki=0.02 s [AstromMurray2008 §10.4].
```

ROADMAP/dökümanlarda:
```markdown
**Kaynakça:** [Ljung1999], [Franklin2010], [TB6612_DS]
```
