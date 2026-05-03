# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik mimari → [`README.md`](README.md).

**Şu an:** Aşama 2A — Donanım entegrasyonu, koruma katmanları, düşük seviye doğrulama.  
**Branch:** `feature/motor-encoder-tb6612`  
**Son commit:** iskelet kod + dokümantasyon (`59df6a8`).  
**Aşama 1 (IMU + complementary filter):** ✅ Tamamlandı, `main` branch'inde.  
**Sıradaki adım:** ROADMAP § Aşama 2A → adım **2A.1** (Encoder TIM2 implementasyonu).  
**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall detection, duty cap %50, soft-start, watchdog) Aşama 2A'da implement edilip test edilmeden motor çalıştırılmamalı.
