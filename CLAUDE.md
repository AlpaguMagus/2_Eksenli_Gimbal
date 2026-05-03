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
