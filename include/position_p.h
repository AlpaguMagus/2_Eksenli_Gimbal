#ifndef POSITION_P_H
#define POSITION_P_H

#include <stdint.h>

/* ============================================================================
 * Pozisyon dış döngü P kontrolcü (Aşama 2.5 — cascade)
 *
 * Cascade yapısı:
 *   θ_ref → (+) → [Kp_pos] → ω_ref → [hız PI iç döngü] → motor → θ
 *            ↑                                                    │
 *            └──────────────── pozisyon geri besleme ───────────┘
 *
 * Tasarım: matlab/asama_2_kontrol/design_position_p.m
 *   Kp_pos = 2.0 [1/s], dış döngü ω_c ≈ 1.93 rad/s — cascade kuralı gereği
 *   iç döngüden ~5× yavaş [Franklin2010] §6.4. PM 69.7°, GM 23 dB.
 *   (NOT: ilk analitik tahmin iç ω_n≈9.4 idi; Vsupply dahil gerçek iç ω_n≈33
 *    — root locus doğrulaması, docs §11.13.2b → ayrım ~16×, daha da güvenli.)
 *   Tip-1 sistem (plant'te entegratör) → P kontrolcü ile ss_error=0
 *   ([Franklin2010] §4.3), PI gereksiz (wind-up riski yok).
 *
 * Gerçekçi sim (verify_realistic_cascade.m, 12.15V doğru besleme):
 *   ss_err %1.75, OS %12.5, kararlı hal STABİL.
 *   ⚠ UYARI: simde küçük genlikli limit-cycle (θ 24-33° gezinme). Kök neden:
 *   iç hız döngüsü düşük hızda (~1 rad/s) encoder kuantizasyonuyla (18.7 rad/s)
 *   kör kalıyor. Simde statik sürtünme YOK — gerçek motorda sürtünme bu
 *   gezinmeyi söndürebilir. Test 2.5 ile gerçek motorda DOĞRULANACAK.
 *   Çıkarsa hedefli çözüm: hız penceresi büyüt / T-metodu hız ölçümü.
 *
 * Birim (firmware): θ çıkış mili rad, ω_ref motor şaftı rad/s.
 *   θ_out        = enc_count · 2π/466          (çıkış mili, 48×9.7 event/rev)
 *   ω_ref_motor  = Kp_pos · (θ_ref − θ_out) · 9.7   (redüktör ölçeği)
 *   ω_ref hız PI setpoint'ine yazılır; iç döngü motor şaftı hızı ölçer.
 * ============================================================================ */

typedef struct {
    float Kp_pos;          /* pozisyon P kazancı [1/s] (design_position_p.m: 2.0) */
    float gear_ratio;      /* redüktör (motor şaftı / çıkış mili) = 9.7 */
    float counts_per_rev;  /* çıkış mili event/rev = 466 (48×9.7) */
    float omega_ref_max;   /* ω_ref güvenlik limiti (rad/s, motor şaftı) */
} PositionP_Config;

void  PositionP_Init(const PositionP_Config *cfg);
void  PositionP_Reset(void);                /* setpoint + θ_out durumunu temizle */

void  PositionP_SetGain(float Kp_pos);      /* runtime KPP: komutu (flash'sız ayar) */
float PositionP_GetGain(void);

void  PositionP_SetSetpoint(float theta_ref_deg);  /* hedef çıkış mili açısı (derece) */
float PositionP_GetSetpoint(void);                 /* derece */

/* Bir adım: enc_count → ω_ref (rad/s, motor şaftı). Hız PI setpoint'ine verilir.
 *   theta_out_deg_out: ölçülen çıkış mili açısı (derece) — telemetri için, NULL olabilir. */
float PositionP_Step(int32_t enc_count, float *theta_out_deg_out);

float PositionP_GetThetaOut(void);          /* son ölçülen çıkış mili açısı (derece) */

#endif /* POSITION_P_H */
