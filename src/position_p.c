#include "position_p.h"

/* Detaylar → include/position_p.h */

#define TWO_PI   6.28318530717958647692f
#define RAD2DEG  (180.0f / 3.14159265358979f)
#define DEG2RAD  (3.14159265358979f / 180.0f)

static float kp_pos        = 2.0f;     /* design_position_p.m */
static float gear          = 9.7f;
static float cpr           = 466.0f;   /* çıkış mili event/rev */
static float omega_ref_max = 300.0f;   /* rad/s motor şaftı (duty ±0.5 cap zaten sınırlar) */

static float theta_ref_rad = 0.0f;     /* hedef çıkış mili açısı (rad) */
static float theta_out_deg = 0.0f;     /* son ölçülen çıkış mili açısı (derece) */

void PositionP_Init(const PositionP_Config *cfg)
{
    kp_pos        = cfg->Kp_pos;
    gear          = cfg->gear_ratio;
    cpr           = cfg->counts_per_rev;
    omega_ref_max = cfg->omega_ref_max;
    theta_ref_rad = 0.0f;
    theta_out_deg = 0.0f;
}

void PositionP_Reset(void)
{
    theta_ref_rad = 0.0f;
    theta_out_deg = 0.0f;
}

void PositionP_SetGain(float k) { if (k >= 0.0f) kp_pos = k; }
float PositionP_GetGain(void)   { return kp_pos; }

void  PositionP_SetSetpoint(float deg) { theta_ref_rad = deg * DEG2RAD; }
float PositionP_GetSetpoint(void)      { return theta_ref_rad * RAD2DEG; }

float PositionP_Step(int32_t enc_count, float *theta_out_deg_out)
{
    /* Ölçülen çıkış mili açısı (rad) — pozisyon ölçümü çözünürlüğü 2π/466 ≈ 0.0135 rad
     * (0.773°), hız ölçümünden 24× daha ince → kuantizasyona dayanıklı. */
    float theta_out = (float)enc_count * (TWO_PI / cpr);
    theta_out_deg   = theta_out * RAD2DEG;
    if (theta_out_deg_out) *theta_out_deg_out = theta_out_deg;

    /* P kontrolcü: çıkış mili açı hatası → çıkış mili hız referansı → motor şaftı */
    float e               = theta_ref_rad - theta_out;   /* çıkış mili rad */
    float omega_ref_out   = kp_pos * e;                  /* çıkış mili rad/s */
    float omega_ref_motor = omega_ref_out * gear;        /* motor şaftı rad/s */

    /* Güvenlik limiti (büyük açı adımında ω_ref patlamasın) */
    if (omega_ref_motor >  omega_ref_max) omega_ref_motor =  omega_ref_max;
    if (omega_ref_motor < -omega_ref_max) omega_ref_motor = -omega_ref_max;

    return omega_ref_motor;
}

float PositionP_GetThetaOut(void) { return theta_out_deg; }
