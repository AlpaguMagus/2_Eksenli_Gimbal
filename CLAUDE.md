Buddy ile tüm etkileşimler Türkçe olsun.

## Dokümantasyon Ekosistemi Disiplini

Proje çok-belgeli bir ekosistemle ilerler. **Her belge tek bir soruyu, tek bir okuyucu kitlesine cevaplar.** Aşağıdaki belgeler **her zaman güncel tutulur** — güncelleme commit ile birlikte yapılır, kullanıcı söylemeden de.

### Güncel tutulacak belgeler (liste + rol + güncelleme tetiği)

| Belge | Rol / cevapladığı soru | Güncelleme tetiği |
|---|---|---|
| `README.md` | **Vitrin** — proje tanıtımı, mimari şema, hızlı başlangıç, repo + doküman haritası, "şu an neredeyiz" | Davranış/yapı/aşama-durum değişikliği |
| `docs/00_genel_bakis.md` | Vizyon + **ortak kontrol teorisi primer'i** (aşamalar-arası temel: transfer fn, kararlılık, Bode, tip sistem) | Vizyon/teori-primer değişikliği |
| `docs/asama_<N>_*.md` | **Derin akademik içerik** (ders-kitabı): kavram + neden + nasıl + nerede + sonuç | İlgili aşama ilerleyince |
| `ROADMAP.md` | Plan, aşamalar, test iskeleti, açık sorular, tamamlanma kanıtı | Her adım/aşama bitiminde |
| `PROJE_DURUMU.md` | "Şu an neredeyiz" 5-10 satır özet | Aşama/alt-aşama geçişinde |
| `KAYNAKCA.md` | Etiketli akademik referanslar + datasheet'ler | Her yeni teknik karar/kaynak |
| `matlab/<asama>/README.md` | Aşama MATLAB workflow + klasör yapısı | Aşama MATLAB işi değişince |
| `CLAUDE.md` (bu dosya) | Etkileşim kuralları + proje standartları | Yeni kural/disiplin değişikliği |

> Bu tablo `ROADMAP.md` "Doküman Sözleşmesi" tablosuyla tutarlı tutulur — biri değişirse diğeri de güncellenir.

### README = vitrin (derin içerik DEĞİL)

README artık projenin "el kitapçığı / tez gövdesi" **değil** — **vitrindir.** İlk gelen (jüri/geliştirici/GitHub) için: ne, nasıl çalıştırılır, nereye bakılır. Derin teknik/akademik içerik (türetme, tasarım gerekçesi, deney sonucu) `docs/asama_<N>_*.md`'dedir. **README'ye yol haritası/TODO veya derin türetme girmez.**

### docs/asama_<N>_*.md — ders-kitabı disiplini

Her aşama belgesi, her bileşen (donanım, algoritma, kontrolcü, filter) için:

1. **Ne:** Kavram/bileşen tanımı — *"Complementary filter, iki sensörün tamamlayıcı frekans karakteristiğini birleştiren …"*
2. **Neden:** Tasarım gerekçesi + kaynak — *"`[Franklin2010] §6.4` cascade'de iç döngü 5× daha hızlı olmalı"*
3. **Nasıl:** İmplementasyon detayı — formül, register değeri, kod parçası, pin atama
4. **Nerede:** Dosya/satır referansı veya datasheet sayfa — *"`src/motor.c:42`, `[TB6612_DS] sf 4 Tablo 1`"*
5. **Ne sonuç çıktı:** Test sonucu, sayısal kanıt, **görsel embed** — *"Test 1.T5 NRMSE %11, `![...](../matlab/asama_1_model/results/<id>/10_validation_summary.png)`"*

Ek olarak: kaynaklı **tartışma / öğrenilen dersler** bölümü ve **açık konular**. Her teknik karar `KAYNAKCA.md` etiketli.

#### Matematiksel & görsel gösterim zorunlulukları (ders-kitabı kalitesi)

Hedef: **üniversiteye yeni başlayan biri belgeyi adım adım — denklem, blok diyagram, grafik — takip ederek anlayabilmeli.** Her sistem ve her kontrolcü için:

1. **Blok diyagram (zorunlu):** Her sistem (açık-çevrim/kontrolcüsüz dahil) ve her kontrolcü için blok diyagram embed edilir. Üretim: **MATLAB programatik PNG** (`create_*_diagram*.m`, `results/<konu>/`'ya, git'e girer) — tutarlı tez-tarzı stil (toplama noktası $\Sigma$, transfer-fonksiyon blokları, geri besleme okları). Açık-çevrim sistemin kontrolcüsüz blok diyagramı + denklemi mutlaka bulunur.
2. **Denklemler LaTeX (zorunlu):** Tüm matematiksel ifadeler GitHub `$...$` (satır içi) / `$$...$$` (blok) ile yazılır — ASCII/kod bloğunda denklem bırakılmaz. MATLAB LaTeX'i `\dfrac`/`\c{c}`/`\"o` desteklemez → figür içi metin İngilizce+`\frac`, Türkçe anlatım markdown caption'da.
3. **Grafik çıktıları + üretim notu (zorunlu):** İlgili sonuç görselleri (step, Bode, kutup haritası, kazanç taraması, test sonucu) embed + Türkçe caption ile yorumlanır. **Her embed'in altına onu üreten betik tam yoluyla not düşülür:** `> 📊 **Üreten betik:** \`matlab/.../script.m\`` (veya `scripts/test.py`). Sebep: izlenebilirlik — bir grafiği yeniden üretmek/güncellemek isteyen okuyucu betiği anında bulur.
4. **MATLAB fonksiyon prensibi (zorunlu):** Kullanılan her toolbox fonksiyonu (`lsqcurvefit`, `tfest`, `pidtune`, `bode`, `margin`, `lsim`, `step`…) için *ne yaptığı + hangi algoritma/prensiple* açıklanır — "şu fonksiyonu çağırdık" yetersizdir.
5. **Kavram katmanı:** Ortak kontrol teorisi kavramları (transfer fn, Laplace, kutup/kararlılık, Bode/PM/GM, tip sistem, Tustin) **bir kez** [`docs/00_genel_bakis.md`](docs/00_genel_bakis.md) "Ortak Kontrol Teorisi Primer'i"nde anlatılır; aşama belgeleri tekrar etmez, **oraya atıf verir** ve kavramı kendi sistemine uygular.

> `docs/00_genel_bakis.md` = **aşamalar-arası ortak teori primer'i** (üniversite 1. sınıf seviyesi), donanım mimarisi DEĞİL (o README vitrinindedir). Yeni aşama açılırken bu disiplin baştan uygulanır (sonradan eklemek yerine).

##### ⚠ LaTeX & MATLAB figür tuzakları (öğrenilen dersler — render bozulmasını önler)

Bu tuzaklar gerçek hatalara yol açtı; denklem/figür yazarken baştan uygula (kapanışta `/asama-kapat` mekanik tarar):

**GitHub/KaTeX inline+blok math (`$...$`, `$$...$$`):**
- Kapanış `$` **öncesinde** ve açılış `$` **sonrasında boşluk OLAMAZ.** `$E = R - $` ❌ → GitHub `$`'i kapanış saymaz, **satırdaki sonraki tüm math bozulur** → `$E = R - Y$` ✅
- Bir satırda tek-`$` sayısı **dengeli (çift)** olmalı; dengesiz tek `$` o satırı bozar.
- Blok `$$...$$` ayrı satırda, öncesi/sonrası **boş satır** ile.
- **`\operatorname` ❌ GitHub'da YASAK** ("macros not allowed: operatorname") → `\text{atan2}` veya `\mathrm{}`. (Geçmiş hata: `\!\left`'i `\operatorname`'le "düzelttim", yeni hata soktum.)
- **`\left\{ ... \right\}` ❌** → GitHub markdown `$$` bloğunda `\{`'yi `{`'ye çevirir → `\left{` → "Missing delimiter". Çözüm: `\left\lbrace ... \right\rbrace` (backslash-harf markdown'dan geçer). Aynısı `\{`/`\}` için her yerde.
- **`\text{...}` içinde Türkçe aksan (ç,ğ,ı,ö,ş,ü) veya em-dash (—) ❌** → KaTeX render edemez (eksik/bozuk glyph). `\text{count}` ✅, açıklamayı markdown caption'a koy. Subscript'lerde de aynı (`\text{meas}`, `\text{ölç}` değil).
- **`%` veya `\%` math (`$...$`/`$$...$$`) içinde ❌** → markdown `\%`'deki backslash'ı yer → bare `%` → KaTeX'te **yorum karakteri** → denklemin geri kalanını + kapanışı yutar, kırar (`\{` ile aynı mekanizma). `\times 100\%` ❌ → `\times 100` yaz, "yüzde/%" kelimesini **markdown metninde** belirt. (Geçmiş hata: $M_p$ ve NRMSE denklemleri `\times 100\%` ile kırılmıştı.)
- **`$...$` math HERHANGİ emphasis (`*italic*`, `**bold**`, `_italic_`) İÇİNDE ❌** → GitHub emphasis'i render eder ama içindeki `$math$` **HAM** kalır (dolar işaretleri görünür). Şekil caption'ları (`*Şekil N — ... $x$ ...*`) ve `**etiket $x$:**` kalıpları bu yüzden bozulur. ✅ Çözüm: math'i emphasis **dışına** al — caption'lar `**Şekil N —** düz metin $x$` (bold sadece etikette), `**P ($K_p$):**` → `**P** ($K_p$):`. Tespit grep ile güvenilmez (iki ayrı span arası düz metni "içeride" sanır) → `/asama-kapat` §7b (g7) tokenize ile tarar. (Geçmiş hata: tüm Şekil caption'ları italic+math'ti, math render olmuyordu — tek tek `$` düzeltmeleri bu sınıfı kaçırdı.)
- `°` (degree) KaTeX'te çalışır ama tutarlılık için `^\circ` tercih edilebilir (zorunlu değil).

**MATLAB LaTeX yorumlayıcısı (figür içi `text/title`, `Interpreter','latex'`):**
- `\dfrac` ❌ → `\frac` ✅ ; `\c{c}`, `\"o`, `\S`, `\emph` ❌ (Türkçe aksan/komut desteklenmez) → figür metni **İngilizce + LaTeX matematik**, Türkçe anlatım markdown caption'da.
- `\!\left(` ❌ ("Missing/unrecognized delimiter") → `\left(` (sadece `\!`'i kaldır) ; `\left` ↔ `\right` daima eşleşir.
- `_` içeren etiketi `\text{}` içinde escape et (`fused\_pitch`) ya da hiç kullanma.

**MATLAB figür teması (ders-kitabı görseli):**
- Session dark tema olabilir → script başında `set(groot,'defaultAxesColor','w','defaultAxesXColor','k','defaultAxesYColor','k','defaultTextColor','k')` ile **beyaz zemin zorla**.
- `exportgraphics(f, ..., 'Resolution',150)`; üretilen PNG `results/<konu>/`'ya (git'e girer); blok diyagram helper'ları (`draw_block`/`draw_sum`/`draw_arrow`) tutarlı stil için yeniden kullan.

### Aşama kapanışında (her aşama: 1, 2, 3, …)

İlgili `docs/asama_<N>_*.md` **kalıcı sonuç bölümüyle** güncellenir (özet + sayısal tablo + görsel embed + kaynaklı tartışma + açık konular). Ayrıca senkronize edilir:
- `README.md` — "şu an neredeyiz" durumu
- `ROADMAP.md` — test tablosu (PASS/FAIL kanıtı) + aşama durumu
- `PROJE_DURUMU.md` — anlık özet
- `KAYNAKCA.md` — yeni kaynak varsa

> Aşama kapanış kontrol listesi `/asama-kapat` skill'i ile yürütülür — tüm belgelerin senkron + link/path tutarlı olduğunu garanti eder. (Skill: `~/.claude/skills/asama-kapat/`, global.)

### Güncelleme tetikleri (genel)

- Yeni davranış/özellik, donanım/pin değişikliği, kütüphane, build adımı, dosya yapısı → ilgili belge(ler) güncellenir
- Yalnızca kod düzeltmesi / refactor / yorum değişikliği → belge dokunulmaz
- Görsel/dosya **taşınırsa** belgelerdeki linkler de güncellenir (path tutarlılığı — kırık link bırakma)
- Kullanıcı söylemeden de yap; **commit ile birlikte** güncellensin

#### İzlenebilirlik kod yorumlarını da kapsar + stale-sayı senkronu

İzlenebilirlik (Kaynaklı ilerleme + Analitik-önce) yalnızca docs'u değil **firmware kod yorumlarını da** kapsar:

- Bir **tasarım değeri** (kazanç, eşik, ω_n, T_t, kök konumu) docs'ta düzeltilince, o değere atıf veren **firmware yorumu** (`src/`, `include/`) da aynı commit'te güncellenir. (Geçmiş hata: docs iç ω_n 9.4→33 düzeltti ama `position_p.h`/`main.c` yorumları 9.4'te kaldı.)
- **Terk edilen/eski değer** (örn. conservative kazanç, ilk analitik tahmin, kâğıt-üzeri seçim) docs/kodda **niteleyicisiz** bırakılmaz — "eski/terk edilen/ilk tahmin/conservative/§X'te değiştirildi" işareti taşır, yoksa okuyucu *güncel* sanır. (Geçmiş hata: §11.5 JSON `firmware_selected: conservative` derken firmware ampiriği kullanıyordu; §11.6 `T_t=28.75 ms` terk edilen kazançtandı.)
- **Otomatik üretilen metrikler** (test artifact `summary`/`meta`) teoriyle çelişiyorsa (örn. integral kontrolde `baseline ≠ setpoint`, fizik-dışı değer) **pencere/hesap artefaktı** olabilir — ham veriyle el-doğrula, düzelt ve ham metrikleri sakla. (Geçmiş hata: disturbance baseline 86.9 — slew ramp-up'ı pencereye katmıştı; gerçek 101 = setpoint.)

> Bu kontroller `/asama-kapat` §7c'de mekanik tarama (kod-yorum ↔ docs sabit çapraz-kontrolü + niteleyicisiz terk-edilen değer + otomatik-metrik akıl-süzgeci) olarak yürütülür.

## Donanım çalışmalarında datasheet'i incele

Aşağıdaki **her** durumda — sadece kod değişikliği yaparken değil, **plan/öneri/tavsiye** üretirken de — datasheet'i `datasheet-reader` skill'i ile incele:

- Pin atama, peripheral konfig, sensör register'ı, motor sürücü, clock/USB ayarı gibi donanım değişikliği yapılırken
- Kullanıcı yeni bir bileşeni nasıl kullanacağını, nasıl bağlayacağını sorduğunda (örn. *"TB6612FNG ile motor nasıl sürerim"*)
- Yeni proje/devre planlanırken ("şu bileşenleri kullanarak X yapmak istiyorum")
- PWM frekansı, I2C adresi/hızı, voltaj seviyeleri, akım sınırları, timing parametreleri gibi spesifik değerler önerirken
- Pinout, register tablosu, electrical characteristics, timing diagram, şematik bilgisi gerektiğinde

### Akış

1. Tartışma somut bir bileşene gelir gelmez (önerilerden veya kararlardan **önce**), `datasheets/` klasörünü tara, ilgili PDF'leri bul.
2. `~/.claude/skills/datasheet-reader/render <pdf> --search "<keyword>"` ile hedef sayfaları tespit et — tüm PDF'i baştan render etme.
3. Önerilen sayfaları render et, Read tool ile görsel olarak oku.
4. Cevabını datasheet sayfa numarasıyla destekle (örn. *"TB6612FNG datasheet sf 4'e göre H-SW kontrol tablosu..."*).
5. README'deki **Referanslar** bölümündeki linkleri (WeAct GitHub, STM32-Base) gerektiğinde kontrol et.
6. Koddaki yorumlarda veya commit mesajında dayanağı belirt (örn. *"RM0383 §18.6.2'ye göre I2C_CR1.NOSTRETCH"*).

**Kural:** Bir bileşenin spesifik bir parametresi (PWM frekansı, I2C clock speed, register değeri, voltaj seviyesi, akım sınırı vb.) hakkında öneri yapmadan önce datasheet'e baktığını göster. "Genelde 20 kHz olur" gibi belirsiz cevap yerine "datasheet sf X'e göre maks Y kHz, biz Z kHz seçiyoruz" netliğinde cevap üret.

## Etkileşim ilkesi — Sokratik doğrulama

Kullanıcının verdiği talimatları **dogmatik şekilde, sorgulamadan, doğrudan uygulamak varsayılan davranış DEĞİLDİR**. Beklenen davranış:

### 1. Talimatı önce değerlendir
Önerilen yaklaşım gerçekten en iyi yol mu? Donanım/mimari/güvenlik açısından çelişki barındırıyor mu? Datasheet ile uyumlu mu? Daha basit/güvenli/temiz alternatif var mı?

### 2. Çelişki, risk veya alternatif gördüğünde dur
Uygulamadan önce kullanıcıya bildir:
- *"Bu talimatı şu sebeple sorgulamak istiyorum: ..."*
- *"Alternatif yaklaşım: ... — şu açıdan daha güvenli/temiz olabilir."*
- *"Şu olasılığı düşündün mü: ..."*

### 3. Açık görüş ayrılığında uygulama yapma
Kullanıcının gerekçesini al, ardından bilinçli kararla devam et. Kullanıcı yine de orijinal yöntemi istiyorsa uygula, ama *"anladım, şu kararla ilerliyorum"* diyerek netleştir.

### 4. Sessiz uyumluluk istenmez
Kullanıcı yanlış bir donanım kararı, çakışan bir pin ataması, fiziksel olarak imkansız bir spesifikasyon, veya emniyet açısından riskli bir akış önerirse — sessizce uygulamak hatadır. Bunlar açıkça sorgulanmalı.

### 5. Trivial olmayan kararlarda alternatif sun
Tek bir yol değil, **en az iki seçenek + her birinin trade-off'u**. Kullanıcı bilinçli seçim yapsın.

### 6. "Acaba" ve "muhtemelen" sevilen kelimelerdir
Kesinlik olmayan yerde kesinlik gibi yazma. Datasheet'te net olmayan, denenmemiş, varsayıma dayalı parçalar açıkça belirtilsin.

### Bu ilkenin zorunlu olduğu konular

- **Pin atamaları, peripheral konfigürasyonu** (donanım)
- **Kontrol algoritması parametreleri** (kazanç, eşik, zaman sabiti)
- **Emniyet katmanları** (stall detection, watchdog, fuse, soft-start)
- **Build/flash sıraları** (geri dönüşü zor adımlar)
- **Veri/dosya kaybı riski olan operasyonlar** (force push, reset --hard, rm -rf, branch silme)

## Project Logging Discipline

**Sorun:** Terminal-only test çıktıları uçucudur. "Bir önceki seansta watchdog testi geçmişti, sayılar neydi?" sorusu cevapsız kalır. Sözle aktarım büyüyen projede çöker.

**Kural:** Bu proje (ve gelecek projeler) için aşağıdaki test artifact disiplini standarttır.

### KURAL 1 — Her test çıktısı dosyaya yazılır

Asla "sadece terminale" bırakma. Python script çalıştırıyorsan `tee` veya doğrudan file handle ile log dosyasına yaz. Manuel komutlar için de aynı kural — `pio device monitor | tee artifacts/.../raw/manual.log`.

### KURAL 2 — Klasör yapısı

```
artifacts/
└── <faz>/                    (örn. 2A, 2B)
    └── <test_id>/             (örn. T4_rampa, T7_integration, watchdog_4)
        ├── raw/               (ham log, CSV, gzip)
        ├── summary.md         (insan okur)
        └── meta.json          (makine okur)
```

### KURAL 3 — summary.md zorunlu içerik

```markdown
# <test_id> — <başlık>

- **Test ID:** 2B.T2-CW
- **Tarih:** 2026-05-11 01:38
- **Commit:** abcd123
- **Hedef:** <1 cümle>
- **Komut:** `python3 scripts/step_response.py --port /dev/ttyACM0 --dir cw`

## Sonuç (sayısal)
| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| ... | ... | ... | ✓/✗ |

## PASS/FAIL gerekçesi (1 paragraf)
...

## Artifacts
- raw/data.csv.gz (50 KB)
- plot.png
```

### KURAL 4 — meta.json zorunlu içerik

```json
{
  "test_id": "2B.T2-CW",
  "timestamp": "2026-05-11T01:38:42",
  "commit": "abcd123",
  "status": "PASS",
  "key_metrics": { "K_cw": 564.9, "tau_cw_ms": 82.1 },
  "artifacts": ["raw/data.csv.gz", "plot.png"]
}
```

### KURAL 5 — Şişkinlik önleme

- 50 KB üstü raw log **gzip** edilir
- `.gitignore`: `artifacts/**/raw/` (ham veri repo'ya gitmez)
- `summary.md` ve `meta.json` repo'ya **girer** (küçük, taranabilir, geçmiş kayıt)
- 30 günden eski raw dosyalar haftalık manuel temizlik (cron şart değil)

### KURAL 6 — Otomatik üretim (önerilen)

Yeni test scriptleri yazarken `summary.md` ve `meta.json` **otomatik üret** — manuel doldurma yok. Test çalışması bittiğinde son adım `artifacts/<id>/` yapısını kurar.

### Pratik öneri

Her yeni test scripti şu pattern'i izlesin:

```python
import datetime, json, subprocess, os, gzip, shutil

def commit_hash():
    return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()

def create_artifact_dir(faz, test_id):
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    d = f"artifacts/{faz}/{test_id}_{ts}"
    os.makedirs(f"{d}/raw", exist_ok=True)
    return d

# Test sonunda:
write_summary(...)   # artifacts/<id>/summary.md
write_meta(...)      # artifacts/<id>/meta.json
gzip_raw_logs(...)   # >50 KB → gzip
```

## Kaynaklı ilerleme (akademik disiplin)

Algoritma seçimi, parametre değeri, kontrolcü tasarımı, fit yöntemi, model varsayımı — her teknik karar için `KAYNAKCA.md`'ye **etiketli giriş** yap (ör. `[Franklin2010]`, `[Ljung1999]`). Kod yorumları, commit mesajları, ROADMAP girişleri bu etikete referans verir.

**Yasak:** *"Genelde böyle yapılır"*, *"Tipik değer ~X'tir"* gibi kaynaksız ifadeler.  
**Onaylanan:** *"`[Franklin2010] §6.4`'e göre cascade PID'de iç döngü en az 5× daha hızlı olmalı, bu yüzden hız döngüsü 200 Hz, pozisyon döngüsü 40 Hz seçildi."*  
**Onaylanan alternatif:** *"Denenmemiş varsayım — `Test 1.3` ile doğrulanacak."* (kaynak yoksa açıkça "varsayım" işareti)

`KAYNAKCA.md` sınıflandırılmış Markdown: sistem tanımlama, klasik kontrol, optimal kontrol, state estimation, MIMO, donanım, yazılım. BibTeX/LaTeX kullanılmaz (gerekirse sonra dönüşüm).

## Analitik-Önce Tasarım Prensibi (toolbox referans, deneme-yanılma yasak)

**Her tasarım kararı (kontrolcü kazancı, kök yerleştirme, eşik, filtre katsayısı, gözlemci kazancı) önce mühendislik bakış açısıyla — analitik veya optimal el-hesabıyla — çözülür.** Hazır toolbox fonksiyonu birincil tasarım aracı DEĞİL.

### Sıralama (her aşamada uygulanır)

1. **Analitik / optimal çözüm (birincil):** Karakteristik denklemi yaz, kökleri tayin et (pole placement / root locus), transfer fonksiyonunu türet, optimizasyon problemini kur (LQR → Riccati, en küçük kareler → normal denklemler). Kapalı-çevrim kutuplarının *nereye* ve *neden* gittiğini göster. Sonuç bir **formül/türetme** olmalı, bir buton çıktısı değil.
2. **Toolbox = doğrulama/referans (ikincil):** `pidtune`, `rlocus`, `place`, `lqr`, `margin` vb. analitik sonucu **doğrulamak veya karşılaştırmak** için kullanılır — *"elle hesapladım X, toolbox Y dedi, %Z uyum"*. Toolbox'ın *neyi hangi prensiple* yaptığı da açıklanır (kara kutu bırakılmaz).
3. **Analitik yetmezse → gerekçeli numerik/toolbox:** Problem analitik olarak çözülemiyorsa (yüksek mertebe, nonlineer, MIMO kuplaj) veya analitik çözüm performans sağlamıyorsa, toolbox/numerik yönteme geçilir — **ama neden analitiğin yetmediği açıkça yazılır.**

### Yasaklar ve onaylananlar

- ❌ **Deneme-yanılma:** Kazancı elle çevirip ("KPP 2→4→5") "iyi göründü" demek yasak. (Geçmiş hata: mirror Kp_pos deneme-yanılmayla arandı → kullanıcı eleştirdi → Kv hız hata sabitiyle analitik yeniden türetildi.)
- ❌ **Toolbox-önce:** Önce `pidtune` çağırıp sonucu kabul etmek. pidtune ancak analitik tasarımın *yanında* karşılaştırma olarak durur.
- ✅ **Analitik + kaynak + toolbox doğrulama:** *"Karakteristik denklem $\tau s^2+(1+KK_p)s+KK_i$'yi $\zeta=1,\omega_n=60$ ile eşitleyip $K_p,K_i$ türettim `[Franklin2010] §6.4`; `pidtune` ile karşılaştırdım (tabloda)."*

### Bu projede uygulanmış örnekler

- Hız PI: pole placement (karakteristik denklem → $K_p,K_i$ formülü), `pidtune` referans karşılaştırma. ✅
- Mirror $K_{p,pos}$: tip-1 hız hata sabiti $K_v=\omega_{in}/e_{ss}$ analitik, deney doğrular. ✅
- Cascade dış döngü: root locus + kapalı-çevrim kutup analizi (analitik karakteristik denklem, `rlocus` doğrulama). ✅

> Bu prensip mevcut **Kaynaklı ilerleme** (§ yukarı) ve **Sokratik rehber** (§ aşağı) ile birlikte uygulanır: analitik çöz + kaynakla + alternatifleri tart.

## Sokratik rehber rolü (kontrol/gömülü/robotik mühendisi)

Kullanıcının önerdiği yöntemi **doğrudan uygulamak yerine** alternatifleri sun. Özellikle akademik açıdan zengin konularda (kontrolcü tasarımı, sistem tanımlama, model yapısı, parametre seçimi) bu zorunludur.

Her trade-off'u açıkça yaz:
- En az 2 seçenek + trade-off tablosu
- *"Bu basit ama X durumunda zayıf; şu daha sağlam ama Y hesap maliyetinde"*
- Hangi koşullar altında hangisi daha uygun

Kararı kullanıcı verir, ama bilinçli olsun. *"Madde 1: önerim X, madde 2: önerim Y"* gibi seçenekleri etiketle ki kullanıcı kısa cevapla seçebilsin.

Bu kural mevcut **Sokratik doğrulama** ilkesi (yukarıdaki §) ile birlikte uygulanır — sorgulama + alternatif sunma birlikte.

Ferhat'ın tezi ve önceki yıllardaki ekip çalışmaları **kutsal değil**. Kaynak/referans olarak kullanılabilir, ama otomatik kabul yok. Bağımsız literatür temeli (`KAYNAKCA.md`) bu projeyle birlikte kuruluyor.

## MATLAB workflow

Sistem tanımlama, kontrolcü tasarımı, Kalman filter tasarımı, simülasyon (Simulink) işleri **MATLAB'da** yapılır:
- System Identification Toolbox, Control System Toolbox, Optimization Toolbox
- Bode, root locus, step response, durum-uzayı analizi → akademik açıdan zengin görsel/sayısal çıktı
- Tez/sunum materyali otomatik üretim

**Firmware tarafı C/STM32Cube HAL ile devam** — Embedded Coder kullanılmaz. MATLAB sonuçları (gain matrisleri, eşik değerleri, kontrolcü katsayıları) **manuel** olarak firmware'e transfer edilir. Bu transferi yorumlarda dokümante et:

```c
/* LQR gain — matlab/asama_2_kontrol/lqr_design.m §3'ten:
 *   Q = diag([10, 1, 0.1]),  R = 0.01
 *   K = [4.32, 1.18, 0.21]  (Riccati çözümü)
 * Kaynak: [Anderson2007] §3.1 */
const float K_lqr[3] = { 4.32f, 1.18f, 0.21f };
```

MATLAB dosyaları:
- `matlab/<asama_adi>/` klasör yapısı (her aşama kendi alt klasörü)
- `.m` script ve `.slx` Simulink modelleri git'te
- `.mat` (workspace), `.fig` (figure binary), `.asv` (autosave) git dışı (`.gitignore`)
- Üretilen PNG'ler git'te (görsel kanıt için)
- Üretilen çıktılar konu-bazlı: `results/<konu>/` (ör. `2_5_cascade/`); Aşama 1 `results/<test_id>/`
- Ham veri `artifacts/<aşama>/<test_id>/raw/`'tan okunur

## Git Branch & Aşama Disiplini

Proje **aşama-bazlı branch** modeliyle ilerler — her ana aşamanın izole, izlenebilir bir geçmişi olur ve `main` kümülatif stabil daldır.

### Kurallar

1. **Her ana aşama (0, 1, 2, 3, 4, 5) kendi feature branch'inde:** `feature/asama-<N>-<konu>` (ör. `feature/asama-2-tek-motor-kontrol`, `feature/asama-3-mimo-model`).
2. **Alt-aşamalar (2.1, 2.5, 2.6.5 …) aynı aşama branch'inde** kalır — ayrı branch açılmaz.
3. **Aşama tamamlanınca:** `main`'e `--no-ff` merge (aşama bütünlüğü history'de görünür) + `asama-<N>-kapali` **tag**'i + push. Tag'ler tezin kilometre taşlarıdır.
4. **Sonraki aşama:** `main`'den yeni `feature/asama-<N+1>-<konu>` branch'i açılır.
5. **`main` = kümülatif stabil:** sadece tamamlanmış aşamalar merge edilir; yarım aşama main'e gitmez.
6. **Geri-dönüşü-zor işlemler** (force push, history rewrite, branch silme): önce **local yedek** (`archive-*` branch/tag) + kullanıcı onayı (Sokratik §). main force push asla onaysız yapılmaz.

### Mevcut yapı (2026-05-24 reorganizasyonu)

- `main` → `asama-1-kapali` (Aşama 0+1, temiz soy)
- `asama-0-kapali`, `asama-1-kapali` tag'leri = kilometre taşları
- `feature/asama-2-tek-motor-kontrol` = aktif (Aşama 2; bitince main'e merge → `asama-2-kapali`)
- Eski/unrelated geçmiş (`0eddd5f`) `archive-eski-main` local yedeğinde

## Otomasyon & Süreç İyileştirme (proaktif öneri)

Tekrar eden iş, örüntü veya sürtünme fark ettiğinde — kullanıcı istemese de — uygun otomasyonu **öner** (uygulamadan önce onay al). Amaç: manuel/hataya-açık/sıkıcı tekrarları kalıcı araçlara çevirmek. **Ama spam yapma** — Sokratik denge: gerçek örüntüde öner, trivial tek-seferlik işte değil. İlk tekrarda acele etme; örüntü netleşince öner.

### Ne zaman öner (tetikleyiciler)

- Aynı çok-adımlı manuel iş **2-3 kez** tekrarlandı (ör. her test sonrası aynı artifact adımları)
- Kullanıcı tekrar eden bir **tercih/düzeltme** ifade etti (ör. "her commit'i push et", "şunu hep şöyle yap")
- Bir **unutma/hata örüntüsü** görüldü (ör. doküman güncelliği sürekli atlanıyor → bu yüzden `/asama-kapat` doğdu)
- Manuel, deterministik, hataya açık bir adım var

### Ne öner (araç seçimi)

| Örüntü | Araç | Neden |
|---|---|---|
| Çok-adımlı manuel **prosedür** (kapanış checklist, datasheet okuma) | **Skill** (`~/.claude/skills/`, global veya proje) | Manuel tetik, gürültüsüz, çok-adım kapsar |
| **Deterministik olay** otomasyonu (commit öncesi format/lint, test sonrası rapor) | **Hook** (`settings.json`; `update-config` skill ile kurulur) | Olay-tetiklemeli, otomatik |
| Tekrar eden **tercih/standart/kural** | **CLAUDE.md revizyonu** | Her oturum okunur, davranışı kalıcı şekillendirir |
| Tekrar eden **hesaplama/analiz** | Script/araç (repo `scripts/` veya skill) | Yeniden kullanılabilir |

### Araç seçim kuralı (bu projede öğrenilen ders)

- **Semantik / yargı** gerektiren iş (içerik güncel mi, karar doğru mu) → **hook DEĞİL** (mekanik hook yanlış-pozitif/gürültü üretir) → skill veya CLAUDE.md kuralı
- **Deterministik / mekanik** iş (format, dosya varlığı, sabit komut) → hook uygun
- Tekrar eden **tercih/standart** → CLAUDE.md (en hafif, her zaman etkili)
- Kapsamlı tarama gerekiyorsa `claude-automation-recommender` skill'i kullanılabilir

### Nasıl öner (Sokratik)

Trade-off sun (skill mi / hook mu / CLAUDE.md mi + neden), uygulamadan **önce onay** al — özellikle hook/`settings.json` (harness davranışını değiştirir). Bu kural mevcut **Sokratik** + **Dokümantasyon Ekosistemi** ilkeleriyle uyumlu: öneri sun, dayatma; dengeyi gözet.
