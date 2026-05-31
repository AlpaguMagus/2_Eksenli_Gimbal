#ifndef MOTOR_H
#define MOTOR_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * TB6612FNG Motor Sürücü API
 *
 * Donanım:
 *   PB0  → TIM3_CH3 PWM (20 kHz, 4800 step)
 *   PB12 → AIN1  (yön)
 *   PB13 → AIN2  (yön)
 *   PB14 → STBY  (enable)
 *
 * H-SW kontrol mantığı (TB6612FNG datasheet sf 4):
 *   AIN1=H, AIN2=L  → CW   (ileri)
 *   AIN1=L, AIN2=H  → CCW  (geri)
 *   AIN1=H, AIN2=H  → BRAKE (kısa devre fren)
 *   AIN1=L, AIN2=L  → STOP  (Hi-Z, free-wheel)
 *   STBY=L          → tüm sürücü standby
 *
 * Dahili dead-time (datasheet sf 5: 50 ns H→L, 230 ns L→H):
 *   Yön değiştirmede yazılım dead-band gerekmiyor — donanım hallediyor.
 *
 * Init sırası (main.c):
 *   1) Motor_Init()    — STBY=LOW kalır, motor güvenli kapalı
 *   2) (diğer init'ler ve HAL_Delay)
 *   3) Motor_Enable()  — STBY=HIGH (en sonda, kazara seğirme önlenir)
 *
 * Soft-start: ani yüklenmeyi önlemek için PWM'i 0'dan hedef değere
 *             ~200 ms içinde lineer rampa ile çıkar.
 * ============================================================================ */

typedef enum {
    MOTOR_CW    = 0,   /* AIN1=H, AIN2=L */
    MOTOR_CCW   = 1,   /* AIN1=L, AIN2=H */
    MOTOR_BRAKE = 2,   /* AIN1=H, AIN2=H */
    MOTOR_STOP  = 3    /* AIN1=L, AIN2=L (Hi-Z) */
} MotorDir_t;

void  Motor_Init(void);                       /* Pinler init, STBY=LOW */
void  Motor_Enable(void);                     /* STBY=HIGH */
void  Motor_Disable(void);                    /* STBY=LOW */

void  Motor_SetDir(MotorDir_t dir);
void  Motor_SetDuty(float duty01);            /* clamp [0, MOTOR_MAX_DUTY], rampa+dead-band (açık döngü) */
void  Motor_SetDutySigned(float duty);        /* signed, RAMPA YOK — kapalı döngü PI için (Aşama 2.3) */
void  Motor_Tick(void);                       /* main loop'tan her iterasyon (~140 Hz) çağrılır (açık döngü rampa) */

void  Motor_SoftStart(float target_duty01);   /* bloklayan ~200 ms rampa, init için */
void  Motor_Stop(void);                       /* PWM=0, dir=STOP */
void  Motor_EmergencyStop(void);              /* STBY=L + duty=0 + AIN=0 */

/* ── Stall detection / lockout ────────────────────────────────────────────
 * Tetik: |speed| < 2 rad/s VE current_duty > 0.20 VE 200 ms süre.
 * Rampa sırasında (current_duty != target_duty) bypass — yanlış pozitif önleme.
 * Tetiklenince EmergencyStop + 5 sn lockout (Motor_SetDuty/Enable reddedilir).
 * Lockout otomatik açılır veya Motor_ResetLockout ile erken kapatılabilir.
 * Motor_StallCheck main loop'tan her iterasyonda çağrılmalı.
 * ─────────────────────────────────────────────────────────────────────── */
void  Motor_StallCheck(float speed_radps);    /* main loop tick'i */
bool  Motor_IsStalled(void);                  /* lockout aktif mi? */
void  Motor_ResetLockout(void);               /* lockout'u erken kapat (USB komut için 2B'de) */
bool  Motor_PollStallEvent(void);             /* tek seferlik event flag (read-and-clear) */

/* Debug: fake stall injection (encoder hızını 0 sayar) — sıfır-risk test için */
void  Motor_DebugInjectFakeStall(bool on);

#endif /* MOTOR_H */
