#ifndef MOTOR_H
#define MOTOR_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * TB6612FNG Motor Sürücü API — KANAL-INSTANCE (Aşama 3.3 refactor)
 *
 * İki motor kanalı, her biri kendi MotorCh_t örneğiyle (tüm state struct'ta):
 *
 *   Motor1 (eksen-0):                    Motor2 (eksen-1):
 *     PB0  → TIM3_CH3 PWM                  PB1  → TIM3_CH4 PWM
 *     PB12 → AIN1  (yön)                   PB4  → AIN1  (yön)
 *     PB13 → AIN2  (yön)                   PB5  → AIN2  (yön)
 *     PB14 → STBY  (enable)                PB10 → STBY  (eksen-bağımsız kesme)
 *
 *   PWM: TIM3 PAYLAŞILIR (aynı 20 kHz ARR=4799, bağımsız CCR) — base'i ilk
 *   MotorCh_Init kurar, sonraki yalnız kendi kanalını ekler.
 *
 * H-SW kontrol mantığı (TB6612FNG datasheet sf 4) — iki kanal AYNI:
 *   AIN1=H, AIN2=L  → CW   (ileri)
 *   AIN1=L, AIN2=H  → CCW  (geri)
 *   AIN1=H, AIN2=H  → BRAKE (kısa devre fren)
 *   AIN1=L, AIN2=L  → STOP  (Hi-Z, free-wheel)
 *   STBY=L          → sürücü standby
 *
 * Dahili dead-time (datasheet sf 5: 50 ns H→L, 230 ns L→H):
 *   Yön değiştirmede yazılım dead-band gerekmiyor — donanım hallediyor.
 *
 * Init sırası (main.c):
 *   1) MotorCh_Init(&Motor1); MotorCh_Init(&Motor2);  — STBY=LOW, güvenli kapalı
 *   2) (diğer init'ler ve HAL_Delay)
 *   3) MotorCh_Enable(...)  — STBY=HIGH (en sonda, kazara seğirme önlenir)
 *
 * Soft-start: ani yüklenmeyi önlemek için PWM'i 0'dan hedef değere
 *             ~200 ms içinde lineer rampa ile çıkar.
 *
 * ── Stall detection / lockout — COUNT-TABANLI (2026-05-31 düzeltme) ──────
 * Tetik: 200 ms pencerede |Δ encoder_count| < 2  VE  current_duty > 0.20.
 * NEDEN count (hız değil): hız ~7 ms loop periyodunda 1 count = 18.7 rad/s
 * kuantizasyonla ölçülür → yavaş ama DÖNEN mil (mirror takibi, ~5 rad/s motor
 * şaftı) ω=0 okunur → YANLIŞ-POZİTİF stall (2.T6 koşusunda yaşandı). 200 ms
 * pencerede count deltası 1 count = 0.67 rad/s çözünürlük verir (28× ince);
 * eşik |Δ|<2 ≈ |ω_motor| < 1.35 rad/s (≈ 7.7°/s çıkış mili). Mirror gimbal-hızı
 * takibi ~8 count/200 ms üretir → tetiklenmez; gerçek kilitli rotor 0 count → 200 ms'de
 * kesilir. Kaynak: [Pololu_25D] 48 CPR (motor şaftı, 4× decoded).
 * Rampa sırasında (current_duty != target_duty) bypass — yanlış pozitif önleme.
 * Tetiklenince EmergencyStop + 1 sn lockout: amper bütçesi (docs/asama_0 §8.5)
 * duty-cap %50'de stall akımını (~0.55-0.8 A) TB6612 sürekli limitinin (1.0 A)
 * altında gösterdi → kesme elektriksel değil mekanik/dişli koruması; kısa
 * lockout = hızlı oto-toparlanma ("sistem çalışmayı bırakmasın").
 * Aşama 3.3: stall artık HER İKİ kanalda (3.2b'de motor-2 için ertelenmişti) —
 * her örnek kendi penceresini/lockout'unu taşır.
 * MotorCh_StallCheck main loop'tan her iterasyonda kendi enkoderiyle çağrılır.
 * ============================================================================ */

typedef enum {
    MOTOR_CW    = 0,   /* AIN1=H, AIN2=L */
    MOTOR_CCW   = 1,   /* AIN1=L, AIN2=H */
    MOTOR_BRAKE = 2,   /* AIN1=H, AIN2=H */
    MOTOR_STOP  = 3    /* AIN1=L, AIN2=L (Hi-Z) */
} MotorDir_t;

typedef struct {
    /* ── Donanım konfig (instance tanımında sabitlenir — motor.c) ── */
    uint32_t pwm_channel;       /* TIM_CHANNEL_3 (motor-1) / TIM_CHANNEL_4 (motor-2) */
    uint16_t pwm_pin;           /* GPIOB: PB0 / PB1 */
    uint16_t ain1_pin;          /* GPIOB: PB12 / PB4 */
    uint16_t ain2_pin;          /* GPIOB: PB13 / PB5 */
    uint16_t stby_pin;          /* GPIOB: PB14 / PB10 */

    /* ── Duty / rampa state (Motor_Tick non-blocking rampası) ── */
    float current_duty;         /* uygulanan |duty| */
    float target_duty;          /* hedef |duty| */
    float last_signed_duty;     /* son signed komut (telemetri U2 vb.) */

    /* ── Stall / lockout state ── */
    uint32_t stall_count_ms;
    int32_t  stall_ref_count;
    bool     stall_active;
    uint32_t lockout_until_ms;
    bool     stall_event_pending;
    bool     fake_stall_inject;
    bool     stall_disabled;    /* runtime: stall algılamayı KAPAT (STALLEN:0). Yük altında count-tabanlı
                                 * stall yanlış-pozitif verir (stick-slip + duty>0.20). Birincil akım
                                 * koruması duty-cap %50 (stall ~0.55-0.8 A < TB6612 1.0 A) AKTİF kalır.
                                 * Default false (=algılama AÇIK, emniyet). Yalnız süpervizeli yüklü test. */
    uint32_t last_check_tick;
} MotorCh_t;

/* Kanal örnekleri (motor.c'de tanımlı — pin haritası orada) */
extern MotorCh_t Motor1;   /* eksen-0: PB0/CH3, PB12/13/14 */
extern MotorCh_t Motor2;   /* eksen-1: PB1/CH4, PB4/5/10  */

void  MotorCh_Init(MotorCh_t *m);             /* GPIO + PWM kanal; ilk çağrı TIM3 base kurar; STBY=LOW */
void  MotorCh_Enable(MotorCh_t *m);           /* STBY=HIGH (lockout aktifse reddedilir) */
void  MotorCh_Disable(MotorCh_t *m);          /* STBY=LOW */

void  MotorCh_SetDir(MotorCh_t *m, MotorDir_t dir);
void  MotorCh_SetDuty(MotorCh_t *m, float duty01);   /* clamp [0, MOTOR_MAX_DUTY], rampa+dead-band (açık döngü) */
void  MotorCh_SetDutySigned(MotorCh_t *m, float duty); /* signed, RAMPA YOK — kapalı döngü PI için */
void  MotorCh_Tick(MotorCh_t *m);             /* main loop'tan her iterasyon (~140 Hz) — açık döngü rampa */

void  MotorCh_SoftStart(MotorCh_t *m, float target_duty01); /* bloklayan ~200 ms rampa, init için */
void  MotorCh_Stop(MotorCh_t *m);             /* PWM=0, dir=STOP */
void  MotorCh_EmergencyStop(MotorCh_t *m);    /* STBY=L + duty=0 + AIN=0 */

void  MotorCh_StallCheck(MotorCh_t *m, int32_t enc_count); /* her iterasyonda kendi enkoderiyle */
bool  MotorCh_IsStalled(const MotorCh_t *m);  /* lockout aktif mi? */
void  MotorCh_ResetLockout(MotorCh_t *m);     /* lockout'u erken kapat (RESET komutu) */
void  MotorCh_SetStallDetect(MotorCh_t *m, bool enabled); /* STALLEN: yük altında yanlış-pozitif → kapatılabilir (default açık) */
bool  MotorCh_PollStallEvent(MotorCh_t *m);   /* tek seferlik event flag (read-and-clear) */

float MotorCh_GetDutySigned(const MotorCh_t *m); /* son signed duty (telemetri) */

/* Debug: fake stall injection (count deltasını 0 sayar) — sıfır-risk test için */
void  MotorCh_InjectFakeStall(MotorCh_t *m, bool on);

#endif /* MOTOR_H */
