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
| 2.3 Sim-to-real gap | Gerçekçi sim (kuantizasyon) → ampirik Kp=0.002 doğrulandı | `[Ljung1999] §16` |
| 2.5 Pozisyon cascade | Pozisyon P, iç döngünün 1/5 hızında (Kp_pos=2.0) | `[Franklin2010] §6.4, §4.3` |
| 2.6.5 Simulink + sürtünme | Cascade blok diyagramı + Coulomb/stiction (gap kapandı) | `[Franklin2010] §6.4`, `[Ljung1999] §16` |
| 2.7 IMU mirror | Setpoint = +fused_pitch | proje konsepti |

## Klasör Yapısı (konu-bazlı `results/`)

```
matlab/asama_2_kontrol/
├── README.md                           ← Bu dosya
├── load_motor_params.m                  ← Aşama 1 JSON yükleyici
│   ── Aşama 2.1 hız PI tasarımı ──
├── design_speed_pi_pole_placement.m     ← analitik (pole placement)
├── design_speed_pi_autotune.m           ← pidtune (Robust/Balanced/Fast)
├── compare_speed_pi.m                   ← Bode + step + margins (5 kontrolcü)
├── create_speed_loop_simulink.m         ← hız döngüsü Simulink (programatik)
├── run_pipeline_2_1.m                   ← 2.1 orchestrator
│   ── Aşama 2.3 sim-to-real ──
├── verify_realistic_sim.m               ← gerçekçi hız sim (ampirik kazanç doğrulama)
│   ── Aşama 2.5 pozisyon cascade ──
├── design_position_p.m                  ← pozisyon P (Kp_pos=2.0)
├── sweep_position_strategy.m            ← cascade vs doğrudan PD taraması
├── design_position_direct_pid.m         ← doğrudan PID alternatifi (karşılaştırma)
│   ── Aşama 2.6.5 Simulink + sürtünme ──
├── create_cascade_simulink.m            ← cascade Simulink blok diyagramı
├── verify_realistic_cascade.m           ← sürtünmesiz vs sürtünmeli (gap kapandı)
└── results/                             ← konu-bazlı çıktılar
    ├── 2_1_speed_pi/      (bode, step, metrics, speed_loop_a2_1.slx, params, report)
    ├── 2_3_realistic_sim/ (realistic_sim_verification.png)
    ├── 2_5_cascade/       (position_p_design, realistic_cascade, cascade_block_diagram,
    │                       cascade_simulink_step, cascade_pos_a2_5.slx, position_p_params)
    └── 2_5_strategy/      (position_strategy_sweep, position_direct_pid)
```

> **Not:** `.png`/`.slx` git'te (görsel + model kanıtı), `.mat` git dışı (gitignored).
> Aşama 1 `results/<test_id>/` (tarihli) yapısını kullanır — orada iki çalıştırma
> (orijinal + doğrulama) reproducibility kanıtıdır; Aşama 2 konu-bazlıdır.

## Firmware'e Transfer (manuel, kaynak yorumuyla)

MATLAB çıktıları firmware'e **manuel** aktarılır (Embedded Coder yok). Gerçek değerler:

```c
/* Hız PI — AMPIRIK (Aşama 2.3, gerçek motorda doğrulandı; 2.1 conservative
 * Kp=0.1163 gerçekte bang-bang verdi → sim-to-real gap, docs §11.12).
 * Kaynak: [AstromMurray2008] §10.2 (Tustin), §10.4 (back-calc) */
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
python3 scripts/disturbance_test.py        # 2.4 disturbance (Test 2.T4)
python3 scripts/position_step_test.py      # 2.5 pozisyon cascade (Test 2.5)
# Artifact: artifacts/2/<test>/<test_id>/ (summary.md + meta.json + raw + plot)
```

## Akademik Çıktı

- `results/2_*/` — Bode/step/metrics PNG, Simulink `.slx`, JSON parametreler, raporlar
- [`../../docs/asama_2_kontrol.md`](../../docs/asama_2_kontrol.md) — Aşama 2 ders-kitabı
  bölümü (sokratik kararlar + sayısal sonuçlar + görsel kanıtlar + akademik tartışma)
