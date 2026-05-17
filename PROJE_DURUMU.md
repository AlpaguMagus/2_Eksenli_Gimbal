# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik mimari + el kitapçığı → [`README.md`](README.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model ✅ → tek motor kontrol → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** ✅ **Aşama 1 KAPALI** (Tek motor sistem tanımlama tamamlandı). 18 step × 4497 örnek, `lsqcurvefit` + `tfest` paralel fit, Simulink validation PASS. Sonuçlar: `K=53.89 rad/s/V`, `τ_median=60.5 ms`, `V_dead≈0`, simetri %1.24, validation NRMSE ort %11.11. Aşama 2 (tek motor PI/cascade kontrol) açılışı bekleniyor.

**Aktif branch:** `feature/asama-1-tek-motor-model` (commit'lenmesi gereken değişiklikler var → bu seans sonu)

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması, Aşama 2'yi engellemiyor.
- Aşama 2'de gain scheduling değerlendirilebilir (K(duty) ve τ(duty) varyasyonu için).

**Sıradaki:** Aşama 2.1 sokratik tartışması — Hız iç döngü PI tasarımı (pole placement, MATLAB Control System Toolbox), `K=53.89, τ=60.5 ms` ile başlangıç kazançları.

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED) aktif. Sigorta temin edilince duty cap gevşetilir.

**Akademik çıktılar (Aşama 1):**
- `matlab/asama_1_model/results/20260518_011926/` — 10 PNG + Simulink `.slx` + JSON parametre + fit_report.md
- README §10 — jüri/hoca el kitapçığı disipliniyle Aşama 1 sonuç bölümü
