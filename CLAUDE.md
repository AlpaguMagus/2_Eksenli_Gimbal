Buddy ile tüm etkileşimler Türkçe olsun.

## README.md güncel tut

Projede anlamlı değişiklik yaptığında (yeni özellik, donanım/pin değişikliği, kütüphane eklemesi, build adımı değişimi, dosya yapısı güncellemesi vs.) `README.md`'yi de güncelle.

- Kullanıcı söylemeden de yap; commit'le birlikte güncellensin.
- Yalnızca kod düzeltmesi / küçük refactor / yorum değişikliği gibi davranışı etkilemeyen değişiklikler için README'ye dokunma.
- README dışında `PROJE_DURUMU.md` varsa onu da gözden geçir; durumu yansıtmıyorsa güncelle.

## Donanım çalışmalarında datasheet'i incele

Pin atama, peripheral konfig, sensör register'ı, motor sürücü, clock/USB ayarı gibi **donanımla** ilgili herhangi bir değişiklik yapmadan önce:

1. `datasheets/` klasöründeki ilgili PDF/şematiği aç.
2. PDF'yi text olarak değil, `/datasheet-reader` skill'i ile **görsel** oku (PyMuPDF → PNG → vision). Pinout tabloları, register haritaları, timing diyagramları ve şematikler text dökümünde bozulur.
3. Önce ToC/ilk sayfaları render et, gerekli bölümü bul, sonra o sayfa aralığını incele — tüm PDF'i baştan render etme.
4. README'deki **Referanslar** bölümündeki linkleri (WeAct GitHub, STM32-Base) gerektiğinde kontrol et.
5. Yaptığın değişikliği koddaki yorumlarda veya commit mesajında datasheet sayfa/şema referansıyla destekle (örn. "RM0383 §18.6.2'ye göre I2C_CR1.NOSTRETCH").
