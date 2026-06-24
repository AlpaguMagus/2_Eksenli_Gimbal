# HP/HW-039 sürücü yavaşlık teşhisi — PWM-freq sweep + decay analizi

- **Tarih:** 2026-06-15 · **Eksen-0** HP + HW-039/BTS7960, 20:1, serbest mil
- **Soru:** τ_eff≈450ms yavaşlık (LP'nin 7×'i) sürücü-yazılımıyla düzeltilebilir mi?
- **Komut:** `/tmp/hp_freq_sweep.py`, `/tmp/hp_lowfreq.py` (runtime `BTSPWM:<psc>:<arr>`)

## Kullanıcı hipotezleri — test edildi
**#1 Decay modu (EN'e PWM → coast/fast-decay):** ELENDİ. Firmware ZATEN doğru: EN(PB14) sabit GPIO HIGH,
PWM RPWM/LPWM'de; CW'de LPWM=0 sabit → RPWM off-time'da iki low-side iletir = **slow-decay/fren** (`src/motor.c:68-89`).

**#2 PWM freq / dead-time / slew (yüksek freq duty yer):** ELENDİ. Temiz full-rise t63 (0.30→0.50):

| freq | t63 (ms) | ωf |
|---|---|---|
| 1 kHz | 515 | 493 |
| 2 kHz | 466 | 493 |
| 20 kHz | 448 | 503 |

→ **FREQ-BAĞIMSIZ** (~450-500ms her freq'te; 20kHz hatta biraz hızlı). Düşük-freq HIZLANDIRMIYOR. #2 yanlış.

## Sonuç
- **τ_eff ≈ 450-500ms SABİT** — decay (doğru) + freq (etkisiz) tükendi → **HW-039 yazılımla hızlandırılamaz.**
- Sabit + freq-bağımsız → muhtemel **donanım:** BTS7960 SR slew-direnci (modülde) veya giriş RC-filtresi.
  Motorun mekanik τ'su ~60ms olur (b_emf=Kt·Ke/R'den); 450ms motor değil sürücü/modül.
- Vcc=5V (doğru, kullanıcı teyit). Sürüş mantığı doğru. **Datasheet (handsontec) detaylı slew/dead-time vermiyor** (Infineon IC sheet'i gerek).
- **Aralıklı dropout** ayrıca sürüyor (yön-bağımsız).

## Sıradaki (alternatif)
HW-039 yazılımla optimize — bitti. **Karar: HP'yi TB6612'de test et** (hızlı sürücü, slew yok → ~60ms beklenir).
Akım: HP stall 5.6A > TB6612 ama duty-cap %50→2.8A < TB6612 3.2A peak; gimbal yükü hafif/dengeli → düşük normal akım.
Eğer TB6612 hızlıysa → HP'yi TB6612'de sür (akım dikkatli). Slow kalırsa → motor+gearbox (kabul/farklı redüktör).

## Artifacts
- `/tmp/hp_freq_sweep.log`, `/tmp/hp_lowfreq.log` (raw konsol)
- Runtime araç: `BTSPWM:<psc>:<arr>` komutu (firmware'de kalıcı)
