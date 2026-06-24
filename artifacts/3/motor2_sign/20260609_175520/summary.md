# Aşama 3.2b — Motor-2 Yön/Kimlik Doğrulama

- **Test ID:** 20260609_175520
- **Tarih:** 2026-06-09 17:55
- **Commit:** `63e50e9`
- **Hedef:** Motor-2 açık-döngü döner mi + EC2 okur mu + polarite (motor-1'e göre)?
- **Komut:** `python3 scripts/motor2_sign_test.py --duty 0.3 --hold 2.0`
- **NOT:** Serbest mil (yüksüz), denetimli. Motor-2 stall-lockout YOK (3.2b minimal sürücü).

## Sonuç (sayısal)

| Segment | Komut | rate (count/s) | işaret | süre | durum |
|---|---|---|---|---|---|
| motor-2 ileri + | `DUTY2:0.3` | +1203 | + | 1.6s | 🟢 döndü |
| motor-2 geri - | `DUTY2:-0.3` | -1199 | - | 1.97s | 🟢 döndü |

- **Polarite:** **AYNI (varsayılan: +duty→+count)**
- eşik: |rate| > 200 count/s = 'döndü' (motor şaftı 192 CPR → ~1.0 dev/s)

## Durum: **PASS**

## PASS/FAIL gerekçesi
🟢 Motor-2 her iki yönde döndü, encoder-2 (EC2) okudu, işaretler ZIT (kendi-içinde tutarlı), motor-1 referansı da döndü. Polarite saptandı.

✓ **POLARİTE AYNI** → Aşama 2 cascade'i motor-2'ye işaret değişikliği olmadan yeniden kullanılabilir (3.3 baseline).

## Artifacts
- `data.csv` (seg/EC/EC2/U2 zaman serisi)
- `motor2_sign_plot.png` (EC2 + U2 vs t)
