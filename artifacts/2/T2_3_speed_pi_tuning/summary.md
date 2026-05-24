# Aşama 2.3 — Hız PI Gerçek Motor Tuning + Sim-to-Real Gap

- **Test ID:** T2_3_speed_pi_tuning
- **Tarih:** 2026-05-24
- **Commit:** (bu commit)
- **Hedef:** Aşama 2.1 conservative kazançlarını gerçek motorda doğrulamak (Test 2.T2)
- **Sonuç:** ⚠ Conservative kazanç BANG-BANG verdi → kök neden bulundu → ampirik çözüldü

## Hikaye — gözlem → tanı → çözüm

### 1. İlk deneme: conservative (Kp=0.1163, Ki=4.0447) → BANG-BANG
Motor titredi, dönmedi. U sürekli ±0.5 saturation arasında zıpladı, ω +168/−112 arası savruldu (limit cycle).

### 2. İzolasyon: ölçüm mü kontrolcü mü?
| Durum | ω_std |
|---|---|
| Açık döngü (DUTY sabit) | **~7 rad/s** (temiz) |
| Kapalı döngü (SP_W, PI) | **97-173 rad/s** (çöp) |
→ Ölçüm temiz; bang-bang tamamen **kapalı-döngü limit cycle**.

### 3. Ad-hoc denemeler — hepsi başarısız
| Deneme | Sonuç |
|---|---|
| dt→DWT mikrosaniye (jitter giderme) | Yardımcı ama çözmedi (açık döngü zaten temizdi) |
| Encoder moving-average filtre (WINDOW=5) | Çözmedi |
| 5 kazanç seti (aggressive→saf I) | Hepsi bang-bang |
| Setpoint slew rate (0/100/200/400) | Çözmedi → ani-step değil |
| Motor_Tick bypass (doğrudan PWM) | Çözmedi → firmware akışı değil |

### 4. Setpoint taraması — KÖK NEDEN ortaya çıktı
Conservative kazanç, farklı setpoint (slew=200, Motor_Tick bypass):
| SP | ω_std | U_std | durum |
|---|---|---|---|
| 30 | 104.9 | 0.490 | 🔴 BANG |
| 80 | 98.6 | 0.490 | 🔴 BANG |
| 150 | 87.0 | 0.400 | 🔴 BANG |
| 220 | 60.3 | 0.367 | 🔴 BANG |
| **280** | **6.9** | **0.023** | **🟢 OTURDU** |

Setpoint arttıkça bang-bang azalıyor, 280'de (≈saturation duty) oturuyor. **Setpoint–saturation uyumsuzluğu**: serbest milde 0.5 duty ≈ 280 rad/s; düşük setpoint için (50, gereken duty 0.12) yüksek Kp her error'da saturation'a fırlatıyor → overshoot → limit cycle.

### 5. Düşük kazanç taraması — ÇÖZÜM
SP_W:50 sabit, slew=200, Motor_Tick bypass:
| Kp | Ki | ω_ss | ω_std | U_std | durum |
|---|---|---|---|---|---|
| 0.050 | 2.0 | +30.7 | 97.7 | 0.469 | 🔴 BANG |
| 0.010 | 0.5 | +34.4 | 101.4 | 0.445 | 🔴 BANG |
| 0.005 | 0.25 | +46.8 | 84.8 | 0.331 | 🔴 BANG |
| **0.002** | **0.1** | **+50.1** | **8.7** | **0.003** | **🟢 OTURDU (hata %0)** |
| 0.001 | 0.05 | +51.2 | 8.2 | 0.001 | 🟢 OTURDU (hata %2) |

### 6. Çok-setpoint doğrulama (Kp=0.002, Ki=0.1)
| Setpoint | ω_steady | U_steady |
|---|---|---|
| 50 rad/s | ~50 | 0.10 |
| 120 rad/s | ~120 | 0.22 |
| 30 rad/s | ~30 | 0.07 |
→ Hepsi temiz oturdu, bang-bang yok, setpoint takibi başarılı.

## Kök Neden (akademik)

**Sim-to-real gap.** Aşama 2.1 Simulink modeli:
- İdeal, gürültüsüz, gecikmesiz hız ölçümü
- Saturation vardı ama serbest mil dinamiği farklıydı

Gerçek sistem:
- Serbest mil (yüksüz) çok hızlı/hafif → 0.5 duty ≈ 280 rad/s
- Encoder kuantize (1 count ≈ 18.7 rad/s @ 7ms)
- Yüksek Kp (0.1163) → error=50'de P-term=5.8 >> saturation 0.5 → motor full power → overshoot → limit cycle

**Doğru kazanç ~58× daha düşük (Kp=0.002).** Bu, P-term'in error=50'de 0.1 kalmasını (saturation'ı aşmamasını) sağlıyor.

## Pratik Etki
- Firmware default kazancı Kp=0.002, Ki=0.1 olarak güncellendi (main.c)
- Runtime KP:/KI:/SLEW: komutları eklendi (flash'sız tuning)
- Encoder moving-average filtre + dt→DWT korundu (her durumda doğru iyileştirme)
- Motor_SetDutySigned eklendi (kapalı döngü için rampasız doğrudan PWM)

## 2b — Teorik Doğrulama ✅ (TAMAMLANDI)

`matlab/asama_2_kontrol/verify_realistic_sim.m` — Aşama 2.1 modeline gerçek
efektler (kuantizasyon + moving-avg filtre + saturation + slew + V_sat) eklendi.
Gerçekçi model her iki kazancı simüle etti:

| Kazanç | ω_std | u_std | Sonuç | Gerçek motor |
|---|---|---|---|---|
| conservative (Kp=0.1163) | 46.3 | 0.486 | BANG-BANG | ✅ aynı |
| ampirik (Kp=0.002) | 3.2 | 0.018 | STABİL | ✅ aynı |

**Sim-to-real gap teorik kapandı:** İdeal model conservative'i önerdi (yanlış);
gerçekçi model ampirik Kp=0.002'yi doğruluyor. Görsel:
`matlab/asama_2_kontrol/results/realistic_sim_verification.png`.

## Artifacts
- `../speed_gain_sweep/20260524_165718/` — 5 kazanç taraması (raw + meta)
- `../slew_sweep/20260524_170748/` — slew rate taraması (raw + meta)
- (setpoint + düşük-kazanç + doğrulama taramaları bu summary'de özetlendi)

## Kaynaklar
- `[AstromMurray2008] §10.2` Tustin, `§10.4` anti-windup
- `[Franklin2010] §6.4` pole placement (Aşama 2.1, sim-to-real gap kaynağı)
- `[Ljung1999] §16` model validation
