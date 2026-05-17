# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik mimari → [`README.md`](README.md). Akademik kaynaklar → [`KAYNAKCA.md`](KAYNAKCA.md). MATLAB workflow → [`matlab/README.md`](matlab/README.md).

**Vizyon:** Tek motor model → tek motor kontrol → iki motor MIMO → iki motor LQG/Kalman → gerçek 3D-print gimbal. MATLAB paralel araç, firmware C/STM32Cube HAL bare-metal. Her teknik karar **kaynaklı** (`KAYNAKCA.md` etiketli).

**Şu an:** ✅ **Aşama 0 KAPALI** (donanım entegrasyonu, koruma katmanları, USB CDC iki yönlü, watchdog, logging disiplini). Aşama 1 (tek motor sistem tanımlama) açılışı bekleniyor.

**Aktif branch:** `feature/motor-encoder-tb6612` (vizyon yenileme merge sonrası → `main`'e iniyor; sıradaki: `feature/asama-1-tek-motor-model`).

**Son commit (vizyon yenileme):** 5 aşamalı yol haritası, MATLAB klasör iskeleti, KAYNAKCA.md, CLAUDE.md kaynaklı ilerleme + sokratik rehber + MATLAB workflow kuralları.

**Açık konular:**
- 2A.T5-B (gerçek motor stall testi) — bağımsız donanım doğrulaması, Aşama 1'i engellemiyor.
- R6 (CW%20 ölü-bant değişkenliği) — Aşama 1.3 dead-band fitting'de nicelendirilecek.

**Sıradaki:** Aşama 1.1 sokratik tartışması — `scripts/step_response.py` veri toplama planı + MATLAB fit yöntemi (`tfest` vs `lsqcurvefit`).

**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap %50 + soft-start + watchdog + LED) aktif. Sigorta temin edilince duty cap gevşetilir.
