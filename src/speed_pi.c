#include "speed_pi.h"
#include <stdbool.h>

/* ============================================================================
 * Hız iç döngü PI — Tustin discrete-time + anti-windup back-calculation
 * API ve referanslar için → include/speed_pi.h
 * ============================================================================ */

static SpeedPI_Config cfg          = { 0 };
static float          integrator   = 0.0f;
static float          prev_error   = 0.0f;
static float          last_output  = 0.0f;
static float          setpoint     = 0.0f;
static bool           initialized  = false;

void SpeedPI_Init(const SpeedPI_Config *c)
{
    if (c == 0) return;
    cfg          = *c;
    integrator   = 0.0f;
    prev_error   = 0.0f;
    last_output  = 0.0f;
    setpoint     = 0.0f;
    initialized  = true;
}

void SpeedPI_Reset(void)
{
    integrator  = 0.0f;
    prev_error  = 0.0f;
    last_output = 0.0f;
    /* setpoint korunur — kullanıcı yeniden göndermek zorunda kalmasın */
}

void SpeedPI_SetSetpoint(float r) { setpoint = r; }
float SpeedPI_GetSetpoint(void)   { return setpoint; }
float SpeedPI_GetControl(void)    { return last_output; }

float SpeedPI_Step(float omega_measured)
{
    if (!initialized) return 0.0f;

    /* Hata */
    float error = setpoint - omega_measured;

    /* P bileşeni */
    float u_p = cfg.Kp * error;

    /* I bileşeni — Tustin (bilinear) integration:
     *   i[k] = i[k-1] + Ki·Ts/2·(e[k] + e[k-1])
     * [AstromMurray2008 §10.2] */
    integrator += cfg.Ki * cfg.Ts * 0.5f * (error + prev_error);

    /* Doyumsuz çıkış */
    float u_unsat = u_p + integrator;

    /* Signed saturation ±duty_max (firmware MOTOR_MAX_DUTY = 0.50) */
    float u_sat = u_unsat;
    if (u_sat >  cfg.duty_max) u_sat =  cfg.duty_max;
    if (u_sat < -cfg.duty_max) u_sat = -cfg.duty_max;

    /* Anti-windup back-calculation [AstromMurray2008 §10.4]:
     *   i += (Ts/T_t)·(u_sat − u_unsat)
     * T_t = Kp/Ki  (klasik tracking time seçimi)
     * Saturasyon yokken (u_sat == u_unsat) düzeltme sıfır. */
    if (cfg.T_t > 0.0f) {
        integrator += (cfg.Ts / cfg.T_t) * (u_sat - u_unsat);
    }

    prev_error  = error;
    last_output = u_sat;
    return u_sat;
}
