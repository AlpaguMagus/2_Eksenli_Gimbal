#include "motor.h"
#include "stm32f4xx_hal.h"
#include <math.h>
#include <stdbool.h>

/* ============================================================================
 * TB6612FNG sürücü — iskelet
 * Detaylar için → include/motor.h
 * ============================================================================ */

#define MOTOR_PWM_PERIOD     4799U  /* ARR for 20 kHz @ 96 MHz / (1 × 4800) */
#define MOTOR_MAX_DUTY       0.50f  /* Aşama 2A hard cap. Stall'da ~0.8 A */
#define MOTOR_RAMP_STEP      0.01f  /* her tick'te duty değişimi */
#define MOTOR_DEAD_THRESHOLD 0.10f  /* |Δ| > 0.10 ise rampa, ≤ 0.10 ise direkt */
#define MOTOR_SOFT_STEP_MS   5U     /* SoftStart blok rampa step bekleme */

/* Stall detection */
#define STALL_SPEED_TH       2.0f    /* rad/s motor şaftı eşiği */
#define STALL_DUTY_TH        0.20f   /* duty eşiği */
#define STALL_DURATION_MS    200U    /* tetik penceresi */
#define LOCKOUT_DURATION_MS  5000U   /* lockout süresi */

static TIM_HandleTypeDef htim3;

/* Non-blocking rampa state — Motor_Tick her main iterasyonunda günceller. */
static float current_duty = 0.0f;
static float target_duty  = 0.0f;

/* Stall / lockout state */
static uint32_t stall_count_ms      = 0;
static bool     stall_active        = false;
static uint32_t lockout_until_ms    = 0;
static bool     stall_event_pending = false;
static bool     fake_stall_inject   = false;
static uint32_t last_check_tick     = 0;

static inline void _apply_pwm(float d)
{
    uint32_t ccr = (uint32_t)(d * (float)(MOTOR_PWM_PERIOD + 1U));
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, ccr);
}

static inline float _clamp_duty(float d)
{
    if (d < 0.0f)             return 0.0f;
    if (d > MOTOR_MAX_DUTY)   return MOTOR_MAX_DUTY;
    return d;
}

void Motor_Init(void)
{
    __HAL_RCC_GPIOB_CLK_ENABLE();
    __HAL_RCC_TIM3_CLK_ENABLE();

    /* ── PB12 (AIN1), PB13 (AIN2), PB14 (STBY) — GPIO output, başlangıç LOW
     * Motor Hi-Z + sürücü standby → güvenli kapalı.
     * NOT: TB6612 input pinlerinde dahili 200 kΩ pull-down var (datasheet sf 2);
     *      STM32 GPIO Hi-Z iken bile STBY=L görür, motor seğirmez. */
    GPIO_InitTypeDef gpio_out = {0};
    gpio_out.Pin   = GPIO_PIN_12 | GPIO_PIN_13 | GPIO_PIN_14;
    gpio_out.Mode  = GPIO_MODE_OUTPUT_PP;
    gpio_out.Pull  = GPIO_NOPULL;
    gpio_out.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOB, &gpio_out);

    HAL_GPIO_WritePin(GPIOB,
        GPIO_PIN_12 | GPIO_PIN_13 | GPIO_PIN_14,
        GPIO_PIN_RESET);

    /* ── PB0 — TIM3_CH3 PWM çıkışı (AF2_TIM3) */
    GPIO_InitTypeDef gpio_pwm = {0};
    gpio_pwm.Pin       = GPIO_PIN_0;
    gpio_pwm.Mode      = GPIO_MODE_AF_PP;
    gpio_pwm.Pull      = GPIO_NOPULL;
    gpio_pwm.Speed     = GPIO_SPEED_FREQ_HIGH;
    gpio_pwm.Alternate = GPIO_AF2_TIM3;
    HAL_GPIO_Init(GPIOB, &gpio_pwm);

    /* ── TIM3 base — 20 kHz @ 96 MHz / (1 × 4800) */
    htim3.Instance               = TIM3;
    htim3.Init.Prescaler         = 0;
    htim3.Init.Period            = MOTOR_PWM_PERIOD;
    htim3.Init.CounterMode       = TIM_COUNTERMODE_UP;
    htim3.Init.ClockDivision     = TIM_CLOCKDIVISION_DIV1;
    htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
    HAL_TIM_PWM_Init(&htim3);

    /* ── Channel 3 PWM mode 1, polarity HIGH, başlangıç pulse = 0 (duty %0) */
    TIM_OC_InitTypeDef sConfigOC = {0};
    sConfigOC.OCMode     = TIM_OCMODE_PWM1;
    sConfigOC.Pulse      = 0;
    sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
    sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
    HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_3);

    HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);

    current_duty = 0.0f;
    target_duty  = 0.0f;
}

void Motor_Enable(void)
{
    if (stall_active) return;   /* Lockout aktif — STBY=L'de kalır */
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);    /* STBY = HIGH */
}

void Motor_Disable(void)
{
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_RESET);  /* STBY = LOW  */
}

void Motor_SetDir(MotorDir_t dir)
{
    /* TB6612 H-SW kontrol mantığı (datasheet sf 4):
     *   CW    → AIN1=H, AIN2=L
     *   CCW   → AIN1=L, AIN2=H
     *   BRAKE → AIN1=H, AIN2=H (motor kısa devre fren)
     *   STOP  → AIN1=L, AIN2=L (Hi-Z, free-wheel)
     * Dahili dead-time (50 ns / 230 ns, datasheet sf 5) yön geçişlerini
     * güvenli kılar; yazılım dead-band gerekmez. */
    GPIO_PinState a1, a2;
    switch (dir) {
        case MOTOR_CW:    a1 = GPIO_PIN_SET;   a2 = GPIO_PIN_RESET; break;
        case MOTOR_CCW:   a1 = GPIO_PIN_RESET; a2 = GPIO_PIN_SET;   break;
        case MOTOR_BRAKE: a1 = GPIO_PIN_SET;   a2 = GPIO_PIN_SET;   break;
        case MOTOR_STOP:
        default:          a1 = GPIO_PIN_RESET; a2 = GPIO_PIN_RESET; break;
    }
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, a1);   /* AIN1 */
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_13, a2);   /* AIN2 */
}

void Motor_SetDuty(float duty01)
{
    if (stall_active) return;   /* Lockout — duty komutu reddedilir */

    /* Hard cap MOTOR_MAX_DUTY (0.50f) — Stall'da pik akım ~0.8 A,
     * TB6612 1.2 A continuous limitinin altında.
     *
     * |Δduty| > MOTOR_DEAD_THRESHOLD (0.10) ise sadece target güncellenir,
     * Motor_Tick her iterasyonda 0.01 step ile yaklaştırır (non-blocking).
     * Küçük adımlar (PI çıktısı tipik) anında uygulanır. */
    float d = _clamp_duty(duty01);
    target_duty = d;

    if (fabsf(d - current_duty) <= MOTOR_DEAD_THRESHOLD) {
        /* Küçük adım — direkt uygula, kontrol döngüsü için kritik */
        current_duty = d;
        _apply_pwm(d);
    }
    /* else: büyük sıçrama — Motor_Tick yumuşatır */
}

void Motor_Tick(void)
{
    /* Main loop'tan her iterasyonda (200 Hz @ 5 ms) çağrılır.
     * current_duty → target_duty arasında 0.01 step ile yaklaşır.
     * 30 step × 5 ms = 150 ms (büyük sıçrama için tipik rampa süresi). */
    if (current_duty == target_duty) return;

    if (current_duty < target_duty) {
        current_duty += MOTOR_RAMP_STEP;
        if (current_duty > target_duty) current_duty = target_duty;
    } else {
        current_duty -= MOTOR_RAMP_STEP;
        if (current_duty < target_duty) current_duty = target_duty;
    }
    _apply_pwm(current_duty);
}

void Motor_SoftStart(float target01)
{
    /* Bloklayan rampa — init/start-up için. 0'dan target'a ~200 ms.
     * Kontrol döngüsü öncesi tek seferlik kullanım; main loop bloklanır.
     * Runtime için Motor_SetDuty + Motor_Tick kullan (non-blocking). */
    float t = _clamp_duty(target01);
    target_duty  = t;
    current_duty = 0.0f;
    _apply_pwm(0.0f);

    while (current_duty < t - 0.005f) {
        current_duty += MOTOR_RAMP_STEP;
        if (current_duty > t) current_duty = t;
        _apply_pwm(current_duty);
        HAL_Delay(MOTOR_SOFT_STEP_MS);
    }
    current_duty = t;
    _apply_pwm(t);
}

void Motor_Stop(void)
{
    /* Yumuşak durdurma — PWM target'ı 0, dir STOP. Mevcut hız varsa
     * Motor_Tick rampa ile düşürür, motor sürtünme/atalete bırakılır. */
    Motor_SetDir(MOTOR_STOP);
    target_duty  = 0.0f;
    current_duty = 0.0f;     /* anında — ramping istemiyoruz, motor zaten dur isteği */
    _apply_pwm(0.0f);
}

void Motor_EmergencyStop(void)
{
    /* Kesici durdurma — STBY=L (en hızlı, donanım kesim) + duty=0 + AIN=0.
     * Stall detection ve manuel kill için. */
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_RESET);  /* STBY=L önce */
    target_duty  = 0.0f;
    current_duty = 0.0f;
    _apply_pwm(0.0f);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12 | GPIO_PIN_13, GPIO_PIN_RESET);  /* AIN=0 */
}

/* ── Stall detection + lockout ─────────────────────────────────────────── */

void Motor_StallCheck(float speed_radps)
{
    uint32_t now = HAL_GetTick();

    /* Lockout otomatik açılma — 5 sn dolunca sürücüyü tekrar aktive et */
    if (stall_active && now >= lockout_until_ms) {
        stall_active     = false;
        lockout_until_ms = 0;
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);  /* STBY=H */
    }

    if (stall_active) {
        /* Lockout süresince kontrol yapma */
        last_check_tick = now;
        stall_count_ms  = 0;
        return;
    }

    /* Rampa sırasında bypass (current ≠ target) — yanlış pozitif önleme */
    if (fabsf(current_duty - target_duty) > 0.005f) {
        stall_count_ms  = 0;
        last_check_tick = now;
        return;
    }

    /* Tick periyodu — main loop ~5-10 ms, ilk çağrı veya overflow için clamp */
    uint32_t dt = (last_check_tick == 0U) ? 5U : (now - last_check_tick);
    last_check_tick = now;
    if (dt > 100U) dt = 5U;

    /* Stall koşulu — fake_stall ile debug injection */
    float v = fake_stall_inject ? 0.0f : speed_radps;
    bool cond = (fabsf(v) < STALL_SPEED_TH) && (current_duty > STALL_DUTY_TH);

    if (cond) {
        stall_count_ms += dt;
        if (stall_count_ms >= STALL_DURATION_MS) {
            /* STALL TETİK — kesici durdurma + 5 sn lockout */
            stall_event_pending = true;
            stall_count_ms      = 0;
            lockout_until_ms    = now + LOCKOUT_DURATION_MS;
            Motor_EmergencyStop();
            stall_active        = true;  /* EmergencyStop sonrası set — sıra önemli */
        }
    } else {
        stall_count_ms = 0;
    }
}

bool Motor_IsStalled(void)
{
    return stall_active;
}

bool Motor_PollStallEvent(void)
{
    bool e = stall_event_pending;
    stall_event_pending = false;
    return e;
}

void Motor_ResetLockout(void)
{
    /* Erken kapatma — USB komut için (2B'de). Şu an doğrudan da çağrılabilir. */
    stall_active     = false;
    lockout_until_ms = 0;
    stall_count_ms   = 0;
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);  /* STBY=H */
}

void Motor_DebugInjectFakeStall(bool on)
{
    fake_stall_inject = on;
}
