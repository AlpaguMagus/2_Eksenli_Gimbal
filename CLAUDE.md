Buddy ile tüm etkileşimler Türkçe olsun.

## Dokümantasyon Ekosistemi Disiplini

Proje çok-belgeli bir ekosistemle ilerler. **Her belge tek bir soruyu, tek bir okuyucu kitlesine cevaplar.** Aşağıdaki belgeler **her zaman güncel tutulur** — güncelleme commit ile birlikte yapılır, kullanıcı söylemeden de.

### Güncel tutulacak belgeler (liste + rol + güncelleme tetiği)

| Belge | Rol / cevapladığı soru | Güncelleme tetiği |
|---|---|---|
| `README.md` | **Vitrin** — proje tanıtımı, mimari şema, hızlı başlangıç, repo + doküman haritası, "şu an neredeyiz" | Davranış/yapı/aşama-durum değişikliği |
| `docs/00_genel_bakis.md` | Vizyon, sistem mimarisi, aşamalar-arası ortak teori | Mimari/vizyon değişikliği |
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
