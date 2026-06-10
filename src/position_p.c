#include "position_p.h"

/* Detaylar → include/position_p.h
 * Instance-based (Aşama 3.3) — davranış tek-örnekli Aşama-2 koduyla birebir. */

#define TWO_PI   6.28318530717958647692f
#define RAD2DEG  (180.0f / 3.14159265358979f)
#define DEG2RAD  (3.14159265358979f / 180.0f)

void PositionP_Init(PositionP_t *h, const PositionP_Config *cfg)
{
    if (h == 0 || cfg == 0) return;
    h->cfg           = *cfg;
    h->theta_ref_rad = 0.0f;
    h->theta_out_deg = 0.0f;
}

void PositionP_Reset(PositionP_t *h)
{
    h->theta_ref_rad = 0.0f;
    h->theta_out_deg = 0.0f;
}

void  PositionP_SetGain(PositionP_t *h, float k) { if (k >= 0.0f) h->cfg.Kp_pos = k; }
float PositionP_GetGain(const PositionP_t *h)    { return h->cfg.Kp_pos; }

void  PositionP_SetSetpoint(PositionP_t *h, float deg) { h->theta_ref_rad = deg * DEG2RAD; }
float PositionP_GetSetpoint(const PositionP_t *h)      { return h->theta_ref_rad * RAD2DEG; }

float PositionP_Step(PositionP_t *h, int32_t enc_count, float *theta_out_deg_out)
{
    /* Savunma: Init çağrılmamış (zero-init) örnekte cpr=0 → sıfıra bölme/NaN
     * üretmesin (davranış-denetimi 2026-06-11; eski modül-static kodda compile-time
     * default'lar vardı, struct'ta yok). main.c Init'i her eksene garanti çağırır. */
    if (h->cfg.counts_per_rev <= 0.0f) {
        if (theta_out_deg_out) *theta_out_deg_out = 0.0f;
        return 0.0f;
    }

    /* Ölçülen çıkış mili açısı (rad) — pozisyon ölçümü çözünürlüğü 2π/466 ≈ 0.0135 rad
     * (0.773°), hız ölçümünden 24× daha ince → kuantizasyona dayanıklı. */
    float theta_out  = (float)enc_count * (TWO_PI / h->cfg.counts_per_rev);
    h->theta_out_deg = theta_out * RAD2DEG;
    if (theta_out_deg_out) *theta_out_deg_out = h->theta_out_deg;

    /* P kontrolcü: çıkış mili açı hatası → çıkış mili hız referansı → motor şaftı */
    float e               = h->theta_ref_rad - theta_out;   /* çıkış mili rad */
    float omega_ref_out   = h->cfg.Kp_pos * e;               /* çıkış mili rad/s */
    float omega_ref_motor = omega_ref_out * h->cfg.gear_ratio; /* motor şaftı rad/s */

    /* Güvenlik limiti (büyük açı adımında ω_ref patlamasın) */
    if (omega_ref_motor >  h->cfg.omega_ref_max) omega_ref_motor =  h->cfg.omega_ref_max;
    if (omega_ref_motor < -h->cfg.omega_ref_max) omega_ref_motor = -h->cfg.omega_ref_max;

    return omega_ref_motor;
}

float PositionP_GetThetaOut(const PositionP_t *h) { return h->theta_out_deg; }
