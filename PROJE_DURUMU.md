# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik el kitabı → [`README.md`](README.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model ✅ → tek motor kontrol ✅ → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** ✅ **Aşama 1 KAPALI**, ✅ **Aşama 2 KAPALI** (2.1→2.9: hız PI + cascade + IMU mirror, tüm testler PASS; 2.9 akademik kapanış docs §11.15). → main'e merge edildi (`fc0aefc`) + `asama-2-kapali` tag ✅. **Sıradaki: Aşama 3 (MIMO).** Aşama 1: `K=53.89 rad/s/V, τ_median=60.5 ms, V_dead≈0, V_supply=12.15V`. Aşama 2.1: 5 kontrolcü tasarım. Aşama 2.2: firmware Tustin PI + anti-windup + MODE/SP_W komutları.

**Aşama 2.3 BÜYÜK BULGU (sim-to-real gap):** Conservative kazanç (Kp=0.1163) gerçek motorda **bang-bang limit cycle** verdi. Kök neden: 2.1'in İKİ analitik hatası — (H1) yanlış plant (K=53.89 yerine Kg=K·Vs=654.8, 12×), (H2) doyum kısıtı yok sayıldı (P-terimi e=4.3 rad/s'te doyar). **Analitik düzeltme: doyum-kısıtı (Kp≈duty_max/ω_max=0.002) + doğru-plant pole placement (ω_n=2/τ=33 → Ki=0.1), §11.12.3.** 2b: gerçekçi Simulink + ayrık margin (PM=40°) doğruladı. Test 2.T2 PASS (8/8 step).

**Aşama 2.4 (disturbance) ✅:** Baseline 101 rad/s (=setpoint, PI sıfır ss-error), elle yük ω'yı 56'ya itti (%44 dip), PI duty 0.186→0.50 telafi, setpoint'e döndü. Test 2.T4 PASS.

**Aşama 2.5+2.6 (pozisyon cascade) ✅ 2026-05-24:** Cascade (poz P Kp_pos=2.0 → hız PI) + çıkış mili açısı. Gerçekçi sim limit-cycle uyarısı verdi (sürtünmesiz → kötümser) + **5V sim parametre hatası yakalanıp düzeltildi** (sadece bu oturumun sim scriptlerinde; firmware/doküman/geçmiş test etkilenmedi). Firmware `MODE:POS` + `POS_DEG:`/`KPP:` + watchdog güvenlik düzeltmesi (kapalı-döngü modlarında artık etkili). **Test 2.5 gerçek motorda PASS — 6/6 segment, ss_err<0.8°, OS<1°, limit-cycle YOK (sürtünme simdeki gezinmeyi söndürdü).** Build PASS (Flash 8.0%).

**Aşama 2.6.5 (cascade Simulink + sürtünme) ✅:** `create_cascade_simulink.m` resmi cascade blok diyagramı (firmware-uyumlu model analitik Vsupply sadeleştirmesini ortaya çıkardı → iç ω_n~33, Kp_pos=2.0 ~16× ayrımla güvenli). `verify_realistic_cascade.m`'e Coulomb/stiction sürtünme (eşik Aşama 1 V_dead) eklendi → sürtünmeli sim θ_std=0° = gerçek Test 2.5 ile uyumlu → **sim-to-real gap kapandı** ([Ljung1999] §16). Detay: docs/asama_2_kontrol.md §11.13.7.

**Aktif branch:** `main` (Aşama 2 merge edildi, tag `asama-2-kapali`; Aşama 3 branch'i başlangıçta açılacak).

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması.
- ~~Stiction tartışması~~ ✅ ÇÖZÜLDÜ 2026-05-18 (reddedildi, analiz artefaktı).
- Gain scheduling — τ duty bağımlılığı (43-134 ms) Aşama 3'te değerlendirilecek.
- Encoder hız ölçümü kuantizasyon (18.7 rad/s) — cascade'de sürtünme söndürdüğü için sorun olmadı; gerekirse T-metodu/pencere büyütme kenarda referans.
- İzleme: 2.4'te motor tam durunca u=0.026 anomalisi (edge-case).

**Aşama 2.7/2.8 (IMU mirror) ✅ 2026-05-26:** MODE:MIRROR — motor fused_pitch'i takip eder (cascade). Kp_pos=6 **ANALİTİK** (deneme-yanılma değil): tip-1 hız hata sabiti Kv=Kp_pos, e_ss=ω_in/Kv, ω_in=30°/s, <5° → Kp_pos≥6 ([Franklin2010] §4.2). **Test 2.T6 PASS** — gimbal-hızı RMS 4.68° (Kp=5, analitik doğruladı); hızlı el (~80°/s) bant-genişliği limiti (~10°, beklenen). Detay: docs §11.13.8.

**Sıradaki:** **Aşama 3 — İki Motor MIMO Model.** main'den `feature/asama-3-mimo-model` branch'i açılacak: iki motor kuplajı + decoupling (RGA / condition number, `[Skogestad2005] §10`). ⚠ Aşama 2 kazançları serbest-mil için — Aşama 5'te gerçek gimbalda yük altında yeniden ayarlanacak.

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED + SpeedPI_Reset stall'da) aktif. Sigorta temin edilince duty cap gevşetilir.

**Akademik çıktılar:**
- Aşama 1: `matlab/asama_1_model/results/20260518_011926/` — 10 PNG + `motor_model_asama1.slx` + `motor_params.json` + `fit_report.md` · `20260518_dogrulama/` (bağımsız 2. tanımlama — reproducibility, docs §10.5)
- Aşama 2.1: `matlab/asama_2_kontrol/results/2_1_speed_pi/` — 3 PNG + `speed_loop_a2_1.slx` + `speed_pi_params.json` + `speed_pi_design_report.md`
- Aşama 2.5-2.6.5: `results/2_5_cascade/` (position_p_design + realistic_cascade + cascade_block_diagram + cascade_simulink_step + cascade_rootlocus + `cascade_pos_a2_5.slx` + position_p_params) · `results/2_3_realistic_sim/` (realistic_sim_verification); test `artifacts/2/position_step/20260524_212456/`. (Cascade vs direct-PID karşılaştırma scriptleri `sweep_position_strategy.m`/`design_position_direct_pid.m` korunur — eski `2_5_strategy/` çıktı dizini silindi, §11.13.)
- Teknik belgeler: [`docs/asama_1_model.md`](docs/asama_1_model.md) (Aşama 1) + [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md) (Aşama 2, pozisyon cascade dahil)
