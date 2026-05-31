#include "stm32f4xx_hal.h"
#include "usbd_core.h"
#include "usbd_desc.h"
#include "usbd_cdc.h"
#include "usbd_cdc_if.h"
#include "encoder.h"
#include "motor.h"
#include "cmd_parser.h"
#include "speed_pi.h"
#include "position_p.h"
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
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

    /* DWT cycle counter — mikrosaniye timestamp için (T_US alanı).
     * ARM Cortex-M4 Generic User Guide §11.3 [ARM_DWT]. 32-bit @ 96 MHz →
     * unsigned subtraction ile fark hesabı her zaman doğru; mutlak değer
     * ~44.7 sn'de wrap eder ama Python tarafı diff alıyor, sorun yok. */
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CYCCNT       = 0U;
    DWT->CTRL        |= DWT_CTRL_CYCCNTENA_Msk;

    I2C1_Init();

    /* PC13 LED */
    __HAL_RCC_GPIOC_CLK_ENABLE();
    GPIO_InitTypeDef led = {0};
    led.Pin   = GPIO_PIN_13;
    led.Mode  = GPIO_MODE_OUTPUT_PP;
    led.Pull  = GPIO_NOPULL;
    led.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOC, &led);

    /* PA0 — KEY butonu (debug fake stall tetikleyici). BlackPill schematic'inde
     * KEY → PA0 → GND (active-low). GPIO input + pull-up. TIM2_CH1 AF aktif
     * değil, encoder PA15+PB3'te → çakışma yok. */
    __HAL_RCC_GPIOA_CLK_ENABLE();
    GPIO_InitTypeDef key = {0};
    key.Pin  = GPIO_PIN_0;
    key.Mode = GPIO_MODE_INPUT;
    key.Pull = GPIO_PULLUP;
    HAL_GPIO_Init(GPIOA, &key);

    MPU6050_Init();
    Encoder_Init();           /* TIM2, PA15+PB3 */
    Motor_Init();              /* TIM3, PB0 PWM, PB12-14 GPIO, STBY=LOW */

    /* Hız iç döngü PI kazançları.
     *
     * ⚠ Aşama 2.3 BULGUSU: Aşama 2.1 Simulink tasarımı (conservative pole
     * placement Kp=0.1163, Ki=4.0447) gerçek sistemde BANG-BANG limit cycle
     * verdi. Kök neden: Simulink ideal ölçüm + farklı plant varsaydı; gerçekte
     * serbest mil çok hızlı (0.5 duty → ~280 rad/s no-load) + encoder kuantize
     * + yüksek Kp her error'da saturation'a fırlatıyordu → limit cycle.
     *
     * ANALİTİK DÜZELTME (design_speed_pi_corrected.m, docs §11.12.3): doyum-kısıtı
     * Kp≈duty_max/ω_max=0.002 + doğru-plant (Kg=K·Vs=654.8) pole placement
     * ω_n=2/τ=33 → Ki=0.1. Conservative'den ~58× düşük; tüm setpoint'lere temiz
     * oturur (50/120/30 rad/s, bang-bang yok). 2b gerçekçi Simulink + ayrık margin doğruladı.
     *
     * Runtime KP:/KI:/SLEW: komutlarıyla flash'sız ayarlanabilir (test için).
     * Kaynaklar: [AstromMurray2008] §10.2 (Tustin), §10.4 (back-calculation) */
    static const SpeedPI_Config SPEED_PI_CFG = {
        .Kp       = 0.002f,           /* analitik: doyum-kısıtı Kp≈duty_max/ω_max
                                       * (design_speed_pi_corrected.m, docs §11.12.3);
                                       * 2.1 conservative 58× yüksekti (P-term doyar → bang-bang) */
        .Ki       = 0.1f,
        .Ts       = 0.005f,           /* Tustin SABIT adımı (5 ms = 200 Hz NOMINAL).
                                       * DİKKAT: gerçek ana döngü ~7 ms (~140 Hz, docs
                                       * asama_0 §5.4) — Ts gerçek dt değil. Efektif integral
                                       * kazancı nominalin Ts/dt≈5/7≈0.71 katı; Ki=0.1 bu
                                       * sabit-Ts varsayımı altında geçerli (donanımda doğrulandı).
                                       * Döngü hızı değişir/Ts gerçek dt'ye bağlanırsa integral
                                       * etkisi sessizce kayar (latent kuplaj — docs §11.12.8 notu). */
        .duty_max = 0.50f,            /* = MOTOR_MAX_DUTY firmware tarafı */
        .T_t      = 0.02f             /* Kp/Ki — Aström-Murray T_t = T_i */
    };
    SpeedPI_Init(&SPEED_PI_CFG);

    /* Pozisyon dış döngü P kontrolcü (Aşama 2.5 — cascade).
     * Kp_pos=2.0 [1/s]: matlab/asama_2_kontrol/design_position_p.m
     *   dış döngü ω_c≈1.93 rad/s, cascade kuralı gereği iç döngüden ~5× yavaş [Franklin2010 §6.4]
     *   (ilk tahmin iç ω_n≈9.4; Vsupply dahil gerçek ω_n≈33 → ayrım ~16×, docs §11.13.2b)
     *   PM 69.7°, tip-1 → P ile ss_error=0 [Franklin2010 §4.3]
     * Gerçekçi sim (verify_realistic_cascade.m): ss_err %1.75, OS %12.5.
     *   ⚠ simde küçük limit-cycle (iç hız döngüsü düşük hızda kuant. kör) —
     *   gerçek motorda sürtünme söndürebilir, Test 2.5 ile doğrulanacak. */
    static const PositionP_Config POS_P_CFG = {
        .Kp_pos         = 2.0f,
        .gear_ratio     = 9.7f,
        .counts_per_rev = 466.0f,   /* 48 × 9.7 (çıkış mili event/rev) */
        .omega_ref_max  = 300.0f    /* rad/s motor şaftı güvenlik limiti */
    };
    PositionP_Init(&POS_P_CFG);

    /* USB CDC başlat */
    USBD_Init(&hUsbDeviceFS, &CDC_Desc, DEVICE_FS);
    USBD_RegisterClass(&hUsbDeviceFS, &USBD_CDC);
    USBD_CDC_RegisterInterface(&hUsbDeviceFS, &USBD_Interface_fops_FS);
    USBD_Start(&hUsbDeviceFS);

    HAL_Delay(2000);           /* Host'un /dev/ttyACM0'ı tanıması için bekle */

    Motor_Enable();            /* STBY=HIGH — sürücü artık aktif */

    int16_t ax, ay, az, gx, gy, gz;
    char    buf[160];   /* +OMEGA, +SP, +U alanları için */

    /* Complementary filter durumu */
    float fused_pitch = 0.0f;
    float fused_roll  = 0.0f;
    const float alpha = 0.98f;
    uint32_t last_cyccnt = DWT->CYCCNT;   /* dt için DWT (µs hassas) */

    /* Aşama 2.7 — IMU mirror durumu (MODE:MIRROR).
     * θ_ref = clamp(fused_pitch − pitch0, ±60°), slew 90°/s ile yumuşatılır.
     *   pitch0: MIRROR'a geçiş anındaki pitch (göreli referans, ani sıçrama yok)
     *   clamp ±60°: ±90° complementary singülaritesinden (atan2) uzak + motor güvenli
     *   slew: ani breadboard sarsıntısında hedef sıçramasın (cascade ωc 1.9 rad/s) */
    const float MIRROR_CLAMP_DEG = 60.0f;
    const float MIRROR_SLEW_DPS  = 90.0f;
    static float mirror_pitch0   = 0.0f;   /* göreli referans (geçiş anı pitch) */
    static float mirror_ref      = 0.0f;   /* slew sonrası uygulanan θ_ref (derece) */
    static bool  mirror_prev     = false;  /* MIRROR'a yeni giriş edge-detect */

    uint32_t last_tx          = 0;
    uint32_t last_led         = 0;
    bool     watchdog_tripped = false;   /* edge-detect — WATCHDOG_TIMEOUT mesajı */

    while (1)
    {
        MPU6050_Read(&ax, &ay, &az, &gx, &gy, &gz);

        uint32_t now = HAL_GetTick();   /* ms — watchdog / TX throttle / LED için */

        /* dt: DWT cycle counter ile µs hassas (Aşama 2.3).
         * HAL_GetTick ms çözünürlüğü loop ~7 ms'te ±14% jitter veriyordu →
         * ω = Δcount/dt ölçümünü bozup hız PI'yi bang-bang'e sokuyordu.
         * DWT 96 MHz → dt çözünürlüğü ~10 ns. Unsigned fark wrap-safe. */
        uint32_t cyc_now  = DWT->CYCCNT;
        uint32_t cyc_diff = cyc_now - last_cyccnt;   /* wrap-safe (unsigned) */
        last_cyccnt = cyc_now;
        float dt = (float)cyc_diff / 96000000.0f;     /* SYSCLK 96 MHz */
        if (dt <= 0.0f || dt > 0.5f) dt = 0.005f;     /* ilk döngü / overflow koruması */

        int32_t enc_count = Encoder_GetCount();
        float   enc_speed = Encoder_GetSpeed(dt);            /* ham motor şaftı rad/s */
        float   enc_speed_filt = Encoder_FilterSpeed(enc_speed);  /* moving avg — PI girişi */

        /* PA0 KEY butonu (active-low) → fake stall injection */
        bool key_pressed = (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET);
        Motor_DebugInjectFakeStall(key_pressed);

        /* Stall detection — her iterasyonda (~140 Hz, döngü ~7 ms) */
        Motor_StallCheck(enc_speed);

        /* Watchdog — 1 sn boyunca komut yoksa Motor_Stop. Edge'de USB CDC'ye
         * 'WATCHDOG_TIMEOUT\r\n' bir kerelik mesaj (sürekli flood yok).
         * ⚠ Aşama 2.5: watchdog aktifken mod sürüşü ATLANMALI — yoksa kapalı
         * döngü (SP_W/POS) Motor_Stop'u hemen ezer, motor dönmeye devam eder.
         * SpeedPI_Reset setpoint'i de 0'lar → komut akışı kesilince motor durur. */
        bool wd_active = (now - CmdParser_LastCmdTick() > 1000U);
        if (wd_active) {
            Motor_Stop();
            SpeedPI_Reset();
            if (!watchdog_tripped) {
                static const char ev[] = "WATCHDOG_TIMEOUT\r\n";
                CDC_Transmit_FS((uint8_t *)ev, (uint16_t)(sizeof(ev) - 1U));
                watchdog_tripped = true;
            }
        } else {
            watchdog_tripped = false;
        }

        /* ── Sensör füzyonu (mod sürüşünden ÖNCE — MIRROR modu fused_pitch kullanır) ── */
        float fax = (float)ax, fay = (float)ay, faz = (float)az;
        float pitch = atan2f(fax, sqrtf(fay*fay + faz*faz)) * RAD2DEG;   /* ivmeölçer açısı */
        float roll  = atan2f(fay, sqrtf(fax*fax + faz*faz)) * RAD2DEG;
        float gx_dps = (float)gx / 131.0f;   /* gyro ±250°/s → 131 LSB/(°/s) */
        float gy_dps = (float)gy / 131.0f;
        /* Complementary filter: pitch→Y ekseni (gy), roll→X ekseni (gx) */
        fused_pitch = alpha * (fused_pitch - gy_dps * dt) + (1.0f - alpha) * pitch;
        fused_roll  = alpha * (fused_roll  + gx_dps * dt) + (1.0f - alpha) * roll;

        /* MIRROR'a yeni giriş (edge): göreli referans pitch0 + slew durumu sıfırla */
        bool is_mirror = (CmdParser_GetMode() == CMD_MODE_MIRROR);
        if (is_mirror && !mirror_prev) { mirror_pitch0 = fused_pitch; mirror_ref = 0.0f; }
        mirror_prev = is_mirror;
        if (wd_active) mirror_ref = 0.0f;   /* watchdog: hedef sıfırla (komut kesilince güvenli) */

        /* ── Mod-bağımlı motor sürüş (watchdog aktifken atlanır) ────────
         * DUTY: Motor_Tick rampa. SP_W: hız PI. POS: cascade (poz P → hız PI).
         * MIRROR (Aşama 2.7): θ_ref = clamp(fused_pitch−pitch0, ±60°), slew 90°/s
         *   → POS cascade ile motor IMU pitch'ini takip eder (ayna/taklit). */
        if (!wd_active) {
            if (CmdParser_GetMode() == CMD_MODE_SP_W) {
                /* PI girişi FİLTRELENMİŞ hız (moving average — ham kuantize ölçüm). */
                float u = SpeedPI_Step(enc_speed_filt);
                Motor_SetDutySigned(u);   /* doğrudan, rampasız */
            } else if (CmdParser_GetMode() == CMD_MODE_POS) {
                float omega_ref = PositionP_Step(enc_count, NULL);
                SpeedPI_SetSetpoint(omega_ref);          /* dış döngü → iç döngü setpoint */
                float u = SpeedPI_Step(enc_speed_filt);
                Motor_SetDutySigned(u);
            } else if (is_mirror) {
                /* Hedef: göreli pitch, ±60° clamp (singülarite + güvenlik) */
                float target = fused_pitch - mirror_pitch0;
                if (target >  MIRROR_CLAMP_DEG) target =  MIRROR_CLAMP_DEG;
                if (target < -MIRROR_CLAMP_DEG) target = -MIRROR_CLAMP_DEG;
                /* Slew limit (90°/s): ani IMU sıçramasını yumuşat (dt — DWT µs) */
                float max_step = MIRROR_SLEW_DPS * dt;
                float d = target - mirror_ref;
                if      (d >  max_step) mirror_ref += max_step;
                else if (d < -max_step) mirror_ref -= max_step;
                else                    mirror_ref  = target;
                /* Cascade: θ_ref → poz P → ω_ref → hız PI → motor */
                PositionP_SetSetpoint(mirror_ref);
                float omega_ref = PositionP_Step(enc_count, NULL);
                SpeedPI_SetSetpoint(omega_ref);
                float u = SpeedPI_Step(enc_speed_filt);
                Motor_SetDutySigned(u);
            } else {
                Motor_Tick();             /* DUTY modu rampa */
            }
        }

        /* USB CDC transmit — 40 Hz throttle (her 25 ms'de bir).
         * T_US: DWT.CYCCNT / 96 → mikrosaniye timestamp ([ARM_DWT]).
         * OMEGA: firmware'in hesapladığı motor şaftı hızı (rad/s, signed).
         * EC: ham encoder count (long, signed).
         * SP: hız PI setpoint (rad/s) — sadece SP_W modda anlamlı, DUTY modda 0.
         * U:  hız PI kontrol çıkışı (signed duty) — son SpeedPI_Step sonucu.
         * TR: pozisyon hedefi (çıkış mili derece) — POS/MIRROR modda anlamlı (takip hatası
         *     analizi: TR vs EC×360/466). MIRROR'da slew'li göreli pitch hedefi. */
        if (now - last_tx >= 25U) {
            uint32_t t_us = DWT->CYCCNT / 96U;
            float sp = SpeedPI_GetSetpoint();
            float u  = SpeedPI_GetControl();
            float tr = PositionP_GetSetpoint();   /* θ_ref derece (POS/MIRROR) */
            int len = snprintf(buf, sizeof(buf),
                "T_US:%lu,P:%.1f,R:%.1f,GX:%.1f,GY:%.1f,FP:%.1f,FR:%.1f,EC:%ld,OMEGA:%.1f,SP:%.1f,U:%.3f,TR:%.1f\r\n",
                (unsigned long)t_us,
                pitch, roll, gx_dps, gy_dps, fused_pitch, fused_roll,
                (long)enc_count, enc_speed, sp, u, tr);
            CDC_Transmit_FS((uint8_t *)buf, (uint16_t)len);
            last_tx = now;
        }

        /* Stall event — tetik anında bir kerelik USB mesajı.
         * Stall sırasında Motor_SetDuty reddedildiği için SP_W modda PI integrator
         * wind-up etmemesi için resetlenir (lockout dolduktan sonra ani patlama yok). */
        if (Motor_PollStallEvent()) {
            SpeedPI_Reset();
            static const char ev[] = "STALL_DETECTED\r\n";
            CDC_Transmit_FS((uint8_t *)ev, (uint16_t)(sizeof(ev) - 1));
        }

        /* LED durum kodu: normal 500 ms, stall 100 ms toggle (5 Hz) */
        uint32_t led_period = Motor_IsStalled() ? 100U : 500U;
        if (now - last_led >= led_period) {
            HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
            last_led = now;
        }

        HAL_Delay(5);
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
