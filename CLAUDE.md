# Proje CLAUDE.md — 2 Eksenli Gimbal (proje-spesifik standartlar)

> **Genel (proje-üstü) disiplinler kullanıcı-global `~/.claude/CLAUDE.md`'dedir** (2026-05-31'de oraya taşındı): Dil (Türkçe) · Logging & çıktı analizi · **Test artifact disiplini** (artifacts/summary/meta/gzip) · **Sokratik doğrulama & rehberlik** · **Analitik-Önce tasarım** · **Kaynaklı ilerleme** · **Datasheet-önce donanım** · Dokümantasyon genel ilkeleri + **LaTeX/KaTeX & MATLAB tuzakları** · MATLAB konvansiyonları · Aşamalı-proje git modeli · Otomasyon önerisi.
>
> Bu dosya yalnız **bu projeye özgü** bağları içerir. ⚠ Genel kurallar repo dışında (kullanıcı-global) — başka makine/katkıcı için global dosyanın kurulu olması gerekir.

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

## Donanım (proje)

- Datasheet'ler `datasheets/` klasöründe (ACS712, MPU6050, Pololu 25D, TB6612FNG, WeAct BlackPill F411). Datasheet-önce disiplini global CLAUDE.md'de.
- README'deki **Referanslar** bölümü linkleri (WeAct GitHub, STM32-Base) gerektiğinde kontrol edilir.
- Atıf stili örnekleri: *"`[TB6612_DS]` sf 4 H-SW kontrol tablosu"*, *"RM0383 §18.6.2'ye göre I2C_CR1.NOSTRETCH"*.

## Analitik-Önce — bu projede uygulanmış örnekler

Prensip global CLAUDE.md'de. Bu projede:

- **Hız PI:** doyum-kısıtı + doğru-plant pole placement (karakteristik denklem → $K_p,K_i$), `pidtune` referans karşılaştırma (docs §11.12.3). ✅
- **Mirror $K_{p,pos}$:** tip-1 hız hata sabiti $K_v=\omega_{in}/e_{ss}$ analitik → 6; deney doğrular (4.02° < analitik 4.63°). ✅
- **Cascade dış döngü:** analitik karakteristik denklem + kapalı-çevrim kutup analizi, `rlocus` doğrulama. ✅
- Geçmiş ders: mirror Kp_pos önce deneme-yanılmayla arandı → kullanıcı eleştirdi → $K_v$ ile analitik yeniden türetildi. Tekrarlanmaz.

## MATLAB (proje yapısı)

Genel konvansiyonlar (versiyonlama, manuel transfer, Embedded Coder yok) global CLAUDE.md'de. Proje yapısı:

- `matlab/<asama_adi>/` klasörleri: `00_genel_teori/`, `asama_0_altyapi/`, `asama_1_model/`, `asama_2_kontrol/`, (planlı: `asama_3_mimo_model/`, `asama_4_mimo_kontrol/`, `asama_5_gimbal/`)
- Üretilen çıktılar konu-bazlı: `results/<konu>/` (ör. `2_5_cascade/`); Aşama 1 `results/<test_id>/` (tarihli — reproducibility kanıtı)
- Ham veri `artifacts/<aşama>/<test_id>/raw/`'tan okunur
- Toolbox'lar: Control System, System Identification, Optimization, Signal Processing, Simulink

## Git (proje mevcut yapısı)

Aşamalı branch modeli (kurallar) global CLAUDE.md'de. Bu projenin durumu (2026-05-31):

- `main` = kümülatif stabil; **Aşama 0+1+2 kapalı** — `asama-0-kapali`, `asama-1-kapali`, `asama-2-kapali` tag'leri kilometre taşları
- Aktif: `feature/asama2-hizPI-analitik` (Aşama-2-sonrası iyileştirme/dokümantasyon; biriken iş main'e `--no-ff` merge edilir)
- Aşama 3 açılırken: `main`'den `feature/asama-3-mimo-model`
- Eski/unrelated geçmiş `archive-eski-main`, `archive-asama12-full` yerel yedeklerinde

## Proje notları

- Ferhat'ın tezi ve önceki yılların ekip çalışmaları **kutsal değil** — kaynak/referans olabilir, otomatik kabul yok. Bağımsız literatür temeli `KAYNAKCA.md` ile bu projede kuruluyor.
- Proje-lokal skill: `.claude/skills/flash-test/` (build + ST-Link flash + canlı IMU plot akışı — proje donanımına özgü).
