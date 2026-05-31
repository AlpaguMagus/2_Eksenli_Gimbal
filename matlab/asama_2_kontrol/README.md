# Aşama 2 — Tek Motor Kontrol (MATLAB tasarım/analiz)

> **Amaç:** Aşama 1 motor modeliyle (K=53.89 rad/s/V, τ=60.5 ms, V_supply=12.15V)
> hız iç döngü PI + pozisyon dış döngü P (cascade) tasarla, gerçekçi simülasyonla
> doğrula, firmware'e aktar. Derin akademik anlatı → [`../../docs/asama_2_kontrol.md`](../../docs/asama_2_kontrol.md).

---

## Plan ve Kaynak

| Adım | Yöntem | Kaynak |
|---|---|---|
| 2.1 Hız PI tasarımı | Pole placement + `pidtune` karşılaştırma (5 kontrolcü) | `[Franklin2010] §6.4` |
| 2.2 Firmware hız PI | Bilinear (Tustin) ayrıştırma, Ts=5 ms | `[AstromMurray2008] §10.2` |
| 2.3 Analitik düzeltme + sim-to-real | Doyum-kısıtı + doğru-plant pole placement → Kp=0.002, Ki=0.1; gerçekçi sim (kuantizasyon) doğruladı | `[Franklin2010] §6.4`, `[Ljung1999] §16` |
| 2.3 Kararlılık marjı | `margin` (sürekli) + ZOH/MA ayrık-zaman PM (C1/C2 kaveatı) | `[AstromMurray2008] §10`, `[Ljung1999] §16` |
| 2.4 Anti-windup + disturbance | Back-calculation recovery (sim + gerçek), disturbance bloğu | `[AstromMurray2008] §10.4` |
| 2.5 Pozisyon cascade | Pozisyon P, iç döngünün 1/5 hızında (Kp_pos=2.0); root locus doğrulama | `[Franklin2010] §6.4, §4.3` |
| 2.6.5 Simulink + sürtünme | Cascade blok diyagramı + Coulomb/stiction (gap kapandı) | `[Franklin2010] §6.4`, `[Ljung1999] §16` |
| 2.7 IMU mirror | Canlı takip, Kp_pos=6 (Kv hız hata sabiti) | `[Franklin2010] §4.2` |

## Klasör Yapısı (konu-bazlı `results/`)

```
matlab/asama_2_kontrol/
├── README.md                           ← Bu dosya
├── load_motor_params.m                  ← Aşama 1 JSON yükleyici (tüm design_*/verify_* çağırır)
│   ── Aşama 2.1 hız PI tasarımı ──
├── design_speed_pi_pole_placement.m     ← analitik (pole placement formülü)
├── design_speed_pi_autotune.m           ← pidtune (Robust/Balanced/Fast) doğrulama
├── compare_speed_pi.m                   ← Bode + step + margins (5 kontrolcü)
├── create_speed_loop_simulink.m         ← hız döngüsü Simulink (programatik)
├── run_pipeline_2_1.m                   ← 2.1 orchestrator
│   ── Aşama 2.3 analitik düzeltme + sim-to-real + margin ──
├── design_speed_pi_corrected.m          ← ★ çalışan kazancın ANALİTİK temeli (doyum-kısıtı + doğru-plant, §11.12.3)
├── verify_realistic_sim.m               ← gerçekçi hız sim (analitik kazancı doğrular)
├── design_speed_margin_empirical.m      ← çalışan vs conservative kararlılık marjı (sim-to-real kök-neden)
├── verify_speed_margin_discrete.m       ← ayrık-zaman (ZOH+MA) PM — C1/C2 kaveatı (§11.12.8)
│   ── Aşama 2.T3 anti-windup ──
├── verify_antiwindup.m                  ← sim anti-windup recovery (back-calc 235/715 ms)
├── plot_antiwindup_real.m               ← gerçek-motor anti-windup görseli (CSV→PNG)
│   ── Aşama 2.5 pozisyon cascade ──
├── design_position_p.m                  ← pozisyon P (Kp_pos=2.0)
├── design_position_rootlocus.m          ← cascade dış döngü root locus DOĞRULAMA (analitik-önce)
├── create_control_diagrams.m            ← kapalı-çevrim blok diyagramları (4 adet)
├── sweep_position_strategy.m            ← cascade vs PD taraması (arşiv — karar kaydı, docs §11.13.2)
├── design_position_direct_pid.m         ← doğrudan PID alternatifi (arşiv — karar kaydı)
│   ── Aşama 2.6.5 Simulink + sürtünme ──
├── create_cascade_simulink.m            ← cascade Simulink blok diyagramı
├── verify_realistic_cascade.m           ← sürtünmesiz vs sürtünmeli (gap kapandı)
│   ── Aşama 2.7 IMU mirror ──
├── design_mirror_tracking.m             ← mirror Kp_pos analitik (Kv hız hata sabiti)
└── results/                             ← konu-bazlı çıktılar (PNG/SLX/JSON git'te)
    ├── 2_1_speed_pi/      (bode, step, metrics, blockdiagram, margin emp+discrete,
    │                       analytic_derivation, speed_loop.slx, params, report)
    ├── 2_3_realistic_sim/ (realistic_sim_verification, antiwindup recovery + real)
    ├── 2_4_disturbance/   (disturbance_block.png)
    ├── 2_5_cascade/       (position_p_design, rootlocus, textbook + block diagram,
    │                       realistic_cascade, cascade_step, cascade_pos.slx, params)
    └── 2_7_mirror/        (mirror_blockdiagram, mirror_tracking_design, params)
```

> **Not:** `.png`/`.slx` git'te (görsel + model kanıtı; `.slx` `create_*_simulink.m` ile
> **programatik üretilir** → el-yazımı kaynak değil, üretilen çıktıdır, bu yüzden `results/`'ta —
> tıpkı PNG gibi), `.mat` git dışı (gitignored).
> (Direct-PID alternatifi `2_5_strategy/` Aşama 2.5'te terk edildi — cascade seçildi; üreten
> scriptler `sweep_position_strategy.m` + `design_position_direct_pid.m` kaynakta korunur, docs §11.13.)
> Aşama 1 `results/<test_id>/` (tarihli) yapısını kullanır — orada iki çalıştırma
> (orijinal + doğrulama) reproducibility kanıtıdır; Aşama 2 konu-bazlıdır.

## Firmware'e Transfer (manuel, kaynak yorumuyla)

MATLAB çıktıları firmware'e **manuel** aktarılır (Embedded Coder yok). Gerçek değerler:

```c
/* Hız PI — ANALİTİK (doyum-kısıtı + doğru-plant pole placement, docs §11.12.3).
 * Dürüst kronoloji: 2.3'te donanım taramasıyla bulundu, analitik çerçeve sonradan
 * formalize etti (deney üretmedi, doğruladı). 2.1 conservative Kp=0.1163 iki analitik
 * hatadan (yanlış plant 12× + doyum yok sayıldı) bang-bang verdi → sim-to-real gap, docs §11.12.
 * Kaynak: [Franklin2010] §6.4 (pole placement), [AstromMurray2008] §10.2 (Tustin), §10.4 (back-calc) */
.Kp = 0.002f,  .Ki = 0.1f,  .Ts = 0.005f,  .T_t = 0.02f;

/* Pozisyon P — GÖREVE ÖZEL kazanç (cmd_parser MODE geçişinde set):
 *   MODE:POS  step  → Kp_pos=2.0 (cascade ω_c=ω_n_iç/5, overshootsuz) [Franklin2010 §6.4/§4.3]
 *   MODE:MIRROR takip→ Kp_pos=6.0 (Kv hız hata sabiti, e_ss=ω_in/Kv) [Franklin2010 §4.2]
 * ω_ref_motor = Kp_pos·(θ_ref−θ_out)·9.7 (redüktör) */
```

## Test Akışı

```bash
pio run -t upload                          # firmware flash
python3 scripts/speed_step_test.py         # 2.3 hız step (Test 2.T2)
python3 scripts/antiwindup_test.py         # 2.T3 anti-windup recovery
python3 scripts/disturbance_test.py        # 2.4 disturbance (Test 2.T4)
python3 scripts/position_step_test.py      # 2.5 pozisyon cascade (Test 2.5)
python3 scripts/mirror_test.py             # 2.7 IMU mirror takip (Test 2.T6)
# Artifact: artifacts/2/<test>/<test_id>/ (summary.md + meta.json + raw + plot)
```

## Akademik Çıktı

- `results/2_*/` — Bode/step/metrics PNG, Simulink `.slx`, JSON parametreler, raporlar
- [`../../docs/asama_2_kontrol.md`](../../docs/asama_2_kontrol.md) — Aşama 2 ders-kitabı
  bölümü (sokratik kararlar + sayısal sonuçlar + görsel kanıtlar + akademik tartışma)
