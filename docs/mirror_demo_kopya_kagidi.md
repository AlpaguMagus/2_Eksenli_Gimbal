# Mirror (Aşama 2.7) — Demo Kopya Kâğıdı

> Tek sayfalık sunum aidi (ekosistem dokümanı değil). Derin içerik: [`asama_2_kontrol.md`](asama_2_kontrol.md) §11.13.8.

## 🎤 30-saniye açılış
> *"Aşama 2'yi kapattık: hız PI → pozisyon cascade → **IMU mirror takibi**. Breadboard'u eğince motor şaftı aynı açıya canlı gidiyor. Mirror, kanıtlanmış cascade altyapısının üzerine **sadece referans kaynağını** (sabit hedef yerine canlı IMU pitch) değiştirir; kazancı ise **deneme-yanılmayla değil, takip teorisiyle (Kv hız hata sabiti) analitik** seçtik."*

## 🔢 Anahtar sayılar (gözüne çarpsın)
| | |
|---|---|
| Kazanç (göreve göre, MODE ile **otomatik**) | step **Kp_pos=2** · takip **Kp_pos=6** |
| Analitik türetme (tip-1) | $K_v=K_{p,pos}$ → $K_{p,pos}\ge \omega_{in}/e_{ss}=30/5=$ **6** |
| Gerçek test (2.T6) | RMS **4.02° < 5° PASS** (Kp=6 firmware default, gerçek) · Kp=5 sweep 4.68° · analitik 4.63° |
| Bant genişliği | cascade ~0.3 Hz → gimbal-hızı ~30°/s ✓ · hızlı el ~80°/s aşar (~10.6°) |
| Referans şekillendirme | clamp **±60°** · slew **90°/s** · göreli pitch₀ (ani sıçrama yok) |

## ▶️ Canlı demo (donanım varsa — en güçlü kanıt)
1. USB bağla → `pio device monitor` *(veya `python3 scripts/mirror_test.py`)*
2. `MODE:MIRROR` gönder → kazanç **otomatik 6.0**, geçiş anı pitch'i referans (pitch₀) alınır
3. Board'u **yavaş** eğ (~30°/s) → motor şaftı aynı yöne takip eder
4. **Hızlı** eğ → gecikme görünür → *"bant limiti, beklenen — gimbal yavaş hareket içindir"* (dürüst göster)
5. `STOP` → takipten güvenli çıkış (watchdog hedefi sıfırlar)

## 🖼️ Göster (bu sırayla)
1. **Şekil 11.17** `mirror_blockdiagram.png` — mimari: IMU+filtre → ref üretimi → cascade → motor
2. **Denklem** (ekran/tahta): $K_v=K_{p,pos}$, $e_{ss}=\omega_{in}/K_v$ → $K_{p,pos}\ge 6$
3. **Şekil 11.18** `mirror_tracking_design.png` — analitik: deney noktası (4.68° @ Kp=5) eğrinin üzerinde
4. **Şekil 11.19** `mirror_plot.png` — gerçek (Kp=6 firmware default, RMS 4.02°): θ_out, θ_ref'i ±48° izliyor; hata ±5° bandında

## ⭐ Vurgu (4 madde)
- **Analitik-önce:** $K_v$ ile türetildi, deneme-yanılma değil. Deney **doğrular, üretmez.**
- **Altyapı yeniden kullanımı:** yeni kontrolcü değil; cascade'in (Test 2.5 PASS) referansını değiştirmek.
- **Göreve-uyarlı kazanç:** step=2 / takip=6, MODE ile otomatik — iki görev, iki analitik kazanç.
- **Sim-to-real tutarlılığı:** Kp=6 analitik 4.63° ↔ gerçek **4.02°** · Kp=5 analitik 5.56° ↔ gerçek 4.68° — ikisi de aynı mertebede.

## ⚠️ Dürüst kaveatlar (SEN önce söyle, savunmaya düşme)
- **Mirror = takip (+pitch), stabilizasyon DEĞİL** (−pitch, kamerayı sabit tutma → **Aşama 5**).
- **Serbest mil, yüksüz kazanç** → gerçek gimbalda yük + atalet ile yeniden ayar.
- **Bant limiti:** hızlı el cascade bandını aşar (~10.6°) — fiziksel sınır, kusur değil.
- **Öğrenilen ders:** Kp_pos önce deneme-yanılmayla arandı (2→4→5), sonra **özeleştiriyle** $K_v$ ile yeniden türetildi.

## ❓ Olası sorular → kısa cevap
- *"Neden türev (D) yok?"* → Encoder zaten hızı (türevi) ölçüyor; D gürültüyü amplifiye eder.
- *"Dış döngü neden P, PI değil?"* → Plant tip-1 (hız→pozisyon integratör); P ile ss_error=0 (`[Franklin2010] §4.3`).
- *"Kazanç step'ten neden farklı?"* → Step kriteri overshoot (Kp=2); takip kriteri lag/$K_v$ (Kp=6).
- *"Test Kp=5 ama firmware 6?"* → Artık ikisi de gerçek-motorda ölçüldü: Kp=6 firmware default **4.02°**, Kp=5 sweep 4.68° — ikisi de <5° PASS.
- *"Gerçek stabilizasyon ne zaman?"* → Aşama 5: −pitch, kamerayı eylemsiz tutma + MIMO/LQG.

## 📂 Açılacak dosyalar
- `docs/asama_2_kontrol.md` §11.13.8 — anlatı omurgası
- `docs/00_genel_bakis.md` §2.7 — sistem tipi / $K_v$ teori temeli
- `matlab/asama_2_kontrol/design_mirror_tracking.m` — $K_v$ türetmesi kodda (satır 5-17)
- `src/main.c` (218-250) + `src/cmd_parser.c` (76, MODE:MIRROR→SetGain 6.0) — firmware
- `artifacts/2/mirror/20260531_174740/summary.md` — sayısal sonuç (Kp=6 firmware default, RMS 4.02° PASS); Kp=5 koşusu `…/20260526_204240/`
- Görseller: `matlab/.../results/2_7_mirror/{mirror_blockdiagram,mirror_tracking_design}.png` + `artifacts/2/mirror/20260531_174740/mirror_plot.png`
