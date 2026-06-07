# stall_fix bench doğrulaması — count-tabanlı tespit + 1 sn oto-toparlanma

- **Test ID:** 2.stall_fix (2A.T5-B gerçek-motor stall doğrulamasını da kapatır)
- **Tarih:** 2026-06-07 17:47
- **Commit (firmware):** `0376605` (count-based stall c63e9cb + IMUDIAG 0376605)
- **Hedef:** (1) yavaş/sert takipte yanlış-pozitif YOK, (2) gerçek stall ≤200 ms tespit,
  (3) engel kalkınca ~1 sn oto-devam ("sistem çalışmayı bırakmasın")
- **Komut:** mirror_test.py (A) + inline SP_W/POS koşucuları (B/B3, raw/ logları)

## Sonuç (sayısal)
| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| Yanlış-pozitif (A: 35 s, span 101°, ~80°/s sert dönüşler dahil) | 0 olay | 0 | ✓ |
| Yüklü-ama-dönen ayrımı (B: u=0.50 doyumda ~11 s süren kavrama) | tetiklenmedi | tetiklenmemeli | ✓ |
| Gerçek stall tespiti (B + B3) | 3/3 olay | her kilitte | ✓ |
| Engel sürerken davranış (B3) | kes→1 sn→dene döngüsü (2 ardışık olay) | ölü kalmamalı | ✓ |
| Oto-devam süresi (B3, bırakma sonrası) | **+1.02 s / +1.25 s** | ~1 s | ✓ |
| SP_W stall sonrası | durur, yeni komut bekler | tasarım (speed_pi.c:35 anti-lurch) | ✓ (bilinçli) |

## PASS/FAIL gerekçesi
PASS — üç hedefin üçü gerçek motorda sayısal kanıtla karşılandı. Not 1: Test A mirror
artifact'i (testA_count_stall_yavas) RMS kriterinde 5.8°>5° gösterir; bu STALL değil
TEMPO artefaktıdır (dönüşler ~80°/s = belgeli bant-limiti rejimi; takip kalitesi kanıtı
ayrı koşuda: 4.02° PASS, 20260531_174740). Bu artifact'in konusu stall davranışıdır:
stall=False. Not 2: B2 koşusunda "dönmüyor" gözlemi yanlış alarmdı — 120° adım 2.5 s'de
bitmişti; insan-koreografisi için B3 (sürekli döngü) tasarlandı.

## Artifacts
- raw/testA_mirror_yavas_sert.log — span 101°, stall:False
- raw/testB_spw_gercek_stall.log — yüklü-dönen + ilk gerçek kesim
- raw/testB2_pos_step.log — (hızlı-adım gözlem dersi)
- raw/testB3_pos_dongusu.log — kes→dene döngüsü + oto-devam kanıtı
