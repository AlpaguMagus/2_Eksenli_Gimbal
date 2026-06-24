# 3.HP-dropout-fix — Bulk kapasitör dropout doğrulama (kapasitörlü temiz step-ID)

- **Test ID:** 3.HP-clean-DUTYR (dropout-fix doğrulama koşusu)
- **Tarih:** 2026-06-23 11:39
- **Commit:** 4d9ed83
- **Hedef:** ~940µF low-ESR bulk kapasitör (2×470µF/25V paralel) HW-039 B+/B−'a takıldıktan sonra **0.50 step dropout'unun çözülüp çözülmediğini** doğrulamak + temiz τ63 ölçmek.
- **Donanım:** HP Pololu motor, HW-039/BTS7960 sürücü, Sagemcom CS50001 12V adaptör, **mil serbest**. Kapasitör konfig (kanonik: `docs/00_donanim_semasi.md §4.1`): B+/B− 2×470µF/25V (~940µF bulk), M+/M− 0.1µF (104) seramik, VCC/GND 0.1µF (104) seramik.
- **Komut:** `python3 scripts/hp_stepid_clean.py` (DUTYR rampasız: kick 0.48 → base 0.40 → step 0.50) + `python3 scripts/hp_observe.py` (0.40/4s → 0.50/4s gözlem)

## Sonuç (sayısal)
| Metric | Değer | Beklenen (fix başarılı) | Durum |
|---|---|---|---|
| base ω (DUTYR:0.40) | 2977 cnt/s | >400 (RUNNING) | ✓ |
| new ω (DUTYR:0.50) | 3764 cnt/s | base'den yüksek | ✓ |
| τ63 (0.40→0.50) | 76 ms (script 75.5, ham-veri el-doğrulama 76) | <100 ms (HW-039 hızlı) | ✓ |
| 0.50 step dropout | YOK (EC kesintisiz; hp_observe ΔEC +14018/4s) | dropout YOK | ✓ |

## PASS/FAIL gerekçesi
**PASS.** Kapasitörsüz durumda 0.50 step'inde adaptör OCP-hiccup tetikleniyordu (EC ~74ms'te donuyor, ω→0 kalıcı). ~940µF bulk (2×470µF/25V) takıldıktan sonra iki bağımsız test yakınsadı: (1) `hp_observe` 0.40→0.50 boyunca EC kesintisiz ~1900 cnt/0.5s arttı, hiç donma yok; (2) `hp_stepid_clean` temiz τ63=76ms ölçtü (ham step.csv'den el-doğrulandı: ω base 2977 → 63%-hedef 3474 cnt/s'i 76ms'te geçti → settle 3764). Mekanizma: bulk, ms-ölçekli inrush'ı yerelden besler → Sagemcom adaptör >6A spike görmez → OCP tetiklenmez.

⚠ **Kapsam sınırı (dürüst):** Bu test yalnız **0.50 step'inin geçici inrush'ını** doğruladı. Bulk kapasitör **sürekli akım tavanını YÜKSELTMEZ** — daha yüksek duty / gerçek stall (5.6A sürekli) için ≥6-7A / CC-capable besleme hâlâ gerçek fix. Tam operasyon zarfı (kapalı-çevrim + bozucu reddi) besleme yükseltmesi gerektirir.

## Artifacts
- `meta.json` (makine-okur, PASS, key_metrics)
- `raw/base.csv` (1.2 KB, settle fazı EC-zaman)
- `raw/step.csv` (847 B, 0.40→0.50 step EC-zaman; τ63 buradan el-doğrulandı)

## İlgili
- Teşhis kaydı: `docs/asama_3_mimo_model.md §12.11.6` (dropout ÇÖZÜLDÜ maddesi)
- Kök-neden: `[Sagemcom_PSU]` OCP-hiccup (`KAYNAKCA.md`), `motor-noise-dropout-literatur` workflow
- Üreten betikler: `scripts/hp_stepid_clean.py`, `scripts/hp_observe.py`
