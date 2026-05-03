#include "stm32f4xx_hal.h"
#include "usbd_core.h"
#include "usbd_desc.h"
#include "usbd_cdc.h"
#include "usbd_cdc_if.h"
#include "encoder.h"
#include "motor.h"
#include <string.h>
#include <stdio.h>
#include <math.h>

#define RAD2DEG  (180.0f / 3.14159265f)

/* --- Tanımlamalar --- */
#define MPU6050_ADDR         (0x68 << 1)   /* AD0 GND'ye bağlı */
#define MPU6050_PWR_MGMT_1   0x6B
#define MPU6050_ACCEL_XOUT_H 0x3B          /* 14 byte burst okuma */

/* --- Global Handles --- */
USBD_HandleTypeDef hUsbDeviceFS;           /* usbd_cdc_if.c tarafından extern */
I2C_HandleTypeDef  hi2c1;

/* --- Prototip --- */
void SystemClock_Config(void);
void I2C1_Init(void);
void MPU6050_Init(void);
void MPU6050_Read(int16_t *ax, int16_t *ay, int16_t *az,
                  int16_t *gx, int16_t *gy, int16_t *gz);

/* ================================================================
   MAIN
   ================================================================ */
int main(void)
{
    /* ─── Init sırası ─────────────────────────────────────────────────
     * 1) HAL + clock
     * 2) Periferik init'ler (I2C, MPU6050, Encoder, Motor)
     *      — Motor_Init STBY=LOW bırakır → motor güvenli kapalı
     * 3) USB CDC (host enumeration için 2 sn bekle)
     * 4) Motor_Enable() EN SONDA — STBY=HIGH ile sürücü aktif
     * ──────────────────────────────────────────────────────────────── */

    HAL_Init();
    SystemClock_Config();
    I2C1_Init();

    /* PC13 LED */
    __HAL_RCC_GPIOC_CLK_ENABLE();
    GPIO_InitTypeDef led = {0};
    led.Pin   = GPIO_PIN_13;
    led.Mode  = GPIO_MODE_OUTPUT_PP;
    led.Pull  = GPIO_NOPULL;
    led.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOC, &led);

    MPU6050_Init();
    Encoder_Init();           /* TIM2, PA15+PB3 */
    Motor_Init();              /* TIM3, PB0 PWM, PB12-14 GPIO, STBY=LOW */

    /* USB CDC başlat */
    USBD_Init(&hUsbDeviceFS, &CDC_Desc, DEVICE_FS);
    USBD_RegisterClass(&hUsbDeviceFS, &USBD_CDC);
    USBD_CDC_RegisterInterface(&hUsbDeviceFS, &USBD_Interface_fops_FS);
    USBD_Start(&hUsbDeviceFS);

    HAL_Delay(2000);           /* Host'un /dev/ttyACM0'ı tanıması için bekle */

    Motor_Enable();            /* STBY=HIGH — sürücü artık aktif */

    int16_t ax, ay, az, gx, gy, gz;
    char    buf[96];

    /* Complementary filter durumu */
    float fused_pitch = 0.0f;
    float fused_roll  = 0.0f;
    const float alpha = 0.98f;
    uint32_t last_tick = HAL_GetTick();

    while (1)
    {
        MPU6050_Read(&ax, &ay, &az, &gx, &gy, &gz);

        /* dt hesabı */
        uint32_t now = HAL_GetTick();
        float dt = (now - last_tick) / 1000.0f;
        if (dt <= 0.0f || dt > 0.5f) dt = 0.05f;  /* ilk döngü / overflow koruması */
        last_tick = now;

        int32_t enc_count = Encoder_GetCount();

        float fax = (float)ax, fay = (float)ay, faz = (float)az;

        /* İvmeölçer açısı */
        float pitch = atan2f(fax, sqrtf(fay*fay + faz*faz)) * RAD2DEG;
        float roll  = atan2f(fay, sqrtf(fax*fax + faz*faz)) * RAD2DEG;

        /* Gyro hızı — varsayılan ±250°/s → 131 LSB/(°/s) */
        float gx_dps = (float)gx / 131.0f;
        float gy_dps = (float)gy / 131.0f;

        /* Complementary filter:
           pitch → Y ekseni dönüşü → gy_dps    
           roll  → X ekseni dönüşü → gx_dps   */   
        fused_pitch = alpha * (fused_pitch - gy_dps * dt) + (1.0f - alpha) * pitch;
        fused_roll  = alpha * (fused_roll  + gx_dps * dt) + (1.0f - alpha) * roll;

        int len = snprintf(buf, sizeof(buf),
            "P:%.1f,R:%.1f,GX:%.1f,GY:%.1f,FP:%.1f,FR:%.1f,EC:%ld\r\n",
            pitch, roll, gx_dps, gy_dps, fused_pitch, fused_roll,
            (long)enc_count);
        CDC_Transmit_FS((uint8_t *)buf, (uint16_t)len);

        HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
        HAL_Delay(50);
    }
}

/* ================================================================
   I2C1  —  PB6 = SCL,  PB7 = SDA
   ================================================================ */
void I2C1_Init(void)
{
    __HAL_RCC_GPIOB_CLK_ENABLE();
    __HAL_RCC_I2C1_CLK_ENABLE();

    GPIO_InitTypeDef gpio = {0};
    gpio.Pin       = GPIO_PIN_6 | GPIO_PIN_7;
    gpio.Mode      = GPIO_MODE_AF_OD;
    gpio.Pull      = GPIO_NOPULL;
    gpio.Speed     = GPIO_SPEED_FREQ_VERY_HIGH;
    gpio.Alternate = GPIO_AF4_I2C1;
    HAL_GPIO_Init(GPIOB, &gpio);

    hi2c1.Instance             = I2C1;
    hi2c1.Init.ClockSpeed      = 100000;
    hi2c1.Init.DutyCycle       = I2C_DUTYCYCLE_2;
    hi2c1.Init.OwnAddress1     = 0;
    hi2c1.Init.AddressingMode  = I2C_ADDRESSINGMODE_7BIT;
    hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
    hi2c1.Init.OwnAddress2     = 0;
    hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
    hi2c1.Init.NoStretchMode   = I2C_NOSTRETCH_DISABLE;
    HAL_I2C_Init(&hi2c1);
}

/* ================================================================
   MPU6050
   ================================================================ */
void MPU6050_Init(void)
{
    uint8_t data = 0x00;
    HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, MPU6050_PWR_MGMT_1,
                      I2C_MEMADD_SIZE_8BIT, &data, 1, HAL_MAX_DELAY);
    HAL_Delay(100);
}

void MPU6050_Read(int16_t *ax, int16_t *ay, int16_t *az,
                  int16_t *gx, int16_t *gy, int16_t *gz)
{
    uint8_t raw[14];
    HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, MPU6050_ACCEL_XOUT_H,
                     I2C_MEMADD_SIZE_8BIT, raw, 14, HAL_MAX_DELAY);

    *ax = (int16_t)(raw[0]  << 8 | raw[1]);
    *ay = (int16_t)(raw[2]  << 8 | raw[3]);
    *az = (int16_t)(raw[4]  << 8 | raw[5]);
    /* raw[6..7] = TEMP — atla */
    *gx = (int16_t)(raw[8]  << 8 | raw[9]);
    *gy = (int16_t)(raw[10] << 8 | raw[11]);
    *gz = (int16_t)(raw[12] << 8 | raw[13]);
}

/* ================================================================
   SAAT — HSE 25MHz → PLL → 96MHz SYSCLK, PLLQ=4 → 48MHz USB
   ================================================================ */
void SystemClock_Config(void)
{
    RCC_OscInitTypeDef RCC_OscInitStruct = {0};
    RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

    RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
    RCC_OscInitStruct.HSEState       = RCC_HSE_ON;
    RCC_OscInitStruct.PLL.PLLState   = RCC_PLL_ON;
    RCC_OscInitStruct.PLL.PLLSource  = RCC_PLLSOURCE_HSE;
    RCC_OscInitStruct.PLL.PLLM       = 25;
    RCC_OscInitStruct.PLL.PLLN       = 192;
    RCC_OscInitStruct.PLL.PLLP       = RCC_PLLP_DIV2;   /* SYSCLK = 96 MHz */
    RCC_OscInitStruct.PLL.PLLQ       = 4;                /* USB    = 48 MHz */
    HAL_RCC_OscConfig(&RCC_OscInitStruct);

    RCC_ClkInitStruct.ClockType      = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
                                     | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
    RCC_ClkInitStruct.SYSCLKSource   = RCC_SYSCLKSOURCE_PLLCLK;
    RCC_ClkInitStruct.AHBCLKDivider  = RCC_SYSCLK_DIV1;
    RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
    RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;
    HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_3);
}

void SysTick_Handler(void)
{
    HAL_IncTick();
}
