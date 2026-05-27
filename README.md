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
| **2 — Tek Motor Kontrol** | ✅ KAPALI | Hız PI + sim-to-real gap + disturbance + pozisyon cascade + IMU mirror — **tüm testler PASS** (2.T2/T4/T5/T6) |
| 3 — MIMO Model | ⬜ | İki motor + decoupling |
| 4 — MIMO Kontrol | ⬜ | LQR/LQG + Kalman |
| 5 — Gerçek Gimbal | ⬜ | 3D-baskı + stabilizasyon |

**En son (2026-05-27):** **Aşama 2 KAPALI** — IMU mirror takip (motor IMU pitch'ini izler) Test 2.T6 PASS (gimbal-hızı RMS 4.68°, Kp_pos analitik Kv tasarımı). Aşama 2 tüm kontrol omurgası (hız PI → cascade → mirror) gerçek motorda doğrulandı. Sırada **Aşama 3 — MIMO model**. Detay → [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md) §11.15 (kapanış sentezi). Güncel durum → [`PROJE_DURUMU.md`](PROJE_DURUMU.md).

---

## 🗺 Dokümantasyon Haritası

Her belge tek bir soruyu, tek bir okuyucu kitlesine cevaplar:

| Belge | Cevapladığı soru | Okuyucu |
|---|---|---|
| **README.md** (bu dosya) | Proje ne, nasıl çalıştırılır, nereye bakılır? | İlk gelen / GitHub |
| [`docs/00_genel_bakis.md`](docs/00_genel_bakis.md) | Vizyon + **ortak kontrol teorisi primer'i** (transfer fn, kararlılık, Bode, tip sistem)? | Jüri / yeni başlayan |
| [`docs/asama_0_altyapi.md`](docs/asama_0_altyapi.md) | Donanım, firmware, IMU füzyonu, USB, motor/encoder **nasıl** kuruldu? | Geliştirici |
| [`docs/asama_1_model.md`](docs/asama_1_model.md) | Motor modeli (K, τ) **nasıl/neden** çıkarıldı, **sonuç** ne? | Jüri (akademik) |
| [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md) | Kontrolcü **neden** öyle tasarlandı, **alternatifler**, **sonuç**? | Jüri (akademik) |
| [`ROADMAP.md`](ROADMAP.md) | **Ne planlanıyor**, açık sorular, test iskeleti? | Geliştirici / danışman |
| [`PROJE_DURUMU.md`](PROJE_DURUMU.md) | **Şu an neredeyiz**, en son ne yapıldı? | Gelecek-ben / danışman |
| [`KAYNAKCA.md`](KAYNAKCA.md) | Hangi **literatüre** dayanıyor? (etiketli bibliyografya) | Akademik denetim |
| [`matlab/README.md`](matlab/README.md) | MATLAB tasarım scriptleri nasıl çalışır? | MATLAB kullanıcısı |
| [`CLAUDE.md`](CLAUDE.md) | Geliştirme/dokümantasyon standartları nedir? | Katkı veren |

**İzlenebilirlik ilkesi:** Her teknik karar `[Kaynak]` etiketli ([`KAYNAKCA.md`](KAYNAKCA.md)), her deney sonucu [`artifacts/`](artifacts/)'ta kanıtlı (summary.md + meta.json + ham veri + grafik).

---

## ⚙ Sistem Mimarisi

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

**Bare-metal süper-loop:** RTOS yok. Ana döngü `sensör oku → filtrele → kontrol → USB I/O → tekrarla` (~200 Hz). Düşük gecikme, deterministik zamanlama. Mimari detay → [`docs/00_genel_bakis.md`](docs/00_genel_bakis.md).

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

Komut seti detayı → [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md).

---

## 📂 Repo Yapısı

```
2_Eksenli_Gimbal/
├── README.md                 ← Bu dosya (vitrin)
├── docs/                     ← Aşama-bazlı teknik/akademik belgeler
│   ├── 00_genel_bakis.md     ← Vizyon + ortak kontrol teorisi primer'i (denklem/diyagram)
│   ├── asama_0_altyapi.md    ← Donanım, firmware, IMU, filter, USB, motor/encoder
│   ├── asama_1_model.md      ← Sistem tanımlama (K, τ, dead-band)
│   └── asama_2_kontrol.md    ← Hız PI, sim-to-real, disturbance, pozisyon cascade
├── src/                      ← Firmware kaynak
│   ├── main.c                ← Ana döngü: init, sensör, filter, kontrol, USB
│   ├── motor.c               ← TB6612 sürücü API
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
├── matlab/                   ← MATLAB tasarım/analiz (toolbox tabanlı)
│   ├── asama_1_model/        ← Sistem tanımlama pipeline
│   └── asama_2_kontrol/      ← Kontrolcü tasarım + gerçekçi sim
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
- Yerel datasheet'ler: [`datasheets/`](datasheets/) — STM32F411, MPU6050, TB6612FNG, Pololu 25D motor

**Donanım kuralı:** Pin atama, peripheral konfig, sürücü kurulumu gibi değişikliklerden **önce** ilgili datasheet/şematik görsel olarak incelenir (detay → [`docs/asama_0_altyapi.md`](docs/asama_0_altyapi.md)).
