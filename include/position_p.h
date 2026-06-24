#ifndef POSITION_P_H
#define POSITION_P_H

#include <stdint.h>

/* ============================================================================
 * Pozisyon dış döngü P kontrolcü (Aşama 2.5 — cascade; Aşama 3.3'te instance-based)
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
 * Gerçek motor doğrulaması: Test 2.5 PASS (6/6 segment, ss_err<0.8°, OS<1°,
 *   limit-cycle YOK — sürtünme simdeki gezinmeyi söndürdü, docs §11.13.6).
 *
 * Birim (firmware): θ çıkış mili rad, ω_ref motor şaftı rad/s.
 *   θ_out        = enc_count · 2π/466          (çıkış mili, 48×9.7 event/rev)
 *   ω_ref_motor  = Kp_pos · (θ_ref − θ_out) · 9.7   (redüktör ölçeği)
 *   ω_ref hız PI setpoint'ine yazılır; iç döngü motor şaftı hızı ölçer.
 *
 * INSTANCE-BASED (Aşama 3.3): tüm state PositionP_t içinde — her eksen kendi
 * örneğini taşır (g_axis[i].ppos). Davranış tek-örnekli Aşama-2 koduyla birebir.
 * ============================================================================ */

typedef struct {
    float Kp_pos;          /* pozisyon P kazancı [1/s] (design_position_p.m: 2.0) */
    float gear_ratio;      /* redüktör (motor şaftı / çıkış mili) = 9.7 */
    float counts_per_rev;  /* çıkış mili event/rev = 466 (48×9.7) */
    float omega_ref_max;   /* ω_ref güvenlik limiti (rad/s, motor şaftı) */
} PositionP_Config;

typedef struct {
    PositionP_Config cfg;
    float theta_ref_rad;   /* hedef çıkış mili açısı (rad) */
    float theta_out_deg;   /* son ölçülen çıkış mili açısı (derece) */
} PositionP_t;

void  PositionP_Init(PositionP_t *h, const PositionP_Config *cfg);
void  PositionP_Reset(PositionP_t *h);          /* setpoint + θ_out durumunu temizle */

void  PositionP_SetGain(PositionP_t *h, float Kp_pos);  /* runtime KPP: komutu */
float PositionP_GetGain(const PositionP_t *h);

void  PositionP_SetSetpoint(PositionP_t *h, float theta_ref_deg);  /* hedef çıkış mili açısı (derece) */
float PositionP_GetSetpoint(const PositionP_t *h);                 /* derece */

/* Bir adım: enc_count → ω_ref (rad/s, motor şaftı). Hız PI setpoint'ine verilir.
 *   theta_out_deg_out: ölçülen çıkış mili açısı (derece) — telemetri için, NULL olabilir. */
float PositionP_Step(PositionP_t *h, int32_t enc_count, float *theta_out_deg_out);

float PositionP_GetThetaOut(const PositionP_t *h);  /* son ölçülen çıkış mili açısı (derece) */

#endif /* POSITION_P_H */
