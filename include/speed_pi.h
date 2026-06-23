#ifndef SPEED_PI_H
#define SPEED_PI_H

#include <stdbool.h>

/* ============================================================================
 * Hız iç döngü PI kontrolcü (Aşama 2.2; Aşama 3.3'te instance-based)
 *
 * Tustin (bilinear) z-dönüşümü ile discrete-time ayrıştırma + back-calculation
 * anti-windup.
 *   ÇALIŞAN (deployed) kazanç: Kp=0.002, Ki=0.1 — ANALİTİK (doyum-kısıtı +
 *     doğru-plant pole placement; design_speed_pi_corrected.m, docs §11.11.3):
 *     Kp≈duty_max/ω_max (P-terimi doyumu aşmasın), ω_n=2/τ=33 → Ki=ω_n²τ/Kg, Kg=K·Vs=654.8.
 *     main.c'de yüklenen değer budur; SpeedPI_SetGains ile runtime ayarlanabilir.
 *   Orijinal 2.1 tasarımı (REFERANS, KULLANILMIYOR): pole_placement_conservative
 *     Kp=0.1163, Ki=4.0447, ζ=1.0, ω_n=60 rad/s — İKİ hata (yanlış plant K=53.89 yerine
 *     Kg=654.8; doyum yok sayıldı) → gerçek motorda bang-bang. matlab/.../results/2_1_speed_pi/
 *
 * Model: Aşama 1 motor parametreleri (karakterize ünite — rewire sonrası motor-2 ekseni)
 *   G(s) = K / (τs + 1),  K=53.89 rad/s/V, τ=60.5 ms
 *
 * Form: paralel — P + I integrator ayrı state'te tutulur, anti-windup için
 *   integrator'a back-calculation feedback uygulanır.
 *
 * Tustin integration adımı:
 *   i[k] = i[k-1] + Ki·Ts/2·(e[k] + e[k-1])     [AstromMurray2008 §10.2]
 *
 * Anti-windup back-calculation:
 *   u_unsat = Kp·e + i
 *   u_sat   = clamp(u_unsat, ±duty_max)
 *   i      += (Ts/T_t) · (u_sat − u_unsat)       [AstromMurray2008 §10.4]
 *   T_t     = T_i = Kp/Ki  (varsayılan tracking time)
 *
 * Çıktı: signed duty [-duty_max, +duty_max].
 *
 * INSTANCE-BASED (Aşama 3.3): tüm state SpeedPI_t içinde — her eksen kendi
 * örneğini taşır (g_axis[i].spi). Davranış tek-örnekli Aşama-2 koduyla birebir.
 * ============================================================================ */

typedef struct {
    float Kp;
    float Ki;
    float Ts;        /* Tustin SABIT adımı (s) — 0.005 (5 ms = 200 Hz nominal).
                      * Döngü Aşama 0-2'de ~7 ms (Ts/dt~0.71×) idi → ÖLÇÜLEN ~32 ms/~31 Hz (yavaşladı,
                      * neden açık §12.12.5) → efektif Ki ~0.16× = HP stick-slip kök-nedeni; bkz main.c notu */
    float duty_max;  /* saturation (0.50 = MOTOR_MAX_DUTY) */
    float T_t;       /* anti-windup tracking time (s) — tipik Kp/Ki */
} SpeedPI_Config;

typedef struct {
    SpeedPI_Config cfg;
    float integrator;
    float prev_error;
    float last_output;
    float setpoint_target;   /* kullanıcı komutu (SP_W) */
    float setpoint_actual;   /* slew-limited, PI'nin gördüğü */
    float slew_rate;         /* rad/s/s, 0 = slew kapalı (ani step) */
    bool  initialized;
} SpeedPI_t;

void  SpeedPI_Init(SpeedPI_t *h, const SpeedPI_Config *cfg);
void  SpeedPI_Reset(SpeedPI_t *h);          /* integrator = 0, prev_error = 0, setpoint = 0 */

/* Runtime kazanç ayarı (Aşama 2.3 — kazanç setlerini yeniden flash'sız dene).
 * T_t = Kp/Ki otomatik güncellenir (Kp=0 ise T_t değişmez). Integrator resetlenir. */
void  SpeedPI_SetGains(SpeedPI_t *h, float Kp, float Ki);
float SpeedPI_GetKp(const SpeedPI_t *h);
float SpeedPI_GetKi(const SpeedPI_t *h);

void  SpeedPI_SetSetpoint(SpeedPI_t *h, float omega_ref); /* rad/s, signed */
float SpeedPI_GetSetpoint(const SpeedPI_t *h);  /* USB TX SP: — slew sonrası gerçek uygulanan */
float SpeedPI_GetControl(const SpeedPI_t *h);   /* USB TX U: alanı için (son u_sat) */

/* Setpoint slew rate (Aşama 2.3 — ani step limit cycle'a sokuyordu).
 * rad/s/s; 0 = slew kapalı (ani step). Runtime SLEW: komutu ile ayarlanır. */
void  SpeedPI_SetSlewRate(SpeedPI_t *h, float rate_radps_per_s);
float SpeedPI_GetSlewRate(const SpeedPI_t *h);

/* Tek adım: error hesabı + P + I (Tustin) + anti-windup back-calculation.
 * omega_measured: motor şaftı hızı (rad/s, signed — encoder'dan).
 * Dönüş: signed duty komutu [-duty_max, +duty_max]. */
float SpeedPI_Step(SpeedPI_t *h, float omega_measured);

#endif /* SPEED_PI_H */
