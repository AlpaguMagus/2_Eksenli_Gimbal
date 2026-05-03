#include "motor.h"
#include "stm32f4xx_hal.h"

/* ============================================================================
 * TB6612FNG sürücü — iskelet
 * Detaylar için → include/motor.h
 * ============================================================================ */

#define MOTOR_PWM_PERIOD     4799U  /* ARR for 20 kHz @ 96 MHz / (1 × 4800) */
#define MOTOR_MAX_DUTY       0.50f  /* Aşama 2A hard cap. Stall'da ~0.8 A */
#define MOTOR_SOFT_START_MS  200U   /* 0 → target rampa süresi */
#define MOTOR_SOFT_STEP_MS   5U     /* her stepte bekleme (40 step) */

static TIM_HandleTypeDef htim3;

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
}

void Motor_Enable(void)
{
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
    /* Hard cap MOTOR_MAX_DUTY (0.50f) Aşama 2A boyunca.
     * Stall'da pik akım ~0.8 A — TB6612 1.2 A continuous limitinin altında. */
    if (duty01 < 0.0f)            duty01 = 0.0f;
    if (duty01 > MOTOR_MAX_DUTY)  duty01 = MOTOR_MAX_DUTY;

    uint32_t ccr = (uint32_t)(duty01 * (float)(MOTOR_PWM_PERIOD + 1U));
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, ccr);
}

void Motor_SoftStart(float target_duty01)
{
    /* TODO: 0'dan target_duty01'e ~200 ms içinde lineer rampa.
     *
     *   if (target_duty01 < 0.0f) target_duty01 = 0.0f;
     *   if (target_duty01 > 1.0f) target_duty01 = 1.0f;
     *
     *   const uint32_t steps = MOTOR_SOFT_START_MS / MOTOR_SOFT_STEP_MS;  // 40
     *   for (uint32_t i = 1; i <= steps; ++i) {
     *       float d = target_duty01 * ((float)i / (float)steps);
     *       Motor_SetDuty(d);
     *       HAL_Delay(MOTOR_SOFT_STEP_MS);
     *   }
     */
    (void)target_duty01;
}
