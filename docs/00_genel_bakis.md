# Genel Bakış — Vizyon, Sistem Mimarisi, Ortak Teori

> **Ekosistem:** Bu belge projenin üst-düzey vizyonunu, sistem mimarisini ve aşamalar-arası ortak temeli açıklar. Aşama belgeleri: [`asama_0_altyapi.md`](asama_0_altyapi.md) · [`asama_1_model.md`](asama_1_model.md) · [`asama_2_kontrol.md`](asama_2_kontrol.md). Proje vitrini → [`../README.md`](../README.md). Plan → [`../ROADMAP.md`](../ROADMAP.md). Durum → [`../PROJE_DURUMU.md`](../PROJE_DURUMU.md).

## Uzun Vadeli Vizyon

Bu proje **5 aşamalı kontrol mühendisliği yol haritası** üzerinden iki eksenli kamera gimbal'ına ulaşır:

| Aşama | Hedef | MATLAB klasörü | Belge |
|---|---|---|---|
| **0 ✅** | Donanım entegrasyonu, koruma katmanları, USB CDC | — | [`asama_0_altyapi.md`](asama_0_altyapi.md) |
| **1 ✅** | Tek motor sistem tanımlama (K, τ, dead-band) | `matlab/asama_1_model/` | [`asama_1_model.md`](asama_1_model.md) |
| **2 🟡** | Tek motor PI/PID/cascade + IMU mirror | `matlab/asama_2_kontrol/` | [`asama_2_kontrol.md`](asama_2_kontrol.md) |
| **3** | İki motor MIMO + decoupling | `matlab/asama_3_mimo_model/` | (gelecek) |
| **4** | İki motor LQR/LQG + Kalman | `matlab/asama_4_mimo_kontrol/` | (gelecek) |
| **5** | Gerçek 3D-print gimbal — stabilizasyon | `matlab/asama_5_gimbal/` | (gelecek) |

**Felsefe:** Her teknik karar **kaynaklı** ([`../KAYNAKCA.md`](../KAYNAKCA.md) etiketli). Embedded Coder kullanılmaz; MATLAB çıktıları (kazançlar, eşikler) **manuel** olarak firmware'e transfer edilir, kaynak yorumu eşliğinde.

---

## 1. Sistem Mimarisi

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
                    │   matplotlib ile      │
                    │   gerçek zamanlı      │
                    │   görselleştirme      │
                    └───────────────────────┘
```

Sistem, işletim sistemi (RTOS) kullanmayan **bare-metal** bir gömülü yazılım mimarisi üzerine kuruludur. Ana döngü (`while(1)`) super-loop modeli ile çalışır: sensör oku → filtrele → USB'den gönder → tekrarla. Bu yaklaşım, düşük gecikme (latency) ve deterministik zamanlama sağlar.

---

