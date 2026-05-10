# 2 Eksenli Gimbal — Proje Durum Özeti

> 5-10 satır özet. Detay → [`ROADMAP.md`](ROADMAP.md). Teknik mimari → [`README.md`](README.md).

**Şu an:** ✅ **Aşama 2A KAPALI** (10 adım + 6 test PASS, 2A.T5-B sonraya bırakıldı). Aşama 2B planlama aşamasında — motor sistem tanımlama, K/τ/dead-band parametreleri.

**Branch:** `feature/motor-encoder-tb6612`  
**Son commit:** Test 2A.T7 PASS — entegrasyon doğrulandı (135 sn log, 7.5 sequence döngüsü, USB kesintisiz, yanlış stall yok).  
**Açık konular:** R6 — CW%20 ölü-bant değişkenliği (2B.6'da nicelendirilecek). 2A.T5-B gerçek motor stall testi sonraki seansta eldivenle.  
**Sıradaki:** Aşama 2B planı (USB CDC RX, step response Python scripti, fitting). Implementasyondan önce hocaya sunabilir detayda plan üzerinde anlaşma.  
**Açık emniyet uyarısı:** 12V hattında donanım sigortası yok. Yazılım koruma katmanları (stall + lockout + duty cap + soft-start + LED + watchdog hazırlık) Aşama 2A'da implementasyon tamamlandı.
