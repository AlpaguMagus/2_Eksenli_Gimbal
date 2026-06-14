#ifndef MOTOR_H
#define MOTOR_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * Motor Sürücü API — KANAL-INSTANCE (Aşama 3.3 refactor + 3.5 asimetrik sürücü)
 *
 * İki motor kanalı, her biri kendi MotorCh_t örneğiyle (tüm state struct'ta).
 * ⚠ ASİMETRİK (2026-06-14): Motor1 = HW-039/BTS7960 (HP); Motor2 = TB6612 (LP).
 *
 *   Motor1 (eksen-0) — HW-039/BTS7960:   Motor2 (eksen-1) — TB6612FNG:
 *     PB8  → TIM4_CH3 RPWM (CW yön)        PB1  → TIM3_CH4 PWM
 *     PB9  → TIM4_CH4 LPWM (CCW yön)       PB4  → AIN1 (yön)
 *     PB14 → R_EN+L_EN köprü (enable)      PB5  → AIN2 (yön)
 *     (sign-magnitude; AIN/STBY YOK)       PB10 → STBY (eksen-bağımsız kesme)
 *
 *   PWM: Motor1 TIM4 (BTS7960, 20 kHz: ARR=4799 presc=0, [BTS7960_DS] ≤25 kHz);
 *        Motor2 TIM3 (TB6612, 20 kHz: ARR=4799). AYRI timer'lar — her MotorCh_Init
 *        kendi base'ini kurar. (Eski: ikisi de TB6612/TIM3; motor-1 HP+HW-039'a yükseltildi.)
 *
 * Sürüş mantığı:
 *  · Motor2 (TB6612, datasheet sf 4): AIN1=H,AIN2=L→CW; L,H→CCW; H,H→BRAKE; L,L→STOP; STBY=L→standby.
 *    Dahili dead-time (sf 5: 50/230 ns) → yön değişiminde yazılım dead-band gerekmez.
 *  · Motor1 (BTS7960 sign-magnitude): CW→RPWM=duty/LPWM=0; CCW→RPWM=0/LPWM=duty;
 *    STOP/BRAKE→ikisi 0 (shoot-through koruması); enable=R_EN+L_EN=PB14. [BTS7960_module_DS handsontec].
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
    uint32_t pwm_channel;       /* TB6612: TIM3 kanalı | BTS7960: TIM4_CH3 (RPWM) */
    uint16_t pwm_pin;           /* GPIOB: TB6612 PWM pini | BTS7960 RPWM pini (PB8) */
    uint16_t ain1_pin;          /* GPIOB: TB6612 AIN1 | BTS7960'da 0 (kullanılmaz) */
    uint16_t ain2_pin;          /* GPIOB: TB6612 AIN2 | BTS7960'da 0 (kullanılmaz) */
    uint16_t stby_pin;          /* GPIOB: TB6612 STBY | BTS7960 R_EN+L_EN köprü (enable) */

    /* ── Sürücü-tipi soyutlaması (Aşama 3.5 — eksen-0 HP Pololu + HW-039/BTS7960) ──
     * Motor-1 = BTS7960 (RPWM/LPWM yön-başı PWM + enable); Motor-2 = TB6612 (IN1/IN2/PWM).
     * BTS7960: yön = hangi PWM kanalı aktif; shoot-through koruması (_apply_pwm tek kanal). */
    bool       is_bts7960;      /* true=BTS7960/HW-039 (motor-1) · false=TB6612 (motor-2) */
    uint32_t   pwm_channel2;    /* BTS7960 LPWM kanalı (TIM4_CH4); TB6612'de kullanılmaz */
    uint16_t   pwm_pin2;        /* BTS7960 LPWM pini (PB9); TB6612'de kullanılmaz */
    MotorDir_t bts_dir;         /* BTS7960 son yön (CW=RPWM / CCW=LPWM); _apply_pwm kullanır */

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
extern MotorCh_t Motor1;   /* eksen-0: BTS7960 TIM4 RPWM=PB8/LPWM=PB9, EN=PB14 */
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
