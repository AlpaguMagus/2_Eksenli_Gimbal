#include "speed_pi.h"
#include <stdbool.h>

/* ============================================================================
 * Hız iç döngü PI — Tustin discrete-time + anti-windup back-calculation
 * API ve referanslar için → include/speed_pi.h
 * ============================================================================ */

static SpeedPI_Config cfg             = { 0 };
static float          integrator      = 0.0f;
static float          prev_error      = 0.0f;
static float          last_output     = 0.0f;
static float          setpoint_target = 0.0f;   /* kullanıcı komutu (SP_W) */
static float          setpoint_actual = 0.0f;   /* slew-limited, PI'nin gördüğü */
static float          slew_rate       = 200.0f; /* rad/s/s, 0 = slew kapalı (ani step) */
static bool           initialized     = false;

void SpeedPI_Init(const SpeedPI_Config *c)
{
    if (c == 0) return;
    cfg             = *c;
    integrator      = 0.0f;
    prev_error      = 0.0f;
    last_output     = 0.0f;
    setpoint_target = 0.0f;
    setpoint_actual = 0.0f;
    initialized     = true;
}

void SpeedPI_Reset(void)
{
    integrator      = 0.0f;
    prev_error      = 0.0f;
    last_output     = 0.0f;
    setpoint_target = 0.0f;   /* STOP/mod geçişi: hedef de sıfırlanır (eski hıza fırlamasın) */
    setpoint_actual = 0.0f;
}

void  SpeedPI_SetSetpoint(float r)   { setpoint_target = r; }
float SpeedPI_GetSetpoint(void)      { return setpoint_actual; }  /* telemetri: gerçek uygulanan */
float SpeedPI_GetControl(void)       { return last_output; }
void  SpeedPI_SetSlewRate(float r)   { slew_rate = r; }
float SpeedPI_GetSlewRate(void)      { return slew_rate; }

void SpeedPI_SetGains(float Kp, float Ki)
{
    cfg.Kp = Kp;
    cfg.Ki = Ki;
    /* Anti-windup tracking time (Aström-Murray §10.4):
     *   PI (Kp,Ki>0): T_t = T_i = Kp/Ki
     *   Saf I (Kp≈0):  T_t = 1/Ki  (T_i → 0 mantıksız olur, integral mertebesi)
     *   Saf P (Ki≈0):  T_t = 0 → back-calculation devre dışı */
    if (Ki > 1e-6f && Kp > 1e-4f) {
        cfg.T_t = Kp / Ki;
    } else if (Ki > 1e-6f) {
        cfg.T_t = 1.0f / Ki;          /* saf I anti-windup */
    } else {
        cfg.T_t = 0.0f;               /* saf P — back-calc gereksiz */
    }
    SpeedPI_Reset();
}
float SpeedPI_GetKp(void) { return cfg.Kp; }
float SpeedPI_GetKi(void) { return cfg.Ki; }

float SpeedPI_Step(float omega_measured)
{
    if (!initialized) return 0.0f;

    /* Setpoint slew rate limit (Aşama 2.3):
     * Ani step (0→50 rad/s) PI'yi saturation'a fırlatıp serbest milde limit
     * cycle'a sokuyordu. Yumuşak rampa ile setpoint_actual hedefe yaklaşır.
     * slew_rate = 0 → slew kapalı (ani step, karşılaştırma için). */
    if (slew_rate > 0.0f) {
        float max_step = slew_rate * cfg.Ts;
        float d = setpoint_target - setpoint_actual;
        if (d >  max_step)      setpoint_actual += max_step;
        else if (d < -max_step) setpoint_actual -= max_step;
        else                    setpoint_actual  = setpoint_target;
    } else {
        setpoint_actual = setpoint_target;
    }

    /* Hata */
    float error = setpoint_actual - omega_measured;

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
