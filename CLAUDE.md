Buddy ile tüm etkileşimler Türkçe olsun.

## README.md güncel tut

Projede anlamlı değişiklik yaptığında (yeni özellik, donanım/pin değişikliği, kütüphane eklemesi, build adımı değişimi, dosya yapısı güncellemesi vs.) `README.md`'yi de güncelle.

- Kullanıcı söylemeden de yap; commit'le birlikte güncellensin.
- Yalnızca kod düzeltmesi / küçük refactor / yorum değişikliği gibi davranışı etkilemeyen değişiklikler için README'ye dokunma.
- README dışında `PROJE_DURUMU.md` varsa onu da gözden geçir; durumu yansıtmıyorsa güncelle.

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
