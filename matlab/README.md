# MATLAB Çalışma Alanı

> Sistem tanımlama, kontrolcü tasarımı, Kalman filter tasarımı, Simulink simülasyonu.
> Firmware C/STM32Cube HAL ile devam ediyor — **Embedded Coder kullanılmıyor**.
> MATLAB çıktıları (kazançlar, eşikler, katsayılar) manuel olarak firmware'e transfer edilir.

---

## Klasör Yapısı

Her aşamanın kendi alt klasörü vardır:

```
matlab/
├── README.md                   ← Bu dosya
├── 00_genel_teori/             ← Aşamalar-arası teori primer'i görselleri (00_genel_bakis)
├── asama_0_altyapi/            ← Aşama 0: IMU Allan variance + complementary filter
├── asama_1_model/              ← Aşama 1: tek motor sistem tanımlama
├── asama_2_kontrol/            ← Aşama 2: tek motor kontrol (PI, cascade, mirror)
├── asama_3_mimo_model/         ← Aşama 3: iki motor MIMO modelleme (AKTİF; HP eksen-0 cascade karakterizasyon + yüklü-FF bench dahil) + K2/K3/K4 ön-tasarım
├── asama_4_mimo_kontrol/       ← Aşama 4: MIMO kontrolcü — 📐 K6 LQR/LQI tek-eksen ÖN-TASARIM (donanımsız)
└── asama_5_gimbal/             ← Aşama 5: gerçek gimbal — 📐 K7 Kalman attitude tek-eksen ÖN-TASARIM (donanımsız)
```

> Her aşama klasörünün kendi `README.md`'si script listesini + `results/` yapısını tutar.
> `asama_4`/`asama_5` **donanımsız ön-tasarımlarla oluşturuldu** (2026-06-13, merdiven K6/K7 — `docs §12.7`);
> bench-validasyon + 2-eksen/payload işi ilgili aşama açılınca eklenir (eklemeli sözleşme). Ortak
> utility (`ortak/`) henüz yok.

## Toolbox Bağımlılıkları

| Toolbox | Kullanım |
|---|---|
| Control System Toolbox | Transfer function, state-space, root locus, bode |
| System Identification Toolbox | `tfest`, `procest`, `iddata` ile parametrik fit |
| Simulink | Closed-loop simülasyon, gerçek-zamanlı doğrulama |
| Optimization Toolbox | `lsqcurvefit`, constrained fitting |
| Signal Processing Toolbox | Filtreleme, FFT, gürültü analizi |

`mcp__matlab__detect_matlab_toolboxes` ile yüklü olanlar kontrol edilir.

## Veri Akışı

```
artifacts/<aşama>/<test_id>/raw/*.csv.gz
                  │
                  ▼
        MATLAB load script (.m)
                  │
                  ▼
          iddata / table
                  │
        ┌─────────┼──────────┐
        ▼         ▼          ▼
       fit    validate   visualize
        │         │          │
        └─────────┴──────────┘
                  │
                  ▼
     matlab/<aşama>/results/
       ├── parameters.json    ← firmware için
       ├── *.png              ← görsel (git'te)
       └── *.mat              ← workspace (git dışı)
                  │
                  ▼
        firmware C kod
        (manuel transfer +
         kaynak yorumu)
```

## Versiyonlama Kuralları

`.gitignore` (root):
```
*.mat       # Workspace binary — yeniden üretilebilir
*.fig       # Figure binary — yerine PNG export
*.asv       # MATLAB autosave
*.m~        # MATLAB backup
slprj/      # Simulink build cache
```

Git'te tutulanlar:
- `*.m` script dosyaları
- `*.slx` Simulink modelleri (binary ama tasarım dosyası)
- `*.png`, `*.svg` export'lar (görsel kanıt)
- `*.json` üretilen parametre dosyaları (firmware tarafında okunabilir)
- `README.md` aşama açıklamaları

## Kullanım

MATLAB MCP üzerinden çağrılır:
```
mcp__matlab__run_matlab_file → matlab/asama_1_model/fit_first_order.m
mcp__matlab__evaluate_matlab_code → inline analiz
```

Veya GUI'den: MATLAB desktop görünür, kullanıcı script'i kendi açar.

## Akademik Kaynak Bağlantısı

Her .m script başında `KAYNAKCA.md` etiketi yorum olarak:

```matlab
%% Tek motor 1. derece + dead-band fit
% Referans:
%   [Ljung1999] §3   — parametrik model yapıları
%   [Ljung1999] §16  — model validation
%   [Franklin2010] §3 — dinamik model çıkarımı
%
% Girdi:  artifacts/1/step_response/raw/*.csv.gz
% Çıktı:  matlab/asama_1_model/results/motor_params.json

clear; close all; clc;
...
```

Firmware'e değer transfer edilirken kaynak C yorumuna kopyalanır:

```c
/* Hız PI kazançları — matlab/asama_2_kontrol/design_speed_pi_corrected.m'den (analitik:
 *   doyum-kısıtı Kp≈duty_max/ω_max + doğru-plant pole placement ω_n=2/τ, docs §11.11.3):
 *   Kp = 0.002f, Ki = 0.1f, T_t = K_p/K_i = 0.02f
 * Anti-windup back-calculation [AstromMurray2008 §10.4] */
.Kp = 0.002f, .Ki = 0.1f, .T_t = 0.02f;
```

> Yukarısı **gerçek firmware bloğuyla hizalıdır** (`src/main.c` SPEED_PI_CFG); şablon değil,
> çalışan değerlerdir.
