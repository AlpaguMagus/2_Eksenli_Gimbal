# HP step-ID clean capture — τ_HP ≈ 400 ms (SÜRÜCÜ-domeni) + dropout

- **Test ID:** hp_stepid_20260615_024718_clean
- **Tarih:** 2026-06-15 02:47
- **Koşul:** eksen-0 HP, HW-039/BTS7960 20 kHz, 20:1, serbest mil; T_US (µs) zamanlı, ~31 Hz
- **Komut:** `python3` (T_US clean capture) → `matlab hp_identify` (tfest, başarısız) → ham ω(t) incelemesi

## Bulgu (KRİTİK)
**τ_HP ≈ 400 ms — GERÇEK, ölçüm artefaktı DEĞİL.** Ham ω(t) (0.30→0.50 step, EC-türevi, T_US):

| t (ms) | ω (rad/s) |
|---|---|
| <0 (pre) | ~295 |
| 0 (step) | dip ~200 |
| 96 | 311 |
| 224 | 362 |
| 416 | 423 (~%63) |
| 608 | 492 |
| **771** | **125 → 0 (DROPOUT, EC dondu)** |

%63 yükseliş ~416 ms → **τ ≈ 400 ms**. ω yavaş yükseliyor (motorun mekanik τ'su ~60 ms olurdu).

## Yorum
1. **τ ≈ 400 ms motor değil, HW-039/BTS7960 SÜRÜCÜ kaynaklı** (slew/filtreleme). Motor+gearbox mekanik
   τ'su bu mertebede olmaz (LP 60.5 ms; K=Kt·Ke arttıkça back-EMF damping τ'yu KÜÇÜLTÜR, büyütmez).
2. **Step ortasında dropout** (771 ms'de EC dondu) — aralıklı sorun (startup-stiction değil, çalışırken kesildi).
3. **MATLAB `tfest` başarısız** (ω=dEC/dt türev gürültüsü → Kg negatif, fit %5-15). Doğru yöntem:
   pozisyon-fit (EC(t) → 1.mertebe integral) — Python ile τ≈420 ms tutarlı verdi (3 rep).

## Sonuç & açık karar
- **K_HP=83.35 rad/s/V SAĞLAM** (kazanç sorunsuz). **τ_eff ≈ 400 ms sürücü-domeni → HP ekseni ÇOK YAVAŞ (~0.4 Hz)** + aralıklı dropout → hızlı kontrol için kötü.
- **Açık:** τ frekans-bağımlı mı (BTS7960 20 kHz'de slew-limitli filtreleme) yoksa sürücü-inherent mi?
  → PWM-freq sweep ile step-τ ölç (5/10/15/20 kHz) — karar verir. Veya LP'yi HW-039'da test et (sürücü izolasyonu).

## Artifacts
- `raw/data.csv` (688 satır, T_US zamanlı)
- (MATLAB plot `results/3_hp_id/hp_step_id.png` — tfest başarısız, yöntem düzeltilecek)
