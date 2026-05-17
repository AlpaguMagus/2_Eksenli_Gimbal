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
├── asama_1_model/              ← Aşama 1: tek motor sistem tanımlama
│   ├── README.md
│   ├── load_step_data.m        ← artifacts/'tan CSV oku
│   ├── fit_first_order.m       ← 1. derece + dead-band fit
│   ├── validate_model.m        ← model vs ölçüm karşılaştırma
│   └── results/                ← üretilen PNG, .json (git'te)
├── asama_2_kontrol/            ← Aşama 2: tek motor kontrol (PI, cascade)
├── asama_3_mimo_model/         ← Aşama 3: iki motor MIMO modelleme
├── asama_4_mimo_kontrol/       ← Aşama 4: MIMO kontrolcü (decoupling, LQR)
├── asama_5_gimbal/             ← Aşama 5: gerçek 3D-print gimbal entegrasyon
└── ortak/                      ← Aşamalar arası ortak utility
    ├── plot_utils.m
    └── data_loader.m
```

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
/* PI hız kazançları — matlab/asama_2_kontrol/cascade_pi.m §2'den:
 *   τ_cl = τ_ol / 5     [Franklin2010 §6.4]
 *   Kp = 0.42, Ki = 12.3
 * Anti-windup back-calculation [AstromMurray2008 §10.4] */
```
