---
name: teshis
description: Veri-temelli kök-neden teşhisi — performans/davranış şikayetini (geriden geliyor, titriyor, yeterince hızlı değil) spekülasyon yerine ölçülen kanıt + ayırt edici deney + analitik çapraz-doğrulama ile çöz ve dokümana "Teşhis" bölümü olarak kalıcılaştır
disable-model-invocation: true
---

# teshis — veri-temelli kök-neden teşhisi

Bir **performans/davranış şikayeti** geldiğinde ("geriden geliyor", "yeterince hızlı değil",
"titriyor", "ısınıyor", "kayıyor") **spekülasyon yasak**. Bu skill, şikayeti ölçülen kanıtla
çözen ve sonucu dokümana kalıcılaştıran disiplini yürütür.

> Bu disiplin global değil **bu projede** yaşanan gerçek bir vakadan doğdu (2026-06-14, stabilizasyon
> "geriden gelme" → veri-temelli teşhis feedback-only takip hatasını izole etti **ve** bir Kp_pos
> izlenebilirlik çelişkisini yakaladı). Genel prensip: proje `CLAUDE.md` "Teşhis Disiplini".

## Ne zaman çalıştır

- Kullanıcı bir **davranış/performans** sorunu tarif etti (sayısal hedef tutmuyor, "hissiyat" kötü).
- Bir test çıktısı beklenmedik; "neden böyle" sorusu var.
- ❌ Trivial/tek-sebepli mekanik hata (derleme hatası, yanlış pin) için DEĞİL — orada doğrudan düzelt.

## Adımlar

1. **Belirti → hipotez ekseni.** Belirtiyi **sayısal** tarif et. Aday eksenleri AYIR — bunlar fiziksel
   olarak farklı, karıştırma:
   - **Çözünürlük/precision ↔ statik jitter** (sabit hedefte titreme; encoder/ADC kuantizasyonu)
   - **Bandwidth / Kv ↔ dinamik lag** (hareketli referansı geriden izleme; kapalı-çevrim T(s))
   - **Tuning** (kazanç yanlış/yetersiz)
   - **Mimari** (feedforward yok, yanlış sensör konumu, yasa-demosu)
   - **Mekanik** (sürtünme, ölü-bölge, backlash, stall)

2. **Ölçülen kanıt.** Ayırt edici metriği **ham artefakttan** (CSV, terminalden DEĞİL) hesapla:
   xcorr lag (geriden-gelme için), faz kayması, RMS, settling. Gerekirse `artifacts/<faz>/.../raw/`
   gzip'li CSV'yi aç + Python ile metrik üret.

3. **Ayırt edici deney.** Hipotezleri ayıran **tek** manipülasyonu bul, geri kalan SABİT.
   *Örnek:* FF aç/kapa → feedforward'ı çözünürlükten ayırır (çözünürlük değişmeden lag düşerse
   sorun precision değil). En güçlü kanıt budur.

4. **Analitik çapraz-doğrulama.** Beklenen büyüklüğü **türet** (deneme-yanılma değil; proje
   `CLAUDE.md` "Analitik-Önce"). Ör. tip-1 takip hatası $e_{ss}=\omega_{in}/K_v$. Ölçüm ↔ analitik ↔
   bağımsız 3. yol örtüşürse **sağlam** (3-yol yakınsama). Kaynak etiketle (`[Franklin2010]` …).

5. **Konfound kontrolü.** Kıyas adil mi? (tekrarlanamaz uyarım, farklı genlik, ısınma sırası).
   Konfound varsa **dürüstçe işaretle** — yanıltıcı metriği birincil yapma (ör. ham RMS yerine
   hıza-normalize / in-range metrik).

6. **İzlenebilirlik taraması.** Teşhis sırasında **firmware ↔ docs ↔ MATLAB-model ↔ artefakt-etiket**
   değer çelişkisi çıkarsa (ör. firmware `Kp_pos=2.0` ama model/docs/etiket `6`) bunu **ayrı bir bulgu**
   olarak kaydet — proje `CLAUDE.md` "izlenebilirlik kör noktaları" sınıfı. `git log -S` ile gerçek
   koşan değeri kesinleştir.

7. **Kök-neden sıralaması + olgunluk.** Nedenleri **kanıt gücü + düzeltilebilirlik** ile sırala;
   her düzeltmeyi ladder/ROADMAP basamağına bağla (📐 sim / 🔧 fw / 🧪 bench / ✅ validated).

8. **Teşhis kaydı (ZORUNLU).** Sonucu `docs/asama_<N>_*.md` altına **`### N.x. Teşhis: <belirti>`**
   bölümü olarak yaz (şablon aşağıda) + senkronize et (PROJE_DURUMU açık-konu, ROADMAP). Chat'te
   buharlaşmasın.

## Çok-kaynaklı teşhis (workflow şablonu)

Birden fazla kanıt-yolu paralel taranacaksa `stab-lag-diagnosis` workflow desenini yeniden kullan
(kayıtlı script: `workflows/scripts/stab-lag-diagnosis-*.js`):

- **Faz 1 (paralel inceleme):** (a) firmware+tasarım kazanç/bandwidth, (b) ölçülen artefakt metriği,
  (c) mimari/ladder konumu, (d) kontrol-teorisi analitik lag-bütçesi. Her biri `FINDING_SCHEMA`.
- **Faz 2 (sentez):** kök-neden sıralaması + precision-eleme + düzeltme + ölçülen-etki.

## Teşhis doküman bölümü şablonu

```markdown
### N.x. Teşhis: <belirti> · 🔬 veri-temelli

**Belirti.** <kullanıcı gözlemi, sayısal>
**Ayırt edici deney.** <tek manipülasyon> → <hipotez ayrımı>

| Metrik | Durum A | Durum B | Kanıt |
|---|---|---|---|
| ... | ... | ... | artifact path |

**Kök-neden sıralaması.**
| # | Neden | Kanıt | Düzeltme | Olgunluk |
**Precision DEĞİL — neden:** <çözünürlük↔jitter / bandwidth↔lag ayrımı>
**⚠ Konfound / izlenebilirlik bulgusu:** <varsa>
**Açık konular:** <kalan>

> 📊 **Üreten analiz:** <workflow/script> — <artifact paths>
```

## Notlar

- PASS/teşhis şartı **hedefe ulaşmayı** içermeli (sadece "anomali yok" yetmez).
- Ölçüm dosyaya yazılır (proje `CLAUDE.md` "Test Artifact Disiplini").
- Düzeltme donanım gerektiriyorsa (flash + fiziksel test) kullanıcı **"hazırım"** demeden başlatma.
