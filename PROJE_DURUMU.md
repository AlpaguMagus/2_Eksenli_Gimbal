# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik el kitabı → [`README.md`](README.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model ✅ → tek motor kontrol 🟡 → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** ✅ **Aşama 1 KAPALI**, 🟡 **Aşama 2 DEVAM** (2.1→2.6 tamam, kalan 2.7 IMU mirror). Aşama 1: `K=53.89 rad/s/V, τ_median=60.5 ms, V_dead≈0, V_supply=12.15V`. Aşama 2.1: 5 kontrolcü tasarım. Aşama 2.2: firmware Tustin PI + anti-windup + MODE/SP_W komutları.

**Aşama 2.3 BÜYÜK BULGU (sim-to-real gap):** Conservative kazanç (Kp=0.1163) gerçek motorda **bang-bang limit cycle** verdi. Sistematik tanı → kök neden: ideal ölçüm varsayımı + serbest mil hızlı + encoder kuantize. **Ampirik çözüm: Kp=0.002, Ki=0.1.** 2b: gerçekçi Simulink teorik doğruladı. Test 2.T2 PASS (8/8 step).

**Aşama 2.4 (disturbance) ✅:** Elle yük → ω %82 düştü, PI duty 0.18→0.5 telafi, setpoint'e döndü. Test 2.T4 PASS.

**Aşama 2.5+2.6 (pozisyon cascade) ✅ 2026-05-24:** Cascade (poz P Kp_pos=2.0 → hız PI) + çıkış mili açısı. Gerçekçi sim limit-cycle uyarısı verdi (sürtünmesiz → kötümser) + **5V sim parametre hatası yakalanıp düzeltildi** (sadece bu oturumun sim scriptlerinde; firmware/doküman/geçmiş test etkilenmedi). Firmware `MODE:POS` + `POS_DEG:`/`KPP:` + watchdog güvenlik düzeltmesi (kapalı-döngü modlarında artık etkili). **Test 2.5 gerçek motorda PASS — 6/6 segment, ss_err<0.8°, OS<1°, limit-cycle YOK (sürtünme simdeki gezinmeyi söndürdü).** Build PASS (Flash 8.0%).

**Aktif branch:** `feature/asama-1-tek-motor-model`.

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması.
- ~~Stiction tartışması~~ ✅ ÇÖZÜLDÜ 2026-05-18 (reddedildi, analiz artefaktı).
- Gain scheduling — τ duty bağımlılığı (43-134 ms) Aşama 3'te değerlendirilecek.
- Encoder hız ölçümü kuantizasyon (18.7 rad/s) — cascade'de sürtünme söndürdüğü için sorun olmadı; gerekirse T-metodu/pencere büyütme kenarda referans.
- İzleme: 2.4'te motor tam durunca u=0.026 anomalisi (edge-case).

**Sıradaki:** Aşama 2.7 — IMU mirror (setpoint = +fused_pitch, motor IMU pitch'ini takip eder) → 2.8 mirror tracking testi → 2.9 akademik rapor.

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED + SpeedPI_Reset stall'da) aktif. Sigorta temin edilince duty cap gevşetilir.

**Akademik çıktılar:**
- Aşama 1: `matlab/asama_1_model/results/20260518_011926/` — 10 PNG + `motor_model_asama1.slx` + `motor_params.json` + `fit_report.md`
- Aşama 2.1: `matlab/asama_2_kontrol/results/a2_1_20260518_071843/` — 3 PNG + `speed_loop_a2_1.slx` + `speed_pi_params.json` + `speed_pi_design_report.md`
- Aşama 2.5: `matlab/asama_2_kontrol/results/` — `position_p_design.png` + `realistic_cascade.png` + `position_strategy_sweep.png` + `position_p_params.json`; test `artifacts/2/position_step/20260524_212456/`
- README §10 (Aşama 1, 9 alt başlık) + §11 (Aşama 2, §11.13 pozisyon cascade dahil)
