#include "speed_pi.h"

/* ============================================================================
 * Hız iç döngü PI — Tustin discrete-time + anti-windup back-calculation
 * API ve referanslar için → include/speed_pi.h
 * Instance-based (Aşama 3.3) — davranış tek-örnekli Aşama-2 koduyla birebir.
 * ============================================================================ */

void SpeedPI_Init(SpeedPI_t *h, const SpeedPI_Config *c)
{
    if (h == 0 || c == 0) return;
    h->cfg             = *c;
    h->integrator      = 0.0f;
    h->prev_error      = 0.0f;
    h->last_output     = 0.0f;
    h->setpoint_target = 0.0f;
    h->setpoint_actual = 0.0f;
    h->slew_rate       = 200.0f;   /* eski modül-static default (rad/s/s) */
    h->initialized     = true;
}

void SpeedPI_Reset(SpeedPI_t *h)
{
    h->integrator      = 0.0f;
    h->prev_error      = 0.0f;
    h->last_output     = 0.0f;
    h->setpoint_target = 0.0f;   /* STOP/mod geçişi: hedef de sıfırlanır (eski hıza fırlamasın) */
    h->setpoint_actual = 0.0f;
}

void  SpeedPI_SetSetpoint(SpeedPI_t *h, float r)  { h->setpoint_target = r; }
float SpeedPI_GetSetpoint(const SpeedPI_t *h)     { return h->setpoint_actual; }  /* telemetri: gerçek uygulanan */
float SpeedPI_GetControl(const SpeedPI_t *h)      { return h->last_output; }
void  SpeedPI_SetSlewRate(SpeedPI_t *h, float r)  { h->slew_rate = r; }
float SpeedPI_GetSlewRate(const SpeedPI_t *h)     { return h->slew_rate; }

void SpeedPI_SetGains(SpeedPI_t *h, float Kp, float Ki)
{
    h->cfg.Kp = Kp;
    h->cfg.Ki = Ki;
    /* Anti-windup tracking time (Aström-Murray §10.4):
     *   PI (Kp,Ki>0): T_t = T_i = Kp/Ki
     *   Saf I (Kp≈0):  T_t = 1/Ki  (T_i → 0 mantıksız olur, integral mertebesi)
     *   Saf P (Ki≈0):  T_t = 0 → back-calculation devre dışı */
    if (Ki > 1e-6f && Kp > 1e-4f) {
        h->cfg.T_t = Kp / Ki;
    } else if (Ki > 1e-6f) {
        h->cfg.T_t = 1.0f / Ki;       /* saf I anti-windup */
    } else {
        h->cfg.T_t = 0.0f;            /* saf P — back-calc gereksiz */
    }
    SpeedPI_Reset(h);
}
float SpeedPI_GetKp(const SpeedPI_t *h) { return h->cfg.Kp; }
float SpeedPI_GetKi(const SpeedPI_t *h) { return h->cfg.Ki; }

float SpeedPI_Step(SpeedPI_t *h, float omega_measured)
{
    if (!h->initialized) return 0.0f;

    /* Setpoint slew rate limit (Aşama 2.3):
     * Ani step (0→50 rad/s) PI'yi saturation'a fırlatıp serbest milde limit
     * cycle'a sokuyordu. Yumuşak rampa ile setpoint_actual hedefe yaklaşır.
     * slew_rate = 0 → slew kapalı (ani step, karşılaştırma için). */
    if (h->slew_rate > 0.0f) {
        float max_step = h->slew_rate * h->cfg.Ts;
        float d = h->setpoint_target - h->setpoint_actual;
        if (d >  max_step)      h->setpoint_actual += max_step;
        else if (d < -max_step) h->setpoint_actual -= max_step;
        else                    h->setpoint_actual  = h->setpoint_target;
    } else {
        h->setpoint_actual = h->setpoint_target;
    }

    /* Hata */
    float error = h->setpoint_actual - omega_measured;

    /* P bileşeni */
    float u_p = h->cfg.Kp * error;

    /* I bileşeni — Tustin (bilinear) integration:
     *   i[k] = i[k-1] + Ki·Ts/2·(e[k] + e[k-1])
     * [AstromMurray2008 §10.2] */
    h->integrator += h->cfg.Ki * h->cfg.Ts * 0.5f * (error + h->prev_error);

    /* Doyumsuz çıkış */
    float u_unsat = u_p + h->integrator;

    /* Signed saturation ±duty_max (firmware MOTOR_MAX_DUTY = 0.50) */
    float u_sat = u_unsat;
    if (u_sat >  h->cfg.duty_max) u_sat =  h->cfg.duty_max;
    if (u_sat < -h->cfg.duty_max) u_sat = -h->cfg.duty_max;

    /* Anti-windup back-calculation [AstromMurray2008 §10.4]:
     *   i += (Ts/T_t)·(u_sat − u_unsat)
     * T_t = Kp/Ki  (klasik tracking time seçimi)
     * Saturasyon yokken (u_sat == u_unsat) düzeltme sıfır. */
    if (h->cfg.T_t > 0.0f) {
        h->integrator += (h->cfg.Ts / h->cfg.T_t) * (u_sat - u_unsat);
    }

    h->prev_error  = error;
    h->last_output = u_sat;
    return u_sat;
}
