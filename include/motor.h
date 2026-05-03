#ifndef MOTOR_H
#define MOTOR_H

#include <stdint.h>

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
void  Motor_SetDuty(float duty01);            /* clamp 0..1 */

void  Motor_SoftStart(float target_duty01);   /* ~200 ms rampa */

#endif /* MOTOR_H */
