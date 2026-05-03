#include "encoder.h"
#include "stm32f4xx_hal.h"

/* ============================================================================
 * TIM2 quadrature encoder — iskelet
 * Detaylar için → include/encoder.h
 * ============================================================================ */

static TIM_HandleTypeDef htim2;
static int32_t           last_count = 0;

void Encoder_Init(void)
{
    /* TODO:
     *   1. __HAL_RCC_GPIOA_CLK_ENABLE();  __HAL_RCC_GPIOB_CLK_ENABLE();
     *   2. __HAL_RCC_TIM2_CLK_ENABLE();
     *   3. PA15 ve PB3 GPIO config:
     *        Mode      = GPIO_MODE_AF_PP
     *        Pull      = GPIO_PULLUP        // Pololu açık kollektör olabilir
     *        Speed     = GPIO_SPEED_FREQ_HIGH
     *        Alternate = GPIO_AF1_TIM2
     *   4. TIM2 encoder mode (TI1 + TI2, both edges = ENCODERMODE_TI12):
     *        htim2.Instance  = TIM2;
     *        htim2.Init.Period   = 0xFFFFFFFF;       // 32-bit max
     *        htim2.Init.Prescaler= 0;
     *        sConfig.EncoderMode = TIM_ENCODERMODE_TI12;
     *        sConfig.IC1Polarity = TIM_ICPOLARITY_RISING;
     *        sConfig.IC1Selection= TIM_ICSELECTION_DIRECTTI;
     *        sConfig.IC1Prescaler= TIM_ICPSC_DIV1;
     *        sConfig.IC1Filter   = 4;                // Pololu için tipik
     *        (IC2 aynı)
     *        HAL_TIM_Encoder_Init(&htim2, &sConfig);
     *   5. HAL_TIM_Encoder_Start(&htim2, TIM_CHANNEL_ALL);
     */
}

int32_t Encoder_GetCount(void)
{
    /* TODO: return (int32_t)__HAL_TIM_GET_COUNTER(&htim2); */
    return 0;
}

void Encoder_Reset(void)
{
    /* TODO: __HAL_TIM_SET_COUNTER(&htim2, 0); */
    last_count = 0;
}

float Encoder_GetSpeed(float dt_sec)
{
    /* TODO:
     *   int32_t now    = (int32_t)__HAL_TIM_GET_COUNTER(&htim2);
     *   int32_t delta  = now - last_count;
     *   last_count     = now;
     *   if (dt_sec <= 0.0f) return 0.0f;
     *   const float events_per_rev = 192.0f * 9.7f;  // 1862.4
     *   return ((float)delta / events_per_rev) / dt_sec;  // çıkış mili devir/s
     */
    (void)dt_sec;
    return 0.0f;
}
