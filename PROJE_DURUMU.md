# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik el kitabı → [`README.md`](README.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model ✅ → tek motor kontrol ✅ → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** 🟡 **Aşama 3 (MIMO) AÇIK** (`feature/asama-3-mimo-model`, 2026-06-09). **3.1 pin planı ✅ onaylı + kablolama tamam; 3.2a encoder-2 bench PASS** (`artifacts/3/enc2_test/`); IMU kendini-iyileştirme firmware. **3.2b ✅ PASS** (motor-2 ±0.30'da +1203/−1199 count/s, polarite AYNI → cascade işaret çevirme YOK). **3.3 eksen-mimarisi firmware ✅** (2026-06-11, `9def197`): instance-based refactor — `g_axis[2]`, cascade/MIRROR **eksen-1'de (motor-2) bugün kullanılabilir** (`MODE2:`/`POS_DEG2:`/`KPP2:`…), motor-2 stall kazandı, telemetri +`OMEGA2/SP2/TR2` (eski script'ler korunur); 21-ajan adversarial davranış-denetimi geçti (3 gerçek fark → 2 düzeltildi, 1 bilinçli kabul). **⚠ Motor-1 ünitesi kurtarılamaz** (CW sert mekanik catch — motor-içi; tork 0.8'e kadar + gearbox-çıkarma + dislodge denendi, çözmedi; CCW kusursuz). **Karar (2026-06-11): redüktörsüz yedek siparişte** (sağlam gearbox ona takılacak); gelene kadar **proje tek sağlam motor (motor-2 ekseni) üzerinden tamamlanır**, yeni motor tak-çalıştır entegre. **3.3 bench tamamlandı (2026-06-12, tek sağlam motor=motor-2):** `MODE2:POS` cascade 6/6 PASS (ss_err<1°, Test 2.5 ile birebir); `MODE2:MIRROR` takip RMS 5.53°; **`MODE2:STAB` stabilizasyon — motor IMU eğimine TERS döndü (yasa demoland), RMS 6.72°.** IMU uyku sorunu jumper bağlantıyla çözüldü + firmware sertleştirildi (uyku auto-wake + non-blocking init, `94a36e3`). ⚠ Tam eylemsiz stabilizasyon doğrulaması IMU payload'a taşınınca = Aşama 5. **Sıradaki: yeni motor (redüktörsüz, siparişte) gelince eksen-0 entegrasyon → 3.4 MIMO ID** (iki sağlam eksen). Aşama-2-sonrası paket main'de (`512e796`): mirror Kp_pos=6 gerçek 4.02°, amper bütçesi datasheet denetimi (3A yeterli, dar boğaz=sürücü), **count-tabanlı stall fix bench PASS** (yanlış-pozitif 0, oto-devam ~1 sn — 2A.T5-B kapandı), IMUDIAG/IMUINIT teşhis komutları. Önceki: ✅ Aşama 1+2 KAPALI (`asama-2-kapali` tag). Aşama 1: `K=53.89 rad/s/V, τ_median=60.5 ms, V_dead≈0, V_supply=12.15V`. Aşama 2.1: 5 kontrolcü tasarım. Aşama 2.2: firmware Tustin PI + anti-windup + MODE/SP_W komutları.

**Aşama 2.3 BÜYÜK BULGU (sim-to-real gap):** Conservative kazanç (Kp=0.1163) gerçek motorda **bang-bang limit cycle** verdi. Kök neden: 2.1'in İKİ analitik hatası — (H1) yanlış plant (K=53.89 yerine Kg=K·Vs=654.8, 12×), (H2) doyum kısıtı yok sayıldı (P-terimi e=4.3 rad/s'te doyar). **Analitik düzeltme: doyum-kısıtı (Kp≈duty_max/ω_max=0.002) + doğru-plant pole placement (ω_n=2/τ=33 → Ki=0.1), §11.11.3.** 2b: gerçekçi Simulink + ayrık margin (PM=40°) doğruladı. Test 2.T2 PASS (8/8 step).

**Aşama 2.4 (disturbance) ✅:** Baseline 101 rad/s (=setpoint, PI sıfır ss-error), elle yük ω'yı 56'ya itti (%44 dip), PI duty 0.186→0.50 telafi, setpoint'e döndü. Test 2.T4 PASS.

**Aşama 2.5+2.6 (pozisyon cascade) ✅ 2026-05-24:** Cascade (poz P Kp_pos=2.0 → hız PI) + çıkış mili açısı. Gerçekçi sim limit-cycle uyarısı verdi (sürtünmesiz → kötümser) + **5V sim parametre hatası yakalanıp düzeltildi** (sadece bu oturumun sim scriptlerinde; firmware/doküman/geçmiş test etkilenmedi). Firmware `MODE:POS` + `POS_DEG:`/`KPP:` + watchdog güvenlik düzeltmesi (kapalı-döngü modlarında artık etkili). **Test 2.5 gerçek motorda PASS — 6/6 segment, ss_err<0.8°, OS<1°, limit-cycle YOK (sürtünme simdeki gezinmeyi söndürdü).** Build PASS (Flash 8.0%).

**Aşama 2.6.5 (cascade Simulink + sürtünme) ✅:** `create_cascade_simulink.m` resmi cascade blok diyagramı (firmware-uyumlu model analitik Vsupply sadeleştirmesini ortaya çıkardı → iç ω_n~33, Kp_pos=2.0 ~16× ayrımla güvenli). `verify_realistic_cascade.m`'e Coulomb/stiction sürtünme (eşik Aşama 1 V_dead) eklendi → sürtünmeli sim θ_std=0° = gerçek Test 2.5 ile uyumlu → **sim-to-real gap kapandı** ([Ljung1999] §16). Detay: docs/asama_2_kontrol.md §11.13.7.

**Aktif branch:** `feature/asama-3-mimo-model` (main'den açıldı; Aşama 2 main'e merge + tag `asama-2-kapali`).

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması.
- ~~Stiction tartışması~~ ✅ ÇÖZÜLDÜ 2026-05-18 (reddedildi, analiz artefaktı).
- Gain scheduling — τ duty bağımlılığı (43-134 ms) Aşama 3'te değerlendirilecek.
- Encoder hız ölçümü kuantizasyon (18.7 rad/s) — cascade'de sürtünme söndürdüğü için sorun olmadı; gerekirse T-metodu/pencere büyütme kenarda referans.
- İzleme: 2.4'te motor tam durunca u=0.026 anomalisi (edge-case).

**Aşama 2.7/2.8 (IMU mirror) ✅ 2026-05-26:** MODE:MIRROR — motor fused_pitch'i takip eder (cascade). Kp_pos=6 **ANALİTİK** (deneme-yanılma değil): tip-1 hız hata sabiti Kv=Kp_pos, e_ss=ω_in/Kv, ω_in=30°/s, <5° → Kp_pos≥6 ([Franklin2010] §4.2). **Test 2.T6 PASS** — gimbal-hızı RMS 4.02° (Kp_pos=6 firmware default, 05-31 gerçek-motor ölçümü; analitik 4.63° üst sınırını doğruladı), Kp=5 sweep 4.68°; hızlı el (~80°/s) bant-genişliği limiti (~10°, beklenen). Detay: docs §11.13.8.

**Aşama 3 yöntemi (baseline-önce, analitik iterasyon — ROADMAP §3):** 3.2b motor-2 sürücü/kimlik → baseline 2-eksen (Aşama-2 cascade yeniden-kullan) → MIMO ID (2×2 $G(s)$) → RGA/condition number (`[Skogestad2005] §10`) → kanıta-dayalı kontrolcü. ⚠ Aşama 2 kazançları serbest-mil için — Aşama 5'te gerçek gimbalda yük altında yeniden ayarlanacak.

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED + SpeedPI_Reset stall'da) aktif. Sigorta temin edilince duty cap gevşetilir.

**Akademik çıktılar:**
- Aşama 1: `matlab/asama_1_model/results/20260518_011926/` — 10 PNG + `motor_model_asama1.slx` + `motor_params.json` + `fit_report.md` · `20260518_dogrulama/` (bağımsız 2. tanımlama — reproducibility, docs §10.5)
- Aşama 2.1: `matlab/asama_2_kontrol/results/2_1_speed_pi/` — 3 PNG + `speed_loop_a2_1.slx` + `speed_pi_params.json` + `speed_pi_design_report.md`
- Aşama 2.5-2.6.5: `results/2_5_cascade/` (position_p_design + realistic_cascade + cascade_block_diagram + cascade_simulink_step + cascade_rootlocus + `cascade_pos_a2_5.slx` + position_p_params) · `results/2_3_realistic_sim/` (realistic_sim_verification); test `artifacts/2/position_step/20260524_212456/`. (Cascade vs direct-PID karşılaştırma scriptleri `sweep_position_strategy.m`/`design_position_direct_pid.m` korunur — eski `2_5_strategy/` çıktı dizini silindi, §11.13.)
- Teknik belgeler: [`docs/asama_1_model.md`](docs/asama_1_model.md) (Aşama 1) + [`docs/asama_2_kontrol.md`](docs/asama_2_kontrol.md) (Aşama 2, pozisyon cascade dahil)
