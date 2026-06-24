# Aşama 3.2b — Motor-2 Yön/Kimlik Doğrulama

- **Test ID:** 20260609_174135
- **Tarih:** 2026-06-09 17:41
- **Commit:** `63e50e9`
- **Hedef:** Motor-2 açık-döngü döner mi + EC2 okur mu + polarite (motor-1'e göre)?
- **Komut:** `python3 scripts/motor2_sign_test.py --duty 0.3 --hold 2.0`
- **NOT:** Serbest mil (yüksüz), denetimli. Motor-2 stall-lockout YOK (3.2b minimal sürücü).

## Sonuç (sayısal)

| Segment | Komut | rate (count/s) | işaret | süre | durum |
|---|---|---|---|---|---|
| motor-1 ref + | `DUTY:0.3` | +173 | + | 1.59s | ⚠ dönmedi |
| motor-2 ileri + | `DUTY2:0.3` | +1228 | + | 1.97s | 🟢 döndü |
| motor-2 geri - | `DUTY2:-0.3` | -1209 | - | 1.97s | 🟢 döndü |

- **Polarite:** **AYNI (varsayılan: +duty→+count)**
- eşik: |rate| > 200 count/s = 'döndü' (motor şaftı 192 CPR → ~1.0 dev/s)

## Durum: **PARTIAL**

## PASS/FAIL gerekçesi
⚠ Kısmi: bir yön dönmedi veya motor-1 referansı eksik. raw/data.csv incele.

## Artifacts
- `data.csv` (seg/EC/EC2/U2 zaman serisi)
- `motor2_sign_plot.png` (EC2 + U2 vs t)
