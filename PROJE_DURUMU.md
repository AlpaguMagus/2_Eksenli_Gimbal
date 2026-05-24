# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik el kitabı → [`README.md`](README.md). Hocaya sunum kılavuzu → [`SUNUM.md`](SUNUM.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model ✅ → tek motor kontrol 🟡 → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** ✅ **Aşama 1 KAPALI**, 🟡 **Aşama 2 DEVAM** (2.1 + 2.2 + 2.3 ampirik çözüldü, 2b Simulink doğrulama sırada). Aşama 1: `K=53.89 rad/s/V, τ_median=60.5 ms, V_dead≈0`. Aşama 2.1: 5 kontrolcü → conservative (Kp=0.1163) seçildi. Aşama 2.2: firmware Tustin PI + anti-windup + MODE/SP_W komutları.

**Aşama 2.3 BÜYÜK BULGU (sim-to-real gap):** Conservative kazanç gerçek motorda **bang-bang limit cycle** verdi. Sistematik tanı (izolasyon + 5 kazanç + slew + setpoint + düşük-kazanç taramaları) → kök neden: Simulink ideal ölçüm/plant varsaydı, gerçekte serbest mil çok hızlı + encoder kuantize + Kp ~58× fazla yüksekti. **Ampirik çözüm: Kp=0.002, Ki=0.1 → motor temiz oturuyor (50/120/30 rad/s, hata %0).** Firmware: dt→DWT µs, Motor_SetDutySigned (rampasız PWM), Encoder_FilterSpeed (moving-avg), KP:/KI:/SLEW: runtime komutları. Build PASS (Flash 7.9%).

**Aktif branch:** `feature/asama-1-tek-motor-model` — push edildi (`9310367`).

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması.
- ~~Stiction tartışması (R6 açıklaması)~~ ✅ ÇÖZÜLDÜ 2026-05-18 (`artifacts/1/stiction_test/20260518_111200/`): Stiction hipotezi deneysel test ile reddedildi, R6 analiz artefaktı çıktı. Aşama 2 düşük setpoint riski yok.
- Gain scheduling — τ duty bağımlılığı (43-134 ms) için Aşama 2.3 testi sonrası değerlendirilecek.

**Sıradaki:** Aşama 2b — Simulink'e kuantizasyon + ölçüm gecikmesi + serbest mil + saturation ekleyip ampirik Kp=0.002'yi teorik doğrula. Sonra programatik `scripts/speed_step_test.py` resmi step response metrikleri.

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED + SpeedPI_Reset stall'da) aktif. Sigorta temin edilince duty cap gevşetilir.

**Akademik çıktılar:**
- Aşama 1: `matlab/asama_1_model/results/20260518_011926/` — 10 PNG + `motor_model_asama1.slx` + `motor_params.json` + `fit_report.md`
- Aşama 2.1: `matlab/asama_2_kontrol/results/a2_1_20260518_071843/` — 3 PNG + `speed_loop_a2_1.slx` + `speed_pi_params.json` + `speed_pi_design_report.md`
- README §10 (Aşama 1 el kitapçığı, 9 alt başlık) + §11 (Aşama 2 el kitapçığı, 11 alt başlık)
- SUNUM.md — hocaya sunum kılavuzu (sıra + vurgu + Q&A)
