#include "motor.h"
#include "stm32f4xx_hal.h"

/* ============================================================================
 * TB6612FNG sürücü — iskelet
 * Detaylar için → include/motor.h
 * ============================================================================ */

#define MOTOR_PWM_PERIOD     4799U  /* ARR for 20 kHz @ 96 MHz / (1 × 4800) */
#define MOTOR_SOFT_START_MS  200U   /* 0 → target rampa süresi */
#define MOTOR_SOFT_STEP_MS   5U     /* her stepte bekleme (40 step) */

static TIM_HandleTypeDef htim3;

void Motor_Init(void)
{
    /* TODO:
     *   1. __HAL_RCC_GPIOB_CLK_ENABLE();
     *   2. __HAL_RCC_TIM3_CLK_ENABLE();
     *   3. PB12, PB13, PB14 GPIO output push-pull, başlangıç LOW:
     *        AIN1=L, AIN2=L → motor Hi-Z (free)
     *        STBY=L         → sürücü standby (güvenli)
     *      NOT: TB6612 input pinlerinde dahili 200 kΩ pull-down var
     *           (datasheet sf 2). STM32 GPIO Hi-Z iken bile sürücü
     *           STBY=L görür → motor seğirmez.
     *   4. PB0 AF config:
     *        Mode = GPIO_MODE_AF_PP
     *        Alternate = GPIO_AF2_TIM3
     *        Speed = GPIO_SPEED_FREQ_HIGH
     *   5. TIM3 PWM init:
     *        htim3.Instance         = TIM3;
     *        htim3.Init.Prescaler   = 0;
     *        htim3.Init.Period      = MOTOR_PWM_PERIOD;
     *        htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
     *        HAL_TIM_PWM_Init(&htim3);
     *   6. Channel 3 PWM config:
     *        sConfigOC.OCMode     = TIM_OCMODE_PWM1;
     *        sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
     *        sConfigOC.Pulse      = 0;  // duty = 0
     *        HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_3);
     *   7. HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);
     */
}

void Motor_Enable(void)
{
    /* TODO: HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);  // STBY=HIGH */
}

void Motor_Disable(void)
{
    /* TODO: HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_RESET); */
}

void Motor_SetDir(MotorDir_t dir)
{
    /* TODO:
     *   GPIO_PinState a1, a2;
     *   switch (dir) {
     *     case MOTOR_CW:    a1 = SET;   a2 = RESET; break;
     *     case MOTOR_CCW:   a1 = RESET; a2 = SET;   break;
     *     case MOTOR_BRAKE: a1 = SET;   a2 = SET;   break;
     *     case MOTOR_STOP:  a1 = RESET; a2 = RESET; break;
     *   }
     *   HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, a1);  // AIN1
     *   HAL_GPIO_WritePin(GPIOB, GPIO_PIN_13, a2);  // AIN2
     *
     * NOT: TB6612 dahili dead-time (50 ns / 230 ns) yön geçişlerini
     *      güvenli kılar. AIN1/AIN2 doğrudan set edilir, yazılım gecikmesi
     *      gerekmez.
     */
    (void)dir;
}

void Motor_SetDuty(float duty01)
{
    /* TODO:
     *   if (duty01 < 0.0f) duty01 = 0.0f;
     *   if (duty01 > 1.0f) duty01 = 1.0f;
     *   uint32_t ccr = (uint32_t)(duty01 * (float)(MOTOR_PWM_PERIOD + 1U));
     *   __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, ccr);
     */
    (void)duty01;
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
