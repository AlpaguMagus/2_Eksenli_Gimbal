# Proje CLAUDE.md — 2 Eksenli Gimbal (proje-spesifik standartlar)

> **Genel (proje-üstü) disiplinler kullanıcı-global `~/.claude/CLAUDE.md`'dedir** (2026-05-31'de oraya taşındı): Dil (Türkçe) · Logging & çıktı analizi · **Test artifact disiplini** (artifacts/summary/meta/gzip) · **Sokratik doğrulama & rehberlik** · **Analitik-Önce tasarım** · **Kaynaklı ilerleme** · **Datasheet-önce donanım** · Dokümantasyon genel ilkeleri + **LaTeX/KaTeX & MATLAB tuzakları** · MATLAB konvansiyonları · Aşamalı-proje git modeli · Otomasyon önerisi.
>
> Bu dosya yalnız **bu projeye özgü** bağları içerir. ⚠ Genel kurallar repo dışında (kullanıcı-global) — başka makine/katkıcı için global dosyanın kurulu olması gerekir.

## ⚠ Çalışma Disiplini — sistematik ilerleme, plan-bağlılığı & güvenlik onayı

> **2026-06-24 kullanıcı geri-bildirimi (kalıcı kural):** "plan dışına çıkma meyilin var — sistematik
> gideceğiz, disiplinleri gözden kaçırma; benden fiziksel bir şey isteyince NE yapacağımı çok açık
> belirt ve **hazır mıyım diye SOR** (görmeyip dalıyorum / motor yanlış pozisyonda tehlike); önerdiğin
> sırayla ilerle; sokratik ol." Bu bölüm her oturum okunur — atlanmaz.

**1. Plan-bağlılığı (drift YASAK).** Her teknik adımdan ÖNCE mekanik sor: *"ROADMAP / Kontrol Merdiveni'nde
NEREDEYİZ, sıradaki PLANLI adım ne?"* Ad-hoc deneme / basamak atlama yok. Bir iş plana oturmuyorsa
önce **planı göster + sıralamayı doğrula**, sonra ilerle. Birden çok teşhis/tasarım turuna dalmadan
önce planı tekrar kontrol et (bu projede tekrarlanan hata: analiz/teşhis derinliğine dalıp planı
bayatlatmak).

**2. Önerdiğin sırayla ilerle.** Bir adım listesi sunduysan o sırayı takip et; sırayı değiştireceksen
**gerekçele + onay al**, sessizce atlama.

**3. Sistematik disiplinler ATLANMAZ** (hız uğruna bile): Analitik-önce · Kaynaklı · Teşhis (spekülasyon
yasak, ham-veri) · Test-artifact (summary/meta) · Datasheet-önce · İzlenebilirlik · Aşamalı-git. Genel
disiplinler global CLAUDE.md'de — her adımda geçerli.

**4. 🛑 GÜVENLİK — fiziksel/motorlu HER istekten önce AÇIK onay (en kritik kural).** Kullanıcıdan fiziksel
bir eylem istediğinde (motoru/tabanı eğ-sars, stand'ı kaldır, flash, motorlu test başlat, kabloya dokun):
   - **NE yapacağını madde madde, çok açık yaz:** hangi parça · ne yönde · ne kadar (derece/saniye) · kaç kez.
   - **Motor pozisyonu & güvenliği belirt:** motor şu an nerede, hangi yöne gidecek, runaway / çarpma /
     **±90° kablo limiti** riski var mı, başlamadan önce hangi konumda olmalı.
   - **"Hazır mısın?" diye SOR ve BEKLE** — kullanıcı *"hazırım/evet"* demeden testi BAŞLATMA. Kullanıcı
     bazen talimatı görmeyip dalıyor → motor yanlış pozisyonda **fiziksel tehlike**. Bu yüzden onay
     zorunlu. Detay: `.../memory/bench-test-hazirim-bekle.md`.

**5. Sokratik (global CLAUDE.md "Etkileşim ilkesi").** Trivial olmayan kararda alternatif + trade-off sun,
kullanıcı bilinçli karar versin; sessiz uyumluluk değil.

**6. 🔬 VERİ-ÖNCE (IMU+encoder) — test koşmadan ÖNCE eldeki veriyi DERİN analiz et.** Bu projede tek
sensör **IMU (FP) + encoder (θ_out)**. Üst üste confound'lu test koşmak yerine eldeki ham veriyi sonuna
kadar çöz: **kinematik harita** (FP↔θ_out fit → k_kin, asılı denge), **dinamik** (free-decay ω_n/ζ),
**kontrolcü gerçekten kompanze ediyor mu** (FP saparken θ_out karşı-hareket etti mi — etmiyorsa kontrol
YOK), **base-drift** (asılı denge testler arası kaydı mı → mutlak-açı testlerini bozar). Sonucu **ham
FP+θ_out izinden** oku — türetilmiş metrik (p2p, "%X'e döndü") gravite/drift confound'unu maskeler.
Yeni test ancak veri *"şu ayırt-edici ölçüm eksik"* dediğinde. **(Geçmiş ders 2026-06-24: saatlerce
confound'lu STAB testi koşuldu, hepsi sonuçsuz; TEK veri-analizi k_kin=−0.84 (arşiv −1.04 yanlıştı),
base-drift +14→+26°, ve STAB testlerinin "denge-only/bozucu-yok" olduğunu anında gösterdi — kullanıcı
"IMU'ya bakmıyorsun" diye haklı eleştirdi.)** Bkz. `.../memory/veri-once-imu-encoder-analiz.md`.

## Dokümantasyon Ekosistemi (proje tablosu)

Aşağıdaki belgeler **her zaman güncel tutulur** (genel ilke: global CLAUDE.md "Dokümantasyon genel ilkeleri"):

| Belge | Rol / cevapladığı soru | Güncelleme tetiği |
|---|---|---|
| `README.md` | **Vitrin** — proje tanıtımı, mimari şema, hızlı başlangıç, repo + doküman haritası, "şu an neredeyiz" | Davranış/yapı/aşama-durum değişikliği |
| `docs/00_genel_bakis.md` | Vizyon + **ortak kontrol teorisi primer'i** (aşamalar-arası temel: transfer fn, kararlılık, Bode, tip sistem) | Vizyon/teori-primer değişikliği |
| `docs/00_donanim_semasi.md` | **Tek yaşayan donanım şeması** (kesişen: pin haritası + ASCII bağlantı + kablolama + güç + ACS712 rezerv). Faz belgeleri buna atıf verir | Donanım/pin/kablolama değişikliği |
| `docs/asama_<N>_*.md` | **Derin akademik içerik** (ders-kitabı): kavram + neden + nasıl + nerede + sonuç | İlgili aşama ilerleyince |
| `ROADMAP.md` | Plan, aşamalar, test iskeleti, açık sorular, tamamlanma kanıtı | Her adım/aşama bitiminde |
| `PROJE_DURUMU.md` | "Şu an neredeyiz" 5-10 satır özet | Aşama/alt-aşama geçişinde |
| `KAYNAKCA.md` | Etiketli akademik referanslar + datasheet'ler | Her yeni teknik karar/kaynak |
| `matlab/<asama>/README.md` | Aşama MATLAB workflow + klasör yapısı | Aşama MATLAB işi değişince |
| `CLAUDE.md` (bu dosya) | Proje-spesifik standartlar | Yeni kural/disiplin değişikliği |

> Bu tablo `ROADMAP.md` "Doküman Sözleşmesi" tablosuyla tutarlı tutulur — biri değişirse diğeri de güncellenir.

### Proje bağlamaları (vitrin / ders-kitabı / primer)

- **README = vitrin:** derin teknik/akademik içerik (türetme, tasarım gerekçesi, deney sonucu) `docs/asama_<N>_*.md`'dedir; README'ye yol haritası/TODO veya derin türetme girmez.
- **`docs/asama_<N>_*.md` ders-kitabı disipliniyle yazılır** (Ne/Neden/Nasıl/Nerede/Sonuç + kaynaklı tartışma + açık konular — global CLAUDE.md). Her teknik karar `KAYNAKCA.md` etiketli.
- **Kavram katmanı:** ortak kontrol teorisi kavramları **bir kez** [`docs/00_genel_bakis.md`](docs/00_genel_bakis.md) "Ortak Kontrol Teorisi Primer'i"nde (üniversite 1. sınıf seviyesi); aşama belgeleri tekrar etmez, oraya atıf verir. `00_genel_bakis.md` donanım mimarisi DEĞİL (o README vitrininde). Yeni aşama açılırken bu disiplin baştan uygulanır.
- **Donanım katmanı (kesişen — teori primer'iyle aynı mantık):** tam pin haritası / şema / kablolama **bir kez** [`docs/00_donanim_semasi.md`](docs/00_donanim_semasi.md)'de (TEK doğruluk kaynağı); faz belgeleri (asama_0 §8, asama_3 §12) **şemayı tekrar etmez**, oraya atıf verir, yalnız **pin seçim gerekçesini** tutar. (Geçmiş ders 2026-06-09: şema iki faz-belgesinde duplike edildi → IMU voltajı 5V/3.3V ıraksadı; ayrı belgeye çekilerek çözüldü.)
- **Figür üretimi:** MATLAB programatik PNG (`create_*_diagram*.m`) → `results/<konu>/` (git'e girer); blok diyagram helper'ları (`draw_block`/`draw_sum`/`draw_arrow`) tutarlı tez-tarzı stil için yeniden kullanılır. Her embed altına üretim notu: `> 📊 **Üreten betik:** \`matlab/.../script.m\``.

### Aşama kapanışında (her aşama: 1, 2, 3, …)

İlgili `docs/asama_<N>_*.md` **kalıcı sonuç bölümüyle** güncellenir (özet + sayısal tablo + görsel embed + kaynaklı tartışma + açık konular). Ayrıca senkronize edilir: `README.md` (şu an neredeyiz) · `ROADMAP.md` (test tablosu PASS/FAIL + aşama durumu) · `PROJE_DURUMU.md` · `KAYNAKCA.md` (yeni kaynak varsa).

> Kapanış kontrol listesi `/asama-kapat` skill'i ile yürütülür (`~/.claude/skills/asama-kapat/`, global) — belge senkronu + link/path + LaTeX render + kod-yorum stale taramalarını garanti eder.

### İzlenebilirlik — bu projede yaşanmış kör noktalar

Genel kural global CLAUDE.md'de ("İzlenebilirlik kod yorumlarını da kapsar"). Bu projede yaşanan örnekler (tekrarını önlemek için):

- docs iç ω_n 9.4→33 düzeltildi ama `position_p.h`/`main.c` yorumları 9.4'te kalmıştı.
- §11.5 JSON `firmware_selected: conservative` derken firmware başka kazanç kullanıyordu; §11.6 `T_t=28.75 ms` terk edilen kazançtandı — "conservative" **adı** niteleyici sanılıp tarama dışı kalmıştı.
- Disturbance baseline 86.9 görünüyordu — slew ramp-up'ı pencereye katan hesap artefaktı; gerçek 101 = setpoint.

> Bu sınıf hatalar `/asama-kapat` §7c'de mekanik taranır.

### Atlamalı / ileri-prep iş sonrası faz-senkron (zorunlu)

Sıradan atlayıp **ileri bir aşamanın basamağını** (Kontrol Merdiveni K-x) donanımsız ön-tasarımla yaptığında, iş **tek bir yeri değil, ona referans veren TÜM belgeleri** bayatlatır. Aynı commit'te şu zinciri senkronla:

1. **Ön-tasarım zonu** — `docs/asama_3 §12.7` (olgunluk banner'ı + eklemeli sözleşme; **sim ≠ validasyon**, bench gelince EKLENİR, silinmez).
2. **ROADMAP** — ladder olgunluk-rozeti (📐 sim / 🔧 fw / 🧪 bench / ✅ validated / ⛔ gated) **VE hedef faz-bölümü** (MATLAB dosya listesi, alt-adımlar, önkoşul — eski/yanlış-faz girdilerini ayıkla; ör. Kalman = K7 = Aşama 5, Aşama 4'te listelenmez).
3. **Yapı belgeleri** — `matlab/README` (klasör listesi) + hedef faz klasörünün `README`'si.
4. **PROJE_DURUMU** + gerekirse bu dosyanın MATLAB-yapı satırı.

> **Tetik kuralı:** her donanımsız ileri-prep commit'inden sonra mekanik sor: *"bu hangi faz-bölümünü / yapı-belgesini bayatlattı?"* — `/asama-kapat` stale-taraması (§7c) **aşama kapanışı beklemeden** bu iş için de çalıştırılır. **Geçmiş ders (2026-06-13):** K6/K7 ileri-prep'inde `docs §12.7` + matlab klasörleri güncellendi ama **ROADMAP faz-bölümü (`kalman_design.m` yanlış-fazda) + `matlab/README` ("asama_4/5 henüz yok")** bayat kaldı — kullanıcı denetimi yakaladı. Birincil zon güncellemesi yeterli değil; yayılım zorunlu.

## Donanım (proje)

- Datasheet'ler `datasheets/` klasöründe (ACS712, MPU6050, Pololu 25D, TB6612FNG, WeAct BlackPill F411). Datasheet-önce disiplini global CLAUDE.md'de.
- README'deki **Referanslar** bölümü linkleri (WeAct GitHub, STM32-Base) gerektiğinde kontrol edilir.
- Atıf stili örnekleri: *"`[TB6612_DS]` sf 4 H-SW kontrol tablosu"*, *"RM0383 §18.6.2'ye göre I2C_CR1.NOSTRETCH"*.

## Analitik-Önce — bu projede uygulanmış örnekler

Prensip global CLAUDE.md'de. Bu projede:

- **Hız PI:** doyum-kısıtı + doğru-plant pole placement (karakteristik denklem → $K_p,K_i$), `pidtune` referans karşılaştırma (docs §11.11.3). ✅
- **Mirror $K_{p,pos}$:** tip-1 hız hata sabiti $K_v=\omega_{in}/e_{ss}$ analitik → 6; deney doğrular (4.02° < analitik 4.63°). ✅
- **Cascade dış döngü:** analitik karakteristik denklem + kapalı-çevrim kutup analizi, `rlocus` doğrulama. ✅
- Geçmiş ders: mirror Kp_pos önce deneme-yanılmayla arandı → kullanıcı eleştirdi → $K_v$ ile analitik yeniden türetildi. Tekrarlanmaz.

## Teşhis (diagnosis) Disiplini — performans/davranış şikayetleri

Bir **performans/davranış** şikayeti geldiğinde ("geriden geliyor", "yeterince hızlı değil", "titriyor",
"ısınıyor", "kayıyor") **spekülasyon yasak** — veri-temelli teşhis yürütülür ve **dokümana "Teşhis"
bölümü olarak kalıcılaştırılır** (chat'te buharlaşmasın). Tam prosedür + workflow şablonu + bölüm
şablonu: `.claude/skills/teshis/` (`/teshis`). Çekirdek adımlar:

1. **Belirti → hipotez ekseni:** belirtiyi sayısal tarif et; aday eksenleri AYIR (bunlar fiziksel olarak
   farklı, karıştırma): **çözünürlük/precision ↔ statik jitter** · **bandwidth/Kv ↔ dinamik lag** ·
   **tuning** · **mimari** (FF yok / sensör konumu / yasa-demosu) · **mekanik** (sürtünme/ölü-bölge/stall).
2. **Ölçülen kanıt:** ayırt edici metriği **ham artefakttan** hesapla (xcorr lag, faz, RMS) — terminalden değil.
3. **Ayırt edici deney:** hipotezleri ayıran **tek** manipülasyon, geri kalan sabit (ör. FF aç/kapa →
   feedforward'ı çözünürlükten ayırır: çözünürlük değişmeden lag düşerse sorun precision değil).
4. **Analitik çapraz-doğrulama:** beklenen büyüklüğü türet ($e_{ss}=\omega_{in}/K_v$ …), 3-yol yakınsama = sağlam.
5. **Konfound kontrolü:** kıyas adil mi (tekrarlanamaz uyarım, farklı genlik)? Yanıltıcı metriği birincil yapma.
6. **İzlenebilirlik taraması:** teşhis sırasında firmware↔docs↔model↔etiket **değer çelişkisi** çıkarsa
   ayrı bulgu olarak kaydet + `git log -S` ile gerçek koşan değeri kesinleştir (kör nokta sınıfı).
7. **Kök-neden sıralaması + olgunluk:** kanıt+düzeltilebilirlik ile sırala, düzeltmeyi ladder/ROADMAP'e bağla.
8. **Teşhis kaydı:** `docs/asama_<N>` altına `### Teşhis` bölümü + PROJE_DURUMU/ROADMAP senkron.

> **Doğuş vakası (2026-06-14):** stabilizasyon "geriden gelme" → teşhis feedback-only tip-1 takip hatasını
> izole etti (FF ile lag $165\to 0$ ms, precision değil) **ve** bir $K_{p,pos}$ izlenebilirlik çelişkisini
> yakaladı (firmware $2.0$, model/docs/etiket $6$). Detay: `docs/asama_3_mimo_model.md §12.9`.

## MATLAB (proje yapısı)

Genel konvansiyonlar (versiyonlama, manuel transfer, Embedded Coder yok) global CLAUDE.md'de. Proje yapısı:

- `matlab/<asama_adi>/` klasörleri: `00_genel_teori/`, `asama_0_altyapi/`, `asama_1_model/`, `asama_2_kontrol/`, `asama_3_mimo_model/` (KAPALI; K0–K4 bench-valide), `asama_4_mimo_kontrol/` (📐 K6 LQR/LQI ön-tasarım), `asama_5_gimbal/` (AKTİF — yüklü gimbal: yüklü plant-ID Y0 `loaded_plant_id_design.m`/`loaded_plant_id_fit.m` + analitik kontrol Y1 `loaded_control_design.m` + K7 Kalman `design_kalman_attitude.m`) — `asama_4`/`asama_5` iskeleti 2026-06-13 merdiven ön-tasarımı (`docs §12.7`); `asama_5` yüklü ID/kontrol 2026-06-24 bench koşumlarıyla aktif
- Üretilen çıktılar konu-bazlı: `results/<konu>/` (ör. `2_5_cascade/`); Aşama 1 `results/<test_id>/` (tarihli — reproducibility kanıtı)
- Ham veri `artifacts/<aşama>/<test_id>/raw/`'tan okunur
- Toolbox'lar: Control System, System Identification, Optimization, Signal Processing, Simulink

## Git (proje mevcut yapısı)

Aşamalı branch modeli (kurallar) global CLAUDE.md'de. Bu projenin durumu (2026-06-24):

- `main` = kümülatif stabil; **Aşama 0+1+2+3 kapalı** — `asama-0-kapali`, `asama-1-kapali`, `asama-2-kapali`, `asama-3-kapali` tag'leri kilometre taşları
- Aktif: `feature/asama-5-yuklu-gimbal` (yüklü gimbal, AÇIK)
- Aşama 3 main'e `--no-ff` merge edildi (`asama-3-kapali`); Aşama 4 ön-tasarım; Aşama 5 `main`'den `feature/asama-5-yuklu-gimbal` ile açıldı.
- Eski/unrelated geçmiş `archive-eski-main`, `archive-asama12-full` yerel yedeklerinde

## Proje notları

- Ferhat'ın tezi ve önceki yılların ekip çalışmaları **kutsal değil** — kaynak/referans olabilir, otomatik kabul yok. Bağımsız literatür temeli `KAYNAKCA.md` ile bu projede kuruluyor.
- Proje-lokal skill: `.claude/skills/flash-test/` (build + ST-Link flash + canlı IMU plot akışı — proje donanımına özgü).
