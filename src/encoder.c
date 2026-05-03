#include "encoder.h"
#include "stm32f4xx_hal.h"

/* ============================================================================
 * TIM2 quadrature encoder
 * Detaylar için → include/encoder.h
 *
 * Mod: TIM_ENCODERMODE_TI12 (TI1 ve TI2 her iki kenar → 4× decoding)
 * Pololu "48 CPR" zaten quadrature-decoded sayım — 4'le çarpılmaz.
 *   Kaynak: robotsepeti.com 25D LP sayfası ve Test 2A.T1 gözlemi
 *   (470 ≈ 48 × 9.7 → çıkış mili 1 dev).
 * 1 motor şaftı devri = 48 olay (TI12 mode, kuadratür-decoded)
 * Filter (ICxF=4): 6 ardışık örnek aynı seviye olmalı — Pololu için makul
 * ============================================================================ */

#define EVENTS_PER_REV  48       /* Pololu CPR zaten 4× decoded (motor şaftı) */
#define TWO_PI          6.28318530717958647692f

static TIM_HandleTypeDef htim2;
static int32_t           last_count = 0;

void Encoder_Init(void)
{
    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();
    __HAL_RCC_TIM2_CLK_ENABLE();

    GPIO_InitTypeDef gpio = {0};
    gpio.Mode      = GPIO_MODE_AF_PP;
    gpio.Pull      = GPIO_PULLUP;            /* Pololu açık-kollektör olabilir */
    gpio.Speed     = GPIO_SPEED_FREQ_HIGH;
    gpio.Alternate = GPIO_AF1_TIM2;

    /* PA15 → TIM2_CH1 (Encoder A, sarı kablo) */
    gpio.Pin = GPIO_PIN_15;
    HAL_GPIO_Init(GPIOA, &gpio);

    /* PB3 → TIM2_CH2 (Encoder B, beyaz kablo) */
    gpio.Pin = GPIO_PIN_3;
    HAL_GPIO_Init(GPIOB, &gpio);

    htim2.Instance               = TIM2;
    htim2.Init.Prescaler         = 0;
    htim2.Init.Period            = 0xFFFFFFFFU;        /* 32-bit max */
    htim2.Init.CounterMode       = TIM_COUNTERMODE_UP;
    htim2.Init.ClockDivision     = TIM_CLOCKDIVISION_DIV1;
    htim2.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;

    TIM_Encoder_InitTypeDef sConfig = {0};
    sConfig.EncoderMode  = TIM_ENCODERMODE_TI12;
    sConfig.IC1Polarity  = TIM_ICPOLARITY_RISING;
    sConfig.IC1Selection = TIM_ICSELECTION_DIRECTTI;
    sConfig.IC1Prescaler = TIM_ICPSC_DIV1;
    sConfig.IC1Filter    = 4;
    sConfig.IC2Polarity  = TIM_ICPOLARITY_RISING;
    sConfig.IC2Selection = TIM_ICSELECTION_DIRECTTI;
    sConfig.IC2Prescaler = TIM_ICPSC_DIV1;
    sConfig.IC2Filter    = 4;

    HAL_TIM_Encoder_Init(&htim2, &sConfig);
    HAL_TIM_Encoder_Start(&htim2, TIM_CHANNEL_ALL);

    last_count = 0;
}

int32_t Encoder_GetCount(void)
{
    return (int32_t)__HAL_TIM_GET_COUNTER(&htim2);
}

void Encoder_Reset(void)
{
    __HAL_TIM_SET_COUNTER(&htim2, 0);
    last_count = 0;
}

float Encoder_GetSpeed(float dt_sec)
{
    if (dt_sec <= 0.0f) return 0.0f;

    int32_t now   = (int32_t)__HAL_TIM_GET_COUNTER(&htim2);
    int32_t delta = now - last_count;
    last_count    = now;

    /* (2π × Δcount) / (192 × Δt) = motor şaftı rad/s
     * Çıkış mili (gear-out) için çağıran taraf 9.7'ye bölmeli. */
    return ((float)delta * TWO_PI) / ((float)EVENTS_PER_REV * dt_sec);
}
