# 2 Eksenli Gimbal — Kontrol Mühendisliği Projesi

> **Platform:** STM32F411CEU6 (WeAct BlackPill V2.0) · **Sensör:** MPU6050 6-DOF IMU
> **Mimari:** Bare-metal, STM32Cube HAL · **Build:** PlatformIO · **Tasarım aracı:** MATLAB (System Identification, Control System, Simulink)

İki eksenli kamera gimbal'ına ulaşan **5 aşamalı kontrol mühendisliği projesi**. Tek motorun deneysel modellenmesinden (sistem tanımlama) başlayıp, klasik kontrol (PI/PID/cascade), MIMO modelleme, optimal kontrol (LQR/LQG + Kalman) üzerinden gerçek 3D-baskı gimbal stabilizasyonuna ilerler. Her teknik karar literatür kaynaklıdır; MATLAB'da tasarlanan kontrolcü parametreleri firmware'e manuel transfer edilir.

> Bu README projenin **vitrinidir** (ne, nasıl çalıştırılır, nereye bakılır). Derin teknik/akademik içerik — teori, türetmeler, tasarım gerekçeleri, deney sonuçları — aşama-bazlı belgelerdedir: [`docs/`](docs/).

---

## 📍 Şu An Neredeyiz

| Aşama | Durum | Sonuç |
|---|---|---|
| **0 — Altyapı** | ✅ KAPALI | Donanım + firmware + IMU füzyonu + USB CDC + koruma katmanları |
| **1 — Sistem Tanımlama** | ✅ KAPALI | `K=53.89 rad/s/V, τ=60.5 ms, V_dead≈0` — model NRMSE %11 (Test 1.T5 PASS) |
| **2 — Tek Motor Kontrol** | ✅ KAPALI | Hız PI + sim-to-real gap + disturbance + pozisyon cascade + IMU mirror — **2.T1–T6 tüm testler PASS** (anti-windup sim+gerçek 637ms) |
| **3 — MIMO Model** | ✅ YÜKSÜZ KAPALI | **Yüksüz kontrol merdiveni K0–K4 bench-valide.** K0 decentralized cascade (LP rijit pos 6/6, mirror 5.72°, stab 5.08°) · K1 iki-eksen decentralized (LP 6/6, HP 4/6, çapraz-girişim yok) · K2 gyro-FF (stab lag 272→32 ms, %88↓) · K3 gereksiz (τ ~sabit) · K4 serbest-mil coupling off-diag~0. **HP ekseni** rijit karakterize ($K_g\approx 974/897$ rad/s/duty, $\tau\approx 72$ ms) + analitik cascade; loop 8 ms (I2C BUSY artefaktı çözüldü, `GPIO_PULLUP`). Residual sürtünme-limit-cycle + **derin K4 RGA + yüklü stabilizasyon = Aşama 5** |
| 4 — MIMO Kontrol | ⬜ | Decoupling + LQR/LQI (kanıta-dayalı, RGA kapısı) |
| **5 — Gerçek Gimbal** | 🟡 AÇIK | Yüklü plant-ID (a=0.23, sürtünme 0.06/0.03) + analitik kontrol (Y1) + bench-validasyon — branch `feature/asama-5-yuklu-gimbal` |

**Şu an (2026-06-24):** ✅ **Aşama 3 (yüksüz MIMO) KAPANDI** — yüksüz kontrol merdiveni **K0–K4 bench-valide**: K0 decentralized cascade (LP rijit pos 6/6, mirror 5.72°, stab 5.08°), K1 iki-eksen decentralized (LP 6/6 + HP 4/6, çapraz-girişim yok), K2 gyro-FF (stab lag 272→32 ms, %88↓), K3 gereksiz (τ ~sabit 1.22×), K4 serbest-mil coupling off-diag~0 (decentralized sayıyla gerekçeli). **HP ekseni** rijit karakterize ($K_g\approx 974/897$ rad/s/duty yön-asimetrik, $\tau\approx 72$ ms) + analitik cascade (§12.12); loop gerçek 8 ms (sanılan "~32 ms" kopuk-IMU I2C BUSY-timeout artefaktıydı → tek-satır `GPIO_PULLUP`); residual sürtünme-limit-cycle yapısal → K7. **Sıradaki — Aşama 5 (yüklü gimbal):** IMU payload'a taşınınca plant yeniden-ID + derin K4 RGA + HP-K7 (Kalman) + yüklü stabilizasyon. Kronoloji → [`PROJE_DURUMU.md`](PROJE_DURUMU.md) / [`ROADMAP.md`](ROADMAP.md); detay → [`docs/asama_3_mimo_model.md`](docs/asama_3_mimo_model.md) §12.14.

> 🔎 **Önceki ara-bulgular** (kronoloji PROJE_DURUMU/ROADMAP'te): K0 kapanışı (2026-06-12) · HW-039 "yavaş τ≈400-450ms" hükmü çürütüldü → hızlı τ≈70-100ms, firmware-ramp confound (2026-06-17, §12.11) · "7ms/140Hz loop" iddiası hiç ölçülmedi/varsayım, çürütüldü (§12.13.1).

---

## 🗺 Dokümantasyon Haritası

Her belge tek bir soruyu, tek bir okuyucu kitlesine cevaplar:

| Belge | Cevapladığı soru | Okuyucu |
|---|---|---|
| **README.md** (bu dosya) | Proje ne, nasıl çalıştırılır, nereye bakılır? | İlk gelen / GitHub |
| [`docs/00_genel_bakis.md`](docs/00_genel_bakis.md) | Vizyon + **ortak kontrol teorisi primer'i** (transfer fn, kararlılık, Bode, tip sistem)? | Jüri / yeni başlayan |
| [`docs/00_donanim_semasi.md`](docs/00_donanim_semasi.md) | **Tam donanım şeması** — pin haritası, kablolama (renk-renk), güç, ortak GND (TEK kaynak) | Donanım kuran / geliştirici |
| [`docs/asama_0_altyapi.md`](docs/asama_0_altyapi.md) | Donanım, firmware, IMU füzyonu, USB, motor/encoder **nasıl** kuruldu? | Geliştirici |
| [`docs/asama_1_model.md`](docs/asama_1_model.md) | Motor modeli (K, τ) **nasıl/neden** çıkarıldı, **sonuç** ne? | Jüri (akademik) |
| [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md) | Kontrolcü **neden** öyle tasarlandı, **alternatifler**, **sonuç**? | Jüri (akademik) |
| [`docs/asama_3_mimo_model.md`](docs/asama_3_mimo_model.md) | **MIMO model** (yüksüz KAPALI) — 2-eksen mimari, HP/LP asimetri, cascade, teşhis? | Jüri / geliştirici |
| [`docs/asama_5_yuklu_gimbal.md`](docs/asama_5_yuklu_gimbal.md) | **Yüklü gimbal** (aktif aşama) — yüklü plant-ID (a=0.23), gravite/sürtünme ayrıştırma, stabilizasyon yeniden-tasarım? | Jüri / geliştirici |
| [`ROADMAP.md`](ROADMAP.md) | **Ne planlanıyor**, açık sorular, test iskeleti? | Geliştirici / danışman |
| [`PROJE_DURUMU.md`](PROJE_DURUMU.md) | **Şu an neredeyiz**, en son ne yapıldı? | Gelecek-ben / danışman |
| [`KAYNAKCA.md`](KAYNAKCA.md) | Hangi **literatüre** dayanıyor? (etiketli bibliyografya) | Akademik denetim |
| [`matlab/README.md`](matlab/README.md) | MATLAB tasarım scriptleri nasıl çalışır? | MATLAB kullanıcısı |
| [`CLAUDE.md`](CLAUDE.md) | Geliştirme/dokümantasyon standartları nedir? | Katkı veren |

**İzlenebilirlik ilkesi:** Her teknik karar `[Kaynak]` etiketli ([`KAYNAKCA.md`](KAYNAKCA.md)), her deney sonucu [`artifacts/`](artifacts/)'ta kanıtlı (summary.md + meta.json + ham veri + grafik).

---

## ⚙ Sistem Mimarisi

> ⚠ **INTERIM (2026-06-17):** Aşağıdaki şema **tek-motor Aşama-0 dönemindendir** ve güncel değildir. Güncel: **Motor1/HP = HW-039/BTS7960** (RPWM=PB8 / LPWM=PB9 / EN=PB14, TIM4); **Motor2/LP = TB6612** (PB1/PB4/PB5/PB10, TIM3). Güncel pin haritası → [`docs/00_donanim_semasi.md`](docs/00_donanim_semasi.md) §2.
> **Güç (güncel):** tek 12V Sagemcom PSU + ~940µF bulk kapasitör (dropout fix; ASCII'deki "Mervesan 12V/3A" eskidir). Bulk yalnız inrush'ı çözer; tam akım zarfı/stall için ≥6-7A besleme gerekir → [`docs/00_donanim_semasi.md`](docs/00_donanim_semasi.md) §4.1.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        STM32F411CEU6                                 │
│                                                                      │
│  ┌──────────┐  I2C1   ┌───────────┐                                  │
│  │          │◄───────►│  MPU6050  │  açı/açısal hız sensörü          │
│  │          │ PB6/PB7 │  6-DOF    │                                  │
│  │   ARM    │         └───────────┘                                  │
│  │ Cortex-M4│                                                        │
│  │  96 MHz  │  TIM2    ┌──────────────────────┐                      │
│  │          │◄═════════│ Pololu 25D Encoder   │ 48 CPR kuadratür     │
│  │          │ PA15/PB3 │ (5V besleme)         │                      │
│  │          │          └──────────────────────┘                      │
│  │          │                                                        │
│  │          │  TIM3    ┌────────────┐  PWM   ┌──────────────┐        │
│  │          │═════════►│            │═══════►│              │        │
│  │          │ PB0      │  TB6612FNG │ AO1/2  │  Pololu 25D  │        │
│  │          │  GPIO    │   motor    │═══════►│  12V motor   │        │
│  │          │═════════►│  driver    │        └──────────────┘        │
│  │          │ PB12-14  │            │           ▲                    │
│  │          │ AIN1/2   │            │  VM 12V ──┤ (Mervesan 12V/3A)     │
│  │          │ STBY     └────────────┘                                │
│  │          │                                                        │
│  │          │ ──── USB CDC (Type-C) ────► PC (/dev/ttyACM0)          │
│  │          │ ──── PC13 ────► LED (durum)                            │
│  └──────────┘                                                        │
└──────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │   PC (Linux/Python)   │
                    │   matplotlib gerçek   │
                    │   zamanlı görsel      │
                    └───────────────────────┘
```

**Bare-metal süper-loop:** RTOS yok. Ana döngü `sensör oku → filtrele → kontrol → USB I/O → tekrarla` (ölçülen ~8 ms / ~125 Hz; DWT — IMU okunurken gerçek değer; §12.13'teki ~6 ms IMU-NACK durumuydu, başarılı I2C okuma +2 ms ekler → 8 ms gerçek, §12.14.1). ⚠ Önceki "~7 ms/140 Hz" değeri ölçülmemiş varsayımdı (çürütüldü, §12.13.1). Düşük gecikme, deterministik zamanlama. Mimari detay → [`docs/00_genel_bakis.md`](docs/00_genel_bakis.md).

---

## 🚀 Hızlı Başlangıç

**Gereksinimler:** PlatformIO Core, Python 3 (`pyserial`, `matplotlib`), MATLAB (tasarım scriptleri için, opsiyonel).

```bash
# Firmware derle
pio run

# Flash (BlackPill USB DFU veya ST-Link)
pio run -t upload

# Gerçek zamanlı IMU görselleştirme (PC tarafı)
python plot_angles.py

# Kontrol testleri (motor bağlı, mil serbest)
python3 scripts/speed_step_test.py        # hız PI step response
python3 scripts/position_step_test.py     # pozisyon cascade step
python3 scripts/disturbance_test.py       # disturbance rejection
```

**USB komut seti** (115200 baud, `/dev/ttyACM0`):

| Komut | Açıklama |
|---|---|
| `MODE:DUTY` / `MODE:SP_W` / `MODE:POS` | Açık döngü / hız PI / pozisyon cascade modu |
| `DUTY:<±float>` | Açık döngü duty (işaret = yön) |
| `SP_W:<±float>` | Hız setpoint (rad/s) — SP_W modda |
| `POS_DEG:<±float>` | Pozisyon hedefi (çıkış mili derece) — POS modda |
| `KP:` / `KI:` / `SLEW:` / `KPP:` | Runtime kazanç ayarı (flash'sız) |
| `STOP` / `RESET` / `PING` | Durdur / lockout temizle / handshake |
| `IMUDIAG` / `IMUINIT` | IMU I2C sağlık teşhisi (bus/uyku/AD0) / çek-taksız uyandırma |

> ℹ️ **Eksen-1 (LP):** Aynı komut seti `2` son-ekiyle (`MODE2:`, `POS_DEG2:`, `KPP2:` …). `MIRROR` / `STAB` (IMU mirror / stabilizasyon) modları dahil tam liste → [`docs/asama_3_mimo_model.md`](docs/asama_3_mimo_model.md).

> 🔧 **IMU kendini-iyileştirme (otomatik):** Sarsıntı/güç-glitch'i IMU'yu uykuya veya I2C'yi stuck'a sokarsa firmware ardışık ~40 başarısız okumadan sonra **bus-clear (9 SCL pulse) + re-init** yapar — USB çek-tak gerekmez, USB'ye `IMU_RECOVER` düşer (≥2 s cooldown).

Komut seti detayı → [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md).

---

## 📂 Repo Yapısı

```
2_Eksenli_Gimbal/
├── README.md                 ← Bu dosya (vitrin)
├── docs/                     ← Aşama-bazlı teknik/akademik belgeler
│   ├── 00_genel_bakis.md     ← Vizyon + ortak kontrol teorisi primer'i (denklem/diyagram)
│   ├── 00_donanim_semasi.md  ← Tek donanım şeması (pin/kablolama/güç)
│   ├── asama_0_altyapi.md    ← Donanım, firmware, IMU, filter, USB, motor/encoder
│   ├── asama_1_model.md      ← Sistem tanımlama (K, τ, dead-band)
│   ├── asama_2_kontrol.md    ← Hız PI, sim-to-real, disturbance, pozisyon cascade
│   ├── asama_3_mimo_model.md ← MIMO model (yüksüz KAPALI): 2-eksen mimari, HP/LP asimetri, cascade, teşhis
│   └── asama_5_yuklu_gimbal.md ← Yüklü gimbal: ID + stabilizasyon
├── src/                      ← Firmware kaynak
│   ├── main.c                ← Ana döngü: init, sensör, filter, kontrol, USB
│   ├── motor.c               ← Motor sürücü API (Motor1 HW-039/BTS7960 + Motor2 TB6612, asimetrik)
│   ├── encoder.c             ← TIM2 quadrature encoder
│   ├── speed_pi.c            ← Hız iç döngü PI (Tustin + anti-windup)
│   ├── position_p.c          ← Pozisyon dış döngü P (cascade)
│   ├── cmd_parser.c          ← USB CDC komut parser
│   └── usbd_*.c              ← USB CDC stack
├── include/                  ← Header'lar
├── scripts/                  ← PC tarafı test/veri toplama (Python)
│   ├── step_response.py      ← Aşama 1 veri toplama
│   ├── speed_step_test.py    ← Hız PI step response
│   ├── position_step_test.py ← Pozisyon cascade step
│   └── disturbance_test.py   ← Disturbance rejection
├── matlab/                   ← MATLAB tasarım/analiz (toolbox tabanlı; tam liste → matlab/README.md)
│   ├── 00_genel_teori/       ← Ortak kontrol teorisi figürleri/türetmeleri
│   ├── asama_0_altyapi/      ← Altyapı/filtre analizleri
│   ├── asama_1_model/        ← Sistem tanımlama pipeline
│   ├── asama_2_kontrol/      ← Kontrolcü tasarım + gerçekçi sim
│   ├── asama_3_mimo_model/   ← MIMO model (KAPALI, K0–K4 bench-valide)
│   ├── asama_4_mimo_kontrol/ ← MIMO kontrol ön-tasarım (K6 LQR/LQI)
│   └── asama_5_gimbal/       ← Yüklü gimbal: yüklü plant-ID (Y0) + analitik kontrol (Y1) + K7 Kalman
├── artifacts/                ← Test sonuçları (summary.md + meta.json + raw/ + grafik)
├── datasheets/               ← Donanım PDF/şematik belgeleri
├── plot_angles.py            ← Gerçek zamanlı matplotlib görselleştirme
├── platformio.ini            ← Build konfigürasyonu
├── ROADMAP.md                ← Yol haritası (planlananlar + açık sorular)
├── PROJE_DURUMU.md           ← Anlık durum özeti
├── KAYNAKCA.md               ← Akademik referanslar (etiketli)
└── CLAUDE.md                 ← Geliştirme/dokümantasyon standartları
```

---

## 📚 Referanslar

Akademik kaynaklar ve teknik karar dayanakları **etiketli liste** olarak [`KAYNAKCA.md`](KAYNAKCA.md)'de tutulur (ör. `[Franklin2010]`, `[Ljung1999]`, `[AstromMurray2008]`). Belgeler bu etiketlerle atıf verir.

**Donanım belgeleri:**
- WeAct BlackPill — [GitHub repo](https://github.com/WeActStudio/WeActStudio.MiniSTM32F4x1) · [STM32-Base](https://stm32-base.org/boards/STM32F411CEU6-WeAct-Black-Pill-V2.0.html)
- Yerel datasheet'ler: [`datasheets/`](datasheets/) — STM32F411, MPU6050, TB6612FNG, HW-039/BTS7960, L298N, DFRobot DFR0601, DFRobot product-1619, ACS712 (akım sensörü, ROADMAP rezerv), LM2596 (regülatör), Pololu motor **HP** PL-4840 (12V 25D 48CPR) + **LP** 9.7:1 48CPR (HP/LP asimetri projenin merkezi teması) — tam liste: [`datasheets/`](datasheets/)

**Donanım kuralı:** Pin atama, peripheral konfig, sürücü kurulumu gibi değişikliklerden **önce** ilgili datasheet/şematik görsel olarak incelenir (detay → [`docs/asama_0_altyapi.md`](docs/asama_0_altyapi.md)).

---

## 📄 Lisans ve Katkı

Bu proje **MIT lisansı** altındadır — bkz. [`LICENSE`](LICENSE). Akademik atıf için [`CITATION.cff`](CITATION.cff) (GitHub "Cite this repository" desteği).

**Proje bağlamı / katkı:** Bu depo, 3 kişilik bir bitirme tezi ekibinin parçası olarak geliştirdiğim firmware, sistem-tanımlama / kontrol tasarımı ve dokümantasyonu içerir.

**Danışman:** Dr. Öğr. Üyesi Kerem ALTUN
