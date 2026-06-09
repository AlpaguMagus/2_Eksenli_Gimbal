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

/* ── Stall detection / lockout — COUNT-TABANLI (2026-05-31 düzeltme) ──────
 * Tetik: 200 ms pencerede |Δ encoder_count| < 2  VE  current_duty > 0.20.
 * NEDEN count (hız değil): hız ~7 ms loop periyodunda 1 count = 18.7 rad/s
 * kuantizasyonla ölçülür → yavaş ama DÖNEN mil (mirror takibi, ~5 rad/s motor
 * şaftı) ω=0 okunur → YANLIŞ-POZİTİF stall (2.T6 koşusunda yaşandı). 200 ms
 * pencerede count deltası 1 count = 0.67 rad/s çözünürlük verir (28× ince);
 * eşik |Δ|<2 ≈ |ω_motor| < 1.35 rad/s (≈ 7.7°/s çıkış mili). Mirror gimbal-hızı
 * takibi ~8 count/200 ms üretir → tetiklenmez; gerçek kilitli rotor 0 count → 200 ms'de
 * kesilir. Kaynak: [Pololu_25D] 48 CPR (motor şaftı, 4× decoded).
 * Rampa sırasında (current_duty != target_duty) bypass — yanlış pozitif önleme.
 * Tetiklenince EmergencyStop + 1 sn lockout (eski 5 sn): amper bütçesi
 * (docs/asama_0 §8.5) duty-cap %50'de stall akımını (~0.55-0.8 A) TB6612 sürekli
 * limitinin (1.0 A) altında gösterdi → kesme elektriksel değil mekanik/dişli
 * koruması; kısa lockout = hızlı oto-toparlanma ("sistem çalışmayı bırakmasın").
 * Lockout otomatik açılır veya Motor_ResetLockout ile erken kapatılabilir.
 * Motor_StallCheck main loop'tan her iterasyonda çağrılmalı.
 * ─────────────────────────────────────────────────────────────────────── */
void  Motor_StallCheck(int32_t enc_count);    /* main loop tick'i (Encoder_GetCount) */
bool  Motor_IsStalled(void);                  /* lockout aktif mi? */
void  Motor_ResetLockout(void);               /* lockout'u erken kapat (USB komut için 2B'de) */
bool  Motor_PollStallEvent(void);             /* tek seferlik event flag (read-and-clear) */

/* Debug: fake stall injection (count deltasını 0 sayar) — sıfır-risk test için */
void  Motor_DebugInjectFakeStall(bool on);

/* ============================================================================
 * MOTOR-2 (Aşama 3 — ikinci eksen) — 2. TB6612FNG, A-kanalı
 *
 * Donanım (00_donanim_semasi.md §2; gerekçe asama_3_mimo_model.md §12.2):
 *   PB1  → TIM3_CH4 PWM (motor-1 ile AYNI timer/ARR, bağımsız CCR — ekstra
 *          timer harcamaz; 20 kHz, 4800 step). AF2_TIM3.
 *   PB4  → AIN1-2 (yön)   — GPIO output (PB4=JTRST, SW-DP modunda serbest)
 *   PB5  → AIN2-2 (yön)   — GPIO output (genel-amaçlı, JTAG değil)
 *   PB10 → STBY-2 (enable) — eksen-bağımsız acil kesme (paylaşımlı DEĞİL:
 *          bir eksenin stall'ı diğerini söndürmesin, kullanıcı kararı 2026-06-07)
 *
 * Truth table + dead-time motor-1 ile AYNI (TB6612 datasheet sf 4-5, MotorDir_t).
 *
 * ⚠ KAPSAM (3.2b): bu MİNİMAL açık-döngü sürücüdür — stall-detection/lockout
 *   YOK (motor-1'de var). Gerekçe: 3.2b yalnız yön/kimlik doğrulaması; emniyet
 *   watchdog (1 sn) + duty-cap (%50, ≤0.8 A < TB6612 1.0 A) + denetimli bench
 *   ile sağlanır. Motor-2 stall + shared-struct refactor → Aşama 3.3 (baseline,
 *   motor-2 kapalı-döngüye geçince).
 *
 * Init sırası: Motor2_Init() Motor_Init()'TEN SONRA (htim3 base'ini Motor_Init
 *   kurar; Motor2_Init yalnız CH4'ü ekler). Motor2_Enable() en sonda (STBY=H).
 * ============================================================================ */
void  Motor2_Init(void);                /* PB1 CH4 PWM + PB4/PB5/PB10 GPIO, STBY=LOW */
void  Motor2_Enable(void);              /* PB10 = HIGH */
void  Motor2_Disable(void);             /* PB10 = LOW  */
void  Motor2_SetDir(MotorDir_t dir);    /* PB4=AIN1, PB5=AIN2 (motor-1 truth table) */
void  Motor2_SetDutySigned(float duty); /* signed, rampasız, ±MOTOR_MAX_DUTY clamp */
void  Motor2_Stop(void);                /* PWM=0, dir=STOP */
void  Motor2_EmergencyStop(void);       /* STBY=L + duty=0 + AIN=0 */
float Motor2_GetDutySigned(void);       /* son uygulanan signed duty (telemetri U2) */

#endif /* MOTOR_H */
