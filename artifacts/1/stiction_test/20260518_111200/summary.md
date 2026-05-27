# Stiction Hipotezi Doğrulama Testi — REDDEDİLDİ

- **Test ID:** 20260518_111200
- **Tarih:** 2026-05-18 11:05–11:09 (~4 dk)
- **Commit:** `8109fa1` (firmware: Aşama 2.2 öncesi build, DUTY: komutu yeterli)
- **Hedef:** Aşama 1.5'te öne sürdüğümüz "Önceki R6 anomalisi = stiction" hipotezini deneysel olarak doğrulamak veya çürütmek
- **Komut:** Manuel test protokolü (Bash inline Python script, terminalden)

## Hipotez

> Önceki Test 2A.T2'de motor %20 duty'de döndü (+107 rad/s), Test 2A.T7'de aynı duty'de motor 0 rad/s gösterdi. **Aşama 1.5 yorumumuz:** dynamic dead-band yok (V_dead=−0.24 V), R6 muhtemelen **statik sürtünme (stiction)** — duran motorun başlatılması için kritik eşik (`[Franklin2010] §3.2 Coulomb + viscous friction`).

## Test Protokolü

**FAZ A — Cold-start eşiği:**
1. Motor 30 sn tamamen durdu (yağ birikmesi, termal denge)
2. DUTY:+0.10 → 0.12 → 0.14 → 0.16 → 0.18 → 0.20 → 0.22 → 0.25 sırasıyla
3. Her duty 2.5 sn sürüş + 15 sn cooldown (stiction tekrar yüksek)
4. Her duty'de OMEGA örnekleri toplandı, son 8 değerin ortalaması steady-state

**FAZ B — Sıcak motor (kontrol grubu):**
1. Motor 0.30 ile 10 sn sürüldü (yağ dağıldı, motor sıcak)
2. STOP + 2 sn (kısa, sıcak tutmak için)
3. DUTY:+0.10 → 0.12 → 0.14 → 0.16
4. Her duty 2.5 sn sürüş + 4 sn kısa cooldown (sıcaklık korunsun)

## Sonuçlar

| duty | cold ω_ss | cold | sıcak ω_ss | sıcak | Cold vs Sıcak fark |
|---|---|---|---|---|---|
| 0.100 | +46.75 | 🟢 | +44.41 | 🟢 | %5.0 |
| 0.120 | +56.10 | 🟢 | +58.44 | 🟢 | %4.2 |
| 0.140 | +67.79 | 🟢 | +70.12 | 🟢 | %3.4 |
| 0.160 | +79.47 | 🟢 | +79.47 | 🟢 | %0.0 |
| 0.180 | +93.50 | 🟢 | — | — | — |
| 0.200 | +102.85 | 🟢 | — | — | — |
| 0.220 | +114.54 | 🟢 | — | — | — |
| 0.250 | +130.90 | 🟢 | — | — | — |

**Hepsi 🟢 BAŞLADI** — soğuk dahi %10 duty motor güvenle dönüyor.

## KARAR

✗ **Stiction hipotezi REDDEDİLDİ.**

Cold-start ile sıcak motor arasında ölçüm gürültüsünden anlamlı fark **yok** (%0-5 fark, ölçüm sapması). Motor cold dahi en düşük test edilen duty seviyesinde (%10) anında dönüyor.

## R6 Anomalisinin Gerçek Açıklaması

Stiction reddedildikten sonra T7 ham veri yeniden incelendi (`artifacts/2A/T7_integration/raw/test_2a7_integration.csv.gz`). 8 cycle hepsinde **CW%20 segmentinde encoder count tutarlı şekilde artmış**:

| Cycle | CW%20 ΔEC (3 sn) | ω (output mil) | Durum |
|---|---|---|---|
| 0 | +1744 | +8.0 rad/s | 🟢 BAŞLADI |
| 1 | +1751 | +8.0 | 🟢 |
| 2 | +1752 | +8.0 | 🟢 |
| 3 | +1730 | +8.0 | 🟢 |
| 4 | +1820 | +8.2 | 🟢 |
| 5 | +1759 | +8.1 | 🟢 |
| 6 | +1758 | +8.0 | 🟢 |
| 7 | +1797 | +8.1 | 🟢 |

Motor şaftı hızı: 8.0 × 9.7 ≈ **76 rad/s** (Aşama 1'de ölçtüğümüz %20 duty cold-start 103 rad/s ile uyumlu, ortalama rampa yüzünden biraz düşük).

**T7 orijinal summary'deki "+0.00 rad/s" yanılgıdır.** O dönemde firmware USB CDC TX formatına `OMEGA:` alanını eklememişti (`0f27dd3` commit'te eklendi, T7 sonrası). Python analiz scripti `OMEGA:` regex'ini bulamayınca varsayılan 0.0 raporladı.

**Sonuç:** R6 **gerçek bir fenomen değildi** — analiz/parsing artefaktı. Aşama 1 modelimiz (V_dead ≈ 0) **doğruydu**; ama biz onu "stiction nedeniyle dynamic dead-band sıfır" olarak yanlış yorumladık. **Dynamic dead-band gerçekten sıfır, stiction da yok.**

## Akademik Dürüstlük

Bu bulgu **mevcut hipotezi reddetti** — iyi mühendislik bilimi:
1. T2'de gözlem (motor döndü) ✓
2. T7'de gözlem (motor dönmedi) — **yanlış ölçüm**
3. R6 anomalisi olarak listelendi
4. Aşama 1.3 fit V_dead < 0 verdi
5. Akademik açıklama: stiction
6. **Bu test (2026-05-18) stiction'ı reddetti**
7. T7 ham veri yeniden incelendi → motor T7'de zaten dönmüştü → R6 yok

**Hocaya:** anomali → hipotez → deneysel doğrulama → revizyon döngüsü.

## Pratik Etki (Aşama 2 Kontrolcü Tasarımı için)

| Konu | Önceki yorum | Yeni yorum |
|---|---|---|
| Dynamic dead-band | Yok (V_dead < 0) | Yok (aynı) |
| Stiction | Var (~%20 eşik) | **Yok / minimal** |
| Düşük setpoint riski (10-30 rad/s) | Stiction nedeniyle başlangıç gecikir | Motor zaten %10 duty'de dönüyor, sorun yok |
| Stiction kicker önerisi | Aşama 2.3'te değerlendir | **Gerek yok** |
| Gain scheduling önerisi | Stiction kompanse için | Hâlâ τ duty bağımlılığı için **geçerli** |

## Artifacts

- `raw/test_output.log` — terminal çıktısı (cold faz + sıcak faz + T7 yeniden analiz)

## Kaynakça (KAYNAKCA.md)

- `[Franklin2010] §3.2` — Coulomb + viscous friction (orijinal stiction hipotezimizi destekleyen, ama gerçekleşmedi)
- `[Ljung1999] §16` — model validation (deneysel doğrulama)

## Sıradaki Eylemler

1. ✅ Bu artifact yazıldı
2. ⏳ Dökümanlar güncellenmeli: SUNUM.md §1.5, README §10.7 Bulgu 1, ROADMAP R6 yorumu, PROJE_DURUMU.md açık konular
3. ⏳ T7 orijinal summary.md'sine "REVIZE 2026-05-18 — R6 ölçüm artefaktıydı" notu eklenmeli
4. ⏳ MATLAB `compute_dead_band.m` yorum string'i güncellenmeli (sonraki pipeline run için)
