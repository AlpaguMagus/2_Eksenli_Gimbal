# Aşama 5 — Yüklü Gimbal: Sistem Tanımlama & Kontrol

> **Bu belge ne cevaplar:** Yüklü gimbal (LP eksen + telefon-tilt yükü) için sistem tanımlama
> neden serbest-milden farklı yürütülür, yüklü plant nedir, kontrolcü nasıl yeniden tasarlanır.
> Okuyucu: gelecek-ben / danışman. Vitrin → [`README.md`](../README.md); plan → [`ROADMAP.md`](../ROADMAP.md).
>
> **Durum (2026-06-24):** Aşama 3 (yüksüz MIMO) kapalı. Aşama 5 açık — yüklü **sistem tanımlama**
> tamamlandı (sistematik duty-step); **kontrolcü yeniden tasarımı** + bench-validasyon devam ediyor.

---

## 12.5.0 — Neden yüklü tanımlama serbest-milden FARKLI (metodoloji)

**Geçmiş hata (2026-06-24, kullanıcı eleştirisi):** Serbest milde temiz, sistematik sistem tanımlama
yapıldı (Aşama 1: belli duty ver → çıktıyı ölç → model fit). Yüklüde ilk denemede bu sistematik
**atlandı**, dağınık testler (free-decay, hold-release, kinematik) koşuldu → saatlerce confound. Ders:
**aynı sistematik metodoloji yüklüde de uygulanmalıydı.** Bu bölüm hem doğru sonucu hem de **neden
metodun bir parçasının zorunlu olarak değiştiğini** belgeler.

### Gerçek ve zorunlu fark

| | **Serbest mil (Aşama 1)** | **Yüklü gimbal (Aşama 5)** |
|---|---|---|
| Fiziksel sistem | motor + boş mil | motor + **gravite sarkacı** (telefon-tilt yükü) |
| Mertebe | **1.** | **2.** (sarkaç) + **sürtünme nonlineeritesi** |
| Duty step → ne oturur | sabit **HIZA** ($K\cdot u$) | sabit **AÇIYA** (motor torku = gravite torku) |
| Ölçülen çıktı | hız (encoder rate) | **açı** (FP/encoder) |
| Fit | $K,\tau$ (1. mertebe) | $\omega_n, \zeta$ + **stiction/ölü-bölge** |
| Kısıt | yok (serbest döner) | **±90° kablo limiti** → duty sınırlı |

**Sonuç:** *Metodoloji aynı* (sınırlı duty ver → çıktıyı ölç → fit), ama **ölçülen büyüklük (hız→açı)
ve model yapısı (1.→2. mertebe + sürtünme) zorunlu olarak değişir** çünkü plant fiziksel olarak farklı.
Bu farkı atlamak (hızı ölçmeye çalışmak) yüklüde anlamsızdır — sistem sabit hıza oturmaz.

---

## 12.5.1 — Sistematik yüklü sistem tanımlama (açık-döngü duty-step)

**Ne:** Açık-döngü DUTY modunda (FF kapalı, saf plant) sınırlı duty oranları verildi, **açı yanıtı**
ölçüldü. **Nerede:** `scripts/loaded_sysid_systematic.py` → `artifacts/5/loaded_sysid/`.
**Nasıl:** duty ∈ {±0.05, ±0.08, ±0.10}, her biri 3 s; |FP|>78° güvenlik-STOP; denge-relatif açı.

### Sonuç (sayısal)

| duty | sabit açı (denge-rel) | overshoot | kazanç (°/duty) |
|---|---|---|---|
| +0.05 | **−0.9°** | yok | −18 |
| +0.08 | **−1.8°** | yok | −23 |
| −0.05 | +10.6° | yok | −211 |
| −0.08 | +9.5° | yok | −119 |
| +0.10 | −27.2° | yok | −272 |
| −0.10 | +33.6° | yok | −336 |

### Bulgular (dağınık testlerin KAÇIRDIĞI)

1. **YÖN-ASİMETRİK STICTION (ölü-bölge):** **+ yön ~0.10'a kadar TAKILI** (kopma eşiği yüksek);
   **− yön 0.05'te hareket** ediyor. Küçük + kontrol çabaları **hiçbir şey yapmıyor** → kontrolcü ince
   ayar yapamıyor, "yekpare/takılı" davranış. **Tüm kontrol karışıklığının kök-nedeni budur.**
2. **Overshoot YOK** → sürtünme, **sürülürken** rezonansı söndürüyor. (Serbest-coast free-decay'de
   görülen $\omega_n{=}4$ salınımı, motor sürerken kaybolur — sürtünme baskın.)
3. **Statik kazanç** (kopma üstü) ~**−300°/duty**; asılı denge ~−1° (base elle tutulduğu için drift'li).

### Tamamlayıcı tanımlama (diğer ölçümler)

- **Sarkaç doğal dinamiği (serbest-coast free-decay):** $\omega_n \approx 4$ rad/s (0.65 Hz),
  $\zeta \approx 0.1$ — `scripts/loaded_pendulum_id.py`. (Bu **sürülmemiş** sarkaç; sürülünce stiction baskın.)
- **Kinematik kazanç:** $k_{kin} = \Delta FP/\Delta\theta_{out} = -0.84$ (`loaded_pos_hold` veri-fit;
  arşivdeki Adım-1 değeri −1.04 idi, gerçek −0.84). Negatif → stabilizasyon polaritesi `stab_dir = +1`.
- **Gravite FF kazancı:** $k_{ff,grav} = 0.21$ (yüklü; asılı-dışı açıyı tutmak için duty/sin θ).
- **Aktif pozisyon-tutma KANITLI:** `loaded_pos_hold` — motor stand'ı komut açılarında ±0.3° tuttu,
  uzak açıda duty harcadı (gravite taklit edemez) → cascade + gravite-FF aktif çalışıyor.

---

## 12.5.2 — Yüklü plant modeli (tam)

$$G(s) = \frac{FP}{u} = \frac{K_m/J}{s^2 + 2\zeta\omega_n s + \omega_n^2}, \quad \omega_n=4,\ \zeta=0.1,\ \frac{K_m}{J}=\frac{\omega_n^2}{k_{ff,grav}}=\frac{16}{0.21}\approx 76$$

**+ YÖN-ASİMETRİK Coulomb stiction (nonlineer):** kopma duty'si + yön ~0.09–0.10, − yön ~0.04–0.05.
Sürtünme, sürülen rejimde rezonansı söndürür (osilasyon riski düşük).

> 📊 **Üreten betik:** `scripts/loaded_sysid_systematic.py` (duty-step ID). Plant türetimi
> ($K_m/J = \omega_n^2/k_{ff,grav}$) bu belgede; sayısal değerler ham veriden.

---

## 12.5.3 — Kontrolcü yeniden tasarımı (yüklü, analitik)

**Sorun:** Şimdiye dek **yüksüz kazançlarla** (cascade $K_{p,pos}=2$, hız PI Aşama-2) yüklü gimbal
kontrol edildi (ROADMAP KRİTİK NOT: yük altında yeniden ayar gerekir — yarım yapılmıştı).

**BİRİNCİL çözüm — sürtünme/ölü-bölge telafisi (asimetrik Coulomb FF):**
Firmware mevcut: `kff_coul` fwd / `kff_coul_rev` rev (`LFFC:` komutu). Veriden: **+ yön ~0.09, − yön ~0.05.**
Bu, ölü-bölgeyi besleme-ileri ile geçer → kontrolcü ince ayar yapabilir hale gelir. + gravite FF
($k_{ff,grav}=0.21$). Mevcut cascade ($K_{p,pos}=2$) + bu FF ile bench-test edilecek.

> ⚠ **Rezonans-damping (gyro/notch) GEREKSİZ görünüyor — superseded.** Önceki dağınık iş, yüklü plant'ı
> "hafif-sönümlü rezonans" sanıp gyro/notch damping tasarladı (`loaded_pendulum_damping_design.m`,
> `loaded_controller_redesign.m` — **2026-06-24 SİLİNDİ**, yedek `archive-asama5-scattered`). Sistematik
> ID gösterdi ki **sürülen rejimde sürtünme rezonansı zaten söndürüyor** (overshoot yok) → asıl sorun
> rezonans DEĞİL, **stiction ölü-bölgesi**. Önceki "0.8 Hz osilasyon = rezonans" yorumu büyük ihtimal
> **stick-slip limit-cycle** idi. Gyro-damping ancak Coulomb-FF sonrası bir ihtiyaç çıkarsa değerlendirilir.

---

## 12.5.4 — Öğrenilen dersler (kalıcı)

- **Sistematik > dağınık:** yüklü ID'yi serbest-mil metodolojisiyle (sınırlı duty → çıktı → fit) yapmak
  şarttı; dağınık testler stiction'ı kaçırdı, sistematik tek testte buldu. (`CLAUDE.md` "Çalışma
  Disiplini §6 veri-önce" + `/memory/veri-once-imu-encoder-analiz`.)
- **Türetilmiş metrik ≠ ham IMU:** "%5'e döndü" gibi metrikler gravite/drift confound'unu maskeledi;
  ham FP+θ_out izi gerçeği söyledi.
- **Base elle tutulunca drift eder** (asılı denge +14→+26→−1° kaydı) → mutlak-açı testleri bozulur;
  denge-relatif / off-hanging ölçüm gerekir.

## 12.5.5 — Açık konular / sonraki

- [ ] Asimetrik Coulomb FF (+0.09/−0.05) + gravite FF (0.21) ayarla → fine POS / STAB bench-test
- [ ] Off-hanging STAB + **base bozucu** (kullanıcı base'i eğer) → stabilizasyon bench-validasyon (IMU-yargılı)
- [ ] Gyro-damping pratik faydası (sürtünme zaten söndürürken) ölç
- [ ] K7 Kalman entegrasyonu (IMU payload'a — donanım)
