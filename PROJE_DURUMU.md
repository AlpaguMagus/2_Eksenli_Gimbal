# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik el kitabı → [`README.md`](README.md). Hocaya sunum kılavuzu → [`SUNUM.md`](SUNUM.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model ✅ → tek motor kontrol 🟡 → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** ✅ **Aşama 1 KAPALI**, 🟡 **Aşama 2 DEVAM** (2.1 + 2.2 tamamlandı, 2.3 testi sırada). Aşama 1 sonuçları: `K=53.89 rad/s/V, τ_median=60.5 ms, V_dead≈0, validation NRMSE %11.11`. Aşama 2.1: 5 kontrolcü karşılaştırma → `pole_placement_conservative` seçildi (Kp=0.1163, Ki=4.0447, ζ=1.0, ω_n=60). Aşama 2.2: firmware'de Tustin discretization + anti-windup back-calculation + MODE:DUTY/SP_W komut altyapısı; build PASS (RAM 3.6%, Flash 7.8%).

**Aktif branch:** `feature/asama-1-tek-motor-model` — push edildi (`9310367`).

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması.
- Stiction tartışması (R6 açıklaması) — Aşama 2.3 testinde düşük setpoint davranışı izlenecek, gerekirse gain scheduling eklenir.

**Sıradaki:** Aşama 2.3 — `scripts/speed_step_test.py` ile firmware hız PI step response testi (24 step, settling/overshoot/ss_error ölçüm).

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED + SpeedPI_Reset stall'da) aktif. Sigorta temin edilince duty cap gevşetilir.

**Akademik çıktılar:**
- Aşama 1: `matlab/asama_1_model/results/20260518_011926/` — 10 PNG + `motor_model_asama1.slx` + `motor_params.json` + `fit_report.md`
- Aşama 2.1: `matlab/asama_2_kontrol/results/a2_1_20260518_071843/` — 3 PNG + `speed_loop_a2_1.slx` + `speed_pi_params.json` + `speed_pi_design_report.md`
- README §10 (Aşama 1 el kitapçığı, 9 alt başlık) + §11 (Aşama 2 el kitapçığı, 11 alt başlık)
- SUNUM.md — hocaya sunum kılavuzu (sıra + vurgu + Q&A)
