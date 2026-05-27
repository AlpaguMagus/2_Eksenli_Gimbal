# Kaynakça

> Akademik referanslar, datasheet'ler, kütüphane dokümantasyonu.
> Her giriş **etiketli** (`[Yazar+Yıl]`), commit mesajlarında, kod yorumlarında
> ve ROADMAP'te bu etiketle referans verilir.
>
> **Son güncelleme:** 2026-05-17
>
> Bu dosya canlıdır — her yeni teknik karar için ek girişler eklenir.
> BibTeX/LaTeX yok (gerekirse sonra dönüşüm).

---

## Sistem Tanımlama

- **[Ljung1999]** L. Ljung, *"System Identification: Theory for the User"*, 2nd ed., Prentice Hall, 1999.
  - §3: parametrik model yapıları (ARX, output-error, state-space)
  - §4: prediction error methods, lineer 1. derece fit
  - §16: model validation (residual analysis, K-fold cross-validation)

- **[Soderstrom1989]** T. Söderström, P. Stoica, *"System Identification"*, Prentice Hall, 1989.
  - Daha eski ama kapsamlı; least-squares fit derivation için temel

- **[Olsson1998]** H. Olsson, K.J. Åström, C. Canudas de Wit, M. Gäfvert, P. Lischinsky, *"Friction Models and Friction Compensation"*, European Journal of Control, 1998.
  - Coulomb + viskoz + stiction (statik) sürtünme modelleri; LuGre dinamik model
  - Aşama 2.6.5: cascade gerçekçi simde Coulomb/stiction (Karnopp minimal hali) — sürtünme limit-cycle'ı söndürdü, sim-to-real gap kapandı

## Klasik Kontrol (PID, Cascade)

- **[Franklin2010]** G. Franklin, J.D. Powell, A. Emami-Naeini, *"Feedback Control of Dynamic Systems"*, 6th ed., Pearson, 2010.
  - §3: dinamik model çıkarımı
  - §4-6: root locus + PID design
  - §6.4: cascade kontrol, iç döngü en az 5× daha hızlı kuralı
  - §9: durum uzayı + pole placement

- **[Ogata2010]** K. Ogata, *"Modern Control Engineering"*, 5th ed., Prentice Hall, 2010.
  - Daha klasik yaklaşım, Türkçe çevirisi de var
  - §5: PID tuning yöntemleri (Ziegler-Nichols, Cohen-Coon)

- **[AstromMurray2008]** K.J. Åström, R.M. Murray, *"Feedback Systems: An Introduction for Scientists and Engineers"*, Princeton University Press, 2008.
  - Açık erişim PDF: <https://fbswiki.org/>
  - §10: PID derinlemesine, anti-windup, integrator wind-up
  - §11: cascade ve gain scheduling

## Modern / Optimal Kontrol (LQR, LQG)

- **[Anderson2007]** B.D.O. Anderson, J.B. Moore, *"Optimal Control: Linear Quadratic Methods"*, Dover, 2007 (orig. Prentice Hall, 1989).
  - §2: LQR formülasyonu ve Riccati denklemi
  - §3: closed-loop özellikleri, stability margin
  - §6: LQG kombinasyonu

- **[Friedland2005]** B. Friedland, *"Control System Design: An Introduction to State-Space Methods"*, Dover, 2005.
  - State-space yaklaşımına giriş, MIMO için temel

## State Estimation (Kalman, Luenberger)

- **[Simon2006]** D. Simon, *"Optimal State Estimation: Kalman, H∞, and Nonlinear Approaches"*, Wiley, 2006.
  - §5: Kalman filter ayrıntılı derivation
  - §6: extended Kalman filter (EKF)
  - §13: H∞ filter

- **[Luenberger1971]** D.G. Luenberger, *"An introduction to observers"*, IEEE Trans. Automatic Control, vol. 16, no. 6, pp. 596-602, 1971.
  - Klasik Luenberger observer makalesi (Kalman'ın deterministik alternatifi)

## MIMO Sistemler

- **[Skogestad2005]** S. Skogestad, I. Postlethwaite, *"Multivariable Feedback Control: Analysis and Design"*, 2nd ed., Wiley, 2005.
  - §3: MIMO sistemler giriş
  - §10: decoupling, condition number, RGA (Relative Gain Array)
  - §11: H∞ ve µ-synthesis (ileri seviye)

## Gimbal / Kamera Stabilizasyonu

- *(Aşama 3-5'te eklenecek — gimbal-spesifik akademik makaleler)*

## Sensör Füzyonu

- **[Mahony2008]** R. Mahony, T. Hamel, J.-M. Pflimlin, *"Nonlinear Complementary Filters on the Special Orthogonal Group"*, IEEE Trans. Automatic Control, vol. 53, no. 5, pp. 1203-1218, 2008.
  - Madgwick ve quaternion füzyon için temel
  - Mevcut complementary filter (Aşama 0) lineer versiyon — bu makale nonlinear genişletmeyi anlatır

- **[Madgwick2010]** S.O.H. Madgwick, *"An efficient orientation filter for inertial and inertial/magnetic sensor arrays"*, 2010.
  - <https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/>
  - Madgwick filter — ±90° singülarite çözümü için (Aşama 5 sonrası opsiyonel)

## Donanım — Datasheet'ler ve Üretici Belgeleri

- **[TB6612_DS]** Toshiba, *"TB6612FNG — Dual-channel motor driver"* datasheet.
  - Yerel: `datasheets/TB6612FNG/TB6612FNG.pdf`
  - §1.3: VM=2.5-13.5V, Vcc=2.7-5.5V (Aşama 0'da 3V3+12V seçildi)
  - §1.5: dead-time 50ns/230ns (yön değişim yazılım dead-band gerekmez)
  - §4: H-SW kontrol tablosu (Motor_SetDir mantığı)

- **[MPU6050_DS]** InvenSense, *"MPU-6050 6-axis MotionTracking Device"* datasheet.
  - Yerel: `datasheets/MPU6050/ps-mpu-6000a-00-mpu-6000-and-mpu-6050-datasheet.pdf`

- **[MPU6050_RM]** InvenSense, *"MPU-6050 Register Map and Descriptions"*.
  - Yerel: `datasheets/MPU6050/RS-MPU-6000A-00 - rm-mpu-6000a-00-mpu-6000-register-map.pdf`
  - Register 0x6B: PWR_MGMT_1 (uyandırma)
  - Register 0x3B-0x48: ACCEL + TEMP + GYRO burst okuma adresleri

- **[STM32F411_DS]** STMicroelectronics, *"STM32F411xC/xE Datasheet"*.
  - Yerel: `datasheets/WeAct Black Pill V2.0 STM32F411CEU6/STM32F411_datasheet.pdf`
  - Sf 28: TIM2/TIM5 32-bit, TIM3/TIM4 16-bit
  - Sf 38-52: Alternate function tablosu

- **[RM0383]** STMicroelectronics, *"RM0383 — STM32F411xC/E Reference Manual"*.
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
  - **48 CPR konvansiyon kararı:** Robotsepeti sayfası — *"Kuadratür enkoder her iki kanalda kenarlar için sayım yapması durumunda 48 CPR'lık bir çözünürlük sağlar"* → 48 zaten 4× decoded sayım (Aşama 0 Test 2A.T1'de doğrulandı)

- **[WeAct_BP]** WeAct Studio, *"BlackPill V2.0 STM32F411CEU6"*.
  - GitHub: <https://github.com/WeActStudio/WeActStudio.MiniSTM32F4x1>
  - STM32-Base: <https://stm32-base.org/boards/STM32F411CEU6-WeAct-Black-Pill-V2.0.html>
  - SPI flash footprint pinleri (PA4-PA7), KEY butonu (PA0), PWR LED

## Yazılım / Kütüphaneler

- **[STM32_HAL]** STMicroelectronics, *"STM32Cube HAL Driver"* dokümantasyonu.
  - PlatformIO `framework-stm32cubef4` v1.28.1 ile geliyor
  - `HAL_TIM_Encoder_Init`, `HAL_TIM_PWM_Start`, vb. API'ler

- **[Hunter2007]** J.D. Hunter, *"Matplotlib: A 2D graphics environment"*, Computing in Science & Engineering, vol. 9, no. 3, pp. 90-95, 2007.
  - Python görselleştirme (plot_angles.py, analiz grafikleri)

- **[pyMuPDF]** Artifex Software, *"PyMuPDF (fitz)"*.
  - <https://pymupdf.readthedocs.io/>
  - `datasheet-reader` skill için (`~/.claude/skills/datasheet-reader/`)

- **[NumPy_SciPy]** SciPy ekosistemi (NumPy, SciPy, pandas).
  - `scipy.optimize.curve_fit` — Aşama 1.3 motor model fitting

- **[MATLAB_R20XX]** MathWorks MATLAB.
  - Control System Toolbox, System Identification Toolbox, Simulink, Optimization Toolbox
  - Aşama 1-4: modelleme, kontrolcü tasarımı, simülasyon

## Standartlar / Pratik Notlar

- *(Aşama 1+ ilerledikçe eklenecek)*

---

## Etiket Kullanım Şablonu

Kod yorumlarında:
```c
/* PWM frekansı 20 kHz seçildi:
 *   - TB6612 max 100 kHz [TB6612_DS §1.3]
 *   - Audible threshold üstü → motor sesi minimum
 *   - Kontrol bant genişliği için yeterli [Franklin2010 §11.3]
 */
```

Commit mesajında:
```
feat(control): cascade PID hız iç döngü PI implementasyonu

İç hız döngüsü 200 Hz fixed sample. Kp/Ki pole placement ile:
  τ_cl = τ_ol / 5  [Franklin2010 §6.4 — cascade hızlık oranı]

Kazançlar matlab/asama_2_kontrol/cascade_pi.m'de hesaplandı.
Anti-windup back-calculation [AstromMurray2008 §10.4].
```

ROADMAP/dökümanlarda:
```markdown
**Kaynakça:** [Ljung1999], [Franklin2010], [TB6612_DS]
```
