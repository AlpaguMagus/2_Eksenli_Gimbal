#include "stm32f4xx_hal.h"
#include "usbd_core.h"
#include "usbd_desc.h"
#include "usbd_cdc.h"
#include "usbd_cdc_if.h"
#include "axis.h"
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
#define IMU_I2C_TIMEOUT_MS   3U            /* read timeout — stuck bus ana döngüyü bloklamasın */
#define IMU_FAIL_LIMIT       40U           /* ardışık başarısız okuma → kendini-iyileştir (~0.3 s) */

/* --- Global Handles --- */
USBD_HandleTypeDef hUsbDeviceFS;           /* usbd_cdc_if.c tarafından extern */
I2C_HandleTypeDef  hi2c1;

/* --- Eksen demetleri (Aşama 3.3 — axis.h) ---------------------------------
 * g_axis[0] = motor-1 ekseni (⚠ mevcut ünite CW-kusurlu, yedek bekleniyor)
 * g_axis[1] = motor-2 ekseni (karakterize SAĞLIKLI ünite — aktif geliştirme) */
Axis_t g_axis[AXIS_COUNT] = {
    { .motor = &Motor1, .enc_count = Encoder_GetCount,
      .enc_reset = Encoder_Reset,  .enc_speed = Encoder_GetSpeed,
      .mode = CMD_MODE_DUTY },
    { .motor = &Motor2, .enc_count = Encoder2_GetCount,
      .enc_reset = Encoder2_Reset, .enc_speed = Encoder2_GetSpeed,
      .mode = CMD_MODE_DUTY },
};

/* --- Prototip --- */
void SystemClock_Config(void);
void I2C1_Init(void);
void MPU6050_Init(void);
HAL_StatusTypeDef MPU6050_Read(int16_t *ax, int16_t *ay, int16_t *az,
                               int16_t *gx, int16_t *gy, int16_t *gz);
void MPU6050_Recover(void);   /* I2C bus-clear + re-init (kendini-iyileştirme) */

/* ================================================================
   MAIN
   ================================================================ */
int main(void)
{
    /* ─── Init sırası ─────────────────────────────────────────────────
     * 1) HAL + clock
     * 2) Periferik init'ler (I2C, MPU6050, Encoder×2, Motor×2)
     *      — MotorCh_Init STBY=LOW bırakır → motorlar güvenli kapalı
     * 3) USB CDC (host enumeration için 2 sn bekle)
     * 4) MotorCh_Enable EN SONDA — STBY=HIGH ile sürücüler aktif
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
    Encoder_Init();              /* TIM2, PA15+PB3 (eksen-0) */
    Encoder2_Init();             /* TIM1, PA8+PA9  (eksen-1, 16-bit→yazılım 32-bit) */
    MotorCh_Init(&Motor1);       /* TIM3 base + CH3, PB0 PWM, PB12-14 GPIO, STBY=LOW */
    MotorCh_Init(&Motor2);       /* TIM3 CH4, PB1 PWM, PB4/PB5/PB10 GPIO, STBY=LOW */

    /* Hız iç döngü PI kazançları — HER İKİ EKSENE AYNI set yüklenir:
     * kazançlar Aşama 1-2'de karakterize edilen üniteye göre tasarlandı
     * (o ünite rewire sonrası MOTOR-2 ekseninde); motor-1 ekseni yeni motor
     * gelince aynı başlangıç setiyle doğrulanacak (3.4 MIMO ID zaten ölçer).
     *
     * ⚠ Aşama 2.3 BULGUSU: Aşama 2.1 Simulink tasarımı (conservative pole
     * placement Kp=0.1163, Ki=4.0447) gerçek sistemde BANG-BANG limit cycle
     * verdi. Kök neden: Simulink ideal ölçüm + farklı plant varsaydı; gerçekte
     * serbest mil çok hızlı (0.5 duty → ~280 rad/s no-load) + encoder kuantize
     * + yüksek Kp her error'da saturation'a fırlatıyordu → limit cycle.
     *
     * ANALİTİK DÜZELTME (design_speed_pi_corrected.m, docs §11.11.3): doyum-kısıtı
     * Kp≈duty_max/ω_max=0.002 + doğru-plant (Kg=K·Vs=654.8) pole placement
     * ω_n=2/τ=33 → Ki=0.1. Conservative'den ~58× düşük; tüm setpoint'lere temiz
     * oturur (50/120/30 rad/s, bang-bang yok). 2b gerçekçi Simulink + ayrık margin doğruladı.
     *
     * Runtime KP:/KI:/SLEW: (+2 sonekli eksen-1) komutlarıyla flash'sız ayarlanabilir.
     * Kaynaklar: [AstromMurray2008] §10.2 (Tustin), §10.4 (back-calculation) */
    static const SpeedPI_Config SPEED_PI_CFG = {
        .Kp       = 0.002f,           /* analitik: doyum-kısıtı Kp≈duty_max/ω_max
                                       * (design_speed_pi_corrected.m, docs §11.11.3);
                                       * 2.1 conservative 58× yüksekti (P-term doyar → bang-bang) */
        .Ki       = 0.1f,
        .Ts       = 0.005f,           /* Tustin SABIT adımı (5 ms = 200 Hz NOMINAL).
                                       * DİKKAT: gerçek ana döngü ~7 ms (~140 Hz, docs
                                       * asama_0 §5.4) — Ts gerçek dt değil. Efektif integral
                                       * kazancı nominalin Ts/dt≈5/7≈0.71 katı; Ki=0.1 bu
                                       * sabit-Ts varsayımı altında geçerli (donanımda doğrulandı).
                                       * Döngü hızı değişir/Ts gerçek dt'ye bağlanırsa integral
                                       * etkisi sessizce kayar (latent kuplaj — docs §11.11.8 notu). */
        .duty_max = 0.50f,            /* = MOTOR_MAX_DUTY firmware tarafı (0.70 denendi, motor-1
                                       * CW catch'i yenmedi → 0.50'de kalındı, motor.c notu) */
        .T_t      = 0.02f             /* Kp/Ki — Aström-Murray T_t = T_i */
    };

    /* Pozisyon dış döngü P kontrolcü (Aşama 2.5 — cascade).
     * Kp_pos=2.0 [1/s]: matlab/asama_2_kontrol/design_position_p.m
     *   dış döngü ω_c≈1.93 rad/s, cascade kuralı gereği iç döngüden ~5× yavaş [Franklin2010 §6.4]
     *   (ilk tahmin iç ω_n≈9.4; Vsupply dahil gerçek ω_n≈33 → ayrım ~16×, docs §11.13.2b)
     *   PM 69.7°, tip-1 → P ile ss_error=0 [Franklin2010 §4.3]
     * Gerçek motor: Test 2.5 PASS (6/6 segment, ss_err<0.8°, limit-cycle YOK). */
    static const PositionP_Config POS_P_CFG = {
        .Kp_pos         = 2.0f,
        .gear_ratio     = 9.7f,
        .counts_per_rev = 466.0f,   /* 48 × 9.7 (çıkış mili event/rev) */
        .omega_ref_max  = 300.0f    /* rad/s motor şaftı güvenlik limiti */
    };

    for (int i = 0; i < AXIS_COUNT; i++) {
        SpeedPI_Init(&g_axis[i].spi, &SPEED_PI_CFG);
        PositionP_Init(&g_axis[i].ppos, &POS_P_CFG);
        SpeedFilter_Reset(&g_axis[i].filt);
    }

    /* USB CDC başlat */
    USBD_Init(&hUsbDeviceFS, &CDC_Desc, DEVICE_FS);
    USBD_RegisterClass(&hUsbDeviceFS, &USBD_CDC);
    USBD_CDC_RegisterInterface(&hUsbDeviceFS, &USBD_Interface_fops_FS);
    USBD_Start(&hUsbDeviceFS);

    HAL_Delay(2000);           /* Host'un /dev/ttyACM0'ı tanıması için bekle */

    MotorCh_Enable(&Motor1);   /* STBY=HIGH — sürücüler artık aktif */
    MotorCh_Enable(&Motor2);

    int16_t ax_=0, ay_=0, az_=0, gx_=0, gy_=0, gz_=0;   /* 0-init: ilk-döngü çöp okuması
                                                          * uyku-tespitini yanıltmasın */
    char    buf[240];   /* telemetri: eksen-0 alanları (eski format) + OMEGA2/SP2/TR2 */

    /* Complementary filter durumu */
    float fused_pitch = 0.0f;
    float fused_roll  = 0.0f;
    const float alpha = 0.98f;
    uint32_t last_cyccnt = DWT->CYCCNT;   /* dt için DWT (µs hassas) */

    /* Aşama 2.7 — IMU mirror parametreleri (eksen durumu Axis_t içinde).
     * θ_ref = clamp(fused_pitch − pitch0, ±60°), slew 90°/s ile yumuşatılır.
     *   pitch0: MIRROR'a geçiş anındaki pitch (göreli referans, ani sıçrama yok)
     *   clamp ±60°: ±90° complementary singülaritesinden (atan2) uzak + motor güvenli
     *   slew: ani breadboard sarsıntısında hedef sıçramasın (cascade ωc 1.9 rad/s)
     * Bugün her iki eksenin MIRROR hedefi fused_pitch (tek-IMU demo);
     * Aşama 5'te eksen→pitch/roll eşlemesi yapılır. */
    const float MIRROR_CLAMP_DEG = 60.0f;
    const float MIRROR_SLEW_DPS  = 90.0f;

    uint32_t last_tx          = 0;
    uint32_t last_led         = 0;
    bool     watchdog_tripped = false;   /* edge-detect — WATCHDOG_TIMEOUT mesajı */
    uint32_t imu_fail         = 0;       /* ardışık IMU okuma hatası sayacı */
    uint32_t last_imu_recover = 0;       /* son kendini-iyileştirme zamanı (cooldown) */

    int32_t counts[AXIS_COUNT] = {0};    /* eksen-başına telemetri ara değerleri */
    float   raw_w[AXIS_COUNT]  = {0};
    float   filt_w[AXIS_COUNT] = {0};

    while (1)
    {
        HAL_StatusTypeDef imu_st = MPU6050_Read(&ax_, &ay_, &az_, &gx_, &gy_, &gz_);

        uint32_t now = HAL_GetTick();   /* ms — watchdog / TX throttle / LED için */

        /* IMU KENDİNİ-İYİLEŞTİRME — İKİ ARIZA MODU (2026-06-09 bus; 2026-06-12 uyku):
         * (1) BUS hatası: read != HAL_OK (timeout/stuck SDA) → I2C bus-clear + re-init
         *     (MPU6050_Recover) → 'IMU_RECOVER'.
         * (2) UYKU: read HAL_OK ama TÜM 6 eksen tam 0 → motor anahtarlama güç-glitch'i
         *     çipi uykuya soktu (canlı IMU asla 6-sıfır okumaz; yerçekimi bir eksende
         *     ~16384). Bus sağlam → yalnız uyandır (MPU6050_Init, non-blocking) →
         *     'IMU_WAKE'. (Mirror incident 2026-06-12: eski self-heal yalnız bus-hatası
         *     yakalıyordu; uyku sıfır-veri HAL_OK ile geçip FP=0 sabit kalıyordu.)
         * İkisi de IMU_FAIL_LIMIT ardışık + ≥2 s cooldown (kontrol döngüsünü hitch'lemesin). */
        bool imu_zero = (ax_==0 && ay_==0 && az_==0 && gx_==0 && gy_==0 && gz_==0);
        if (imu_st != HAL_OK || imu_zero) {
            if (++imu_fail >= IMU_FAIL_LIMIT && (now - last_imu_recover) >= 2000U) {
                if (imu_st == HAL_OK) {            /* uyku: bus sağlam, yalnız uyandır */
                    MPU6050_Init();
                    static const char ev[] = "IMU_WAKE\r\n";
                    CDC_Transmit_FS((uint8_t *)ev, (uint16_t)(sizeof(ev) - 1U));
                } else {                           /* bus hatası: tam kurtarma */
                    MPU6050_Recover();
                    static const char ev[] = "IMU_RECOVER\r\n";
                    CDC_Transmit_FS((uint8_t *)ev, (uint16_t)(sizeof(ev) - 1U));
                }
                last_imu_recover = now;
                imu_fail = 0;
            }
        } else {
            imu_fail = 0;
        }

        /* dt: DWT cycle counter ile µs hassas (Aşama 2.3).
         * HAL_GetTick ms çözünürlüğü loop ~7 ms'te ±14% jitter veriyordu →
         * ω = Δcount/dt ölçümünü bozup hız PI'yi bang-bang'e sokuyordu.
         * DWT 96 MHz → dt çözünürlüğü ~10 ns. Unsigned fark wrap-safe. */
        uint32_t cyc_now  = DWT->CYCCNT;
        uint32_t cyc_diff = cyc_now - last_cyccnt;   /* wrap-safe (unsigned) */
        last_cyccnt = cyc_now;
        float dt = (float)cyc_diff / 96000000.0f;     /* SYSCLK 96 MHz */
        if (dt <= 0.0f || dt > 0.5f) dt = 0.005f;     /* ilk döngü / overflow koruması */

        /* PA0 KEY butonu (active-low) → fake stall injection (her iki eksen —
         * debug; basılıyken her iki stall penceresi delta=0 görür) */
        bool key_pressed = (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET);
        for (int i = 0; i < AXIS_COUNT; i++)
            MotorCh_InjectFakeStall(g_axis[i].motor, key_pressed);

        /* ── Eksen ölçümleri + stall (her iterasyon ~140 Hz) ──────────
         * Stall COUNT-tabanlı (2026-05-31, gerekçe motor.h): anlık hız
         * 1 count = 18.7 rad/s kuantize olduğundan yavaş takipte yanlış-pozitif
         * veriyordu. raw hız yalnız telemetri + PI (filtreli) içindir. */
        for (int i = 0; i < AXIS_COUNT; i++) {
            Axis_t *axp = &g_axis[i];
            counts[i] = axp->enc_count();
            raw_w[i]  = axp->enc_speed(dt);
            filt_w[i] = SpeedFilter_Step(&axp->filt, raw_w[i]);
            MotorCh_StallCheck(axp->motor, counts[i]);
        }

        /* Watchdog — 1 sn boyunca komut yoksa tüm eksenleri durdur. Edge'de USB
         * CDC'ye 'WATCHDOG_TIMEOUT\r\n' bir kerelik mesaj (sürekli flood yok).
         * ⚠ Aşama 2.5: watchdog aktifken mod sürüşü ATLANMALI — yoksa kapalı
         * döngü (SP_W/POS) Stop'u hemen ezer, motor dönmeye devam eder.
         * SpeedPI_Reset setpoint'i de 0'lar → komut akışı kesilince motor durur. */
        bool wd_active = (now - CmdParser_LastCmdTick() > 1000U);
        if (wd_active) {
            for (int i = 0; i < AXIS_COUNT; i++) {
                MotorCh_Stop(g_axis[i].motor);
                SpeedPI_Reset(&g_axis[i].spi);
            }
            if (!watchdog_tripped) {
                static const char ev[] = "WATCHDOG_TIMEOUT\r\n";
                CDC_Transmit_FS((uint8_t *)ev, (uint16_t)(sizeof(ev) - 1U));
                watchdog_tripped = true;
            }
        } else {
            watchdog_tripped = false;
        }

        /* ── Sensör füzyonu (mod sürüşünden ÖNCE — MIRROR modu fused_pitch kullanır) ── */
        float fax = (float)ax_, fay = (float)ay_, faz = (float)az_;
        float pitch = atan2f(fax, sqrtf(fay*fay + faz*faz)) * RAD2DEG;   /* ivmeölçer açısı */
        float roll  = atan2f(fay, sqrtf(fax*fax + faz*faz)) * RAD2DEG;
        float gx_dps = (float)gx_ / 131.0f;   /* gyro ±250°/s → 131 LSB/(°/s) */
        float gy_dps = (float)gy_ / 131.0f;
        /* Complementary filter: pitch→Y ekseni (gy), roll→X ekseni (gx) */
        fused_pitch = alpha * (fused_pitch - gy_dps * dt) + (1.0f - alpha) * pitch;
        fused_roll  = alpha * (fused_roll  + gx_dps * dt) + (1.0f - alpha) * roll;

        /* ── Mod-bağımlı eksen sürüşleri (watchdog aktifken atlanır) ────
         * DUTY: MotorCh_Tick rampa. SP_W: hız PI. POS: cascade (poz P → hız PI).
         * MIRROR (Aşama 2.7): θ_ref = clamp(fused_pitch−pitch0, ±60°), slew 90°/s
         *   → cascade ile eksen IMU pitch'ini takip eder (ayna/taklit). */
        for (int i = 0; i < AXIS_COUNT; i++) {
            Axis_t *axp = &g_axis[i];

            /* MIRROR'a yeni giriş (edge): göreli referans pitch0 + slew durumu sıfırla */
            bool is_mirror = (axp->mode == CMD_MODE_MIRROR);
            if (is_mirror && !axp->mirror_prev) { axp->mirror_pitch0 = fused_pitch; axp->mirror_ref = 0.0f; }
            axp->mirror_prev = is_mirror;
            if (wd_active) { axp->mirror_ref = 0.0f; continue; }   /* watchdog: hedef sıfırla */

            if (axp->mode == CMD_MODE_SP_W) {
                /* PI girişi FİLTRELENMİŞ hız (moving average — ham kuantize ölçüm). */
                float u = SpeedPI_Step(&axp->spi, filt_w[i]);
                MotorCh_SetDutySigned(axp->motor, u);   /* doğrudan, rampasız */
            } else if (axp->mode == CMD_MODE_POS) {
                float omega_ref = PositionP_Step(&axp->ppos, counts[i], NULL);
                SpeedPI_SetSetpoint(&axp->spi, omega_ref);   /* dış döngü → iç döngü setpoint */
                float u = SpeedPI_Step(&axp->spi, filt_w[i]);
                MotorCh_SetDutySigned(axp->motor, u);
            } else if (is_mirror) {
                /* Hedef: göreli pitch, ±60° clamp (singülarite + güvenlik) */
                float target = fused_pitch - axp->mirror_pitch0;
                if (target >  MIRROR_CLAMP_DEG) target =  MIRROR_CLAMP_DEG;
                if (target < -MIRROR_CLAMP_DEG) target = -MIRROR_CLAMP_DEG;
                /* Slew limit (90°/s): ani IMU sıçramasını yumuşat (dt — DWT µs) */
                float max_step = MIRROR_SLEW_DPS * dt;
                float d = target - axp->mirror_ref;
                if      (d >  max_step) axp->mirror_ref += max_step;
                else if (d < -max_step) axp->mirror_ref -= max_step;
                else                    axp->mirror_ref  = target;
                /* Cascade: θ_ref → poz P → ω_ref → hız PI → motor */
                PositionP_SetSetpoint(&axp->ppos, axp->mirror_ref);
                float omega_ref = PositionP_Step(&axp->ppos, counts[i], NULL);
                SpeedPI_SetSetpoint(&axp->spi, omega_ref);
                float u = SpeedPI_Step(&axp->spi, filt_w[i]);
                MotorCh_SetDutySigned(axp->motor, u);
            } else {
                MotorCh_Tick(axp->motor);             /* DUTY modu rampa */
            }
        }

        /* USB CDC transmit — 40 Hz throttle (her 25 ms'de bir).
         * T_US: DWT.CYCCNT / 96 → mikrosaniye timestamp ([ARM_DWT]).
         * Eksen-0 alanları (Aşama-2 script uyumlu, format korunur):
         *   EC, OMEGA (ham hız), SP, U (hız PI çıkışı), TR (poz hedefi, derece)
         * Eksen-1 alanları:
         *   EC2 (count), U2 (motor-2 uygulanan signed duty — 3.2b semantiği),
         *   OMEGA2/SP2/TR2 (yeni — satır SONUNDA, eski regex'leri bozmaz) */
        if (now - last_tx >= 25U) {
            uint32_t t_us = DWT->CYCCNT / 96U;
            float sp  = SpeedPI_GetSetpoint(&g_axis[0].spi);
            float u   = SpeedPI_GetControl(&g_axis[0].spi);
            float tr  = PositionP_GetSetpoint(&g_axis[0].ppos);
            float u2  = MotorCh_GetDutySigned(&Motor2);
            float sp2 = SpeedPI_GetSetpoint(&g_axis[1].spi);
            float tr2 = PositionP_GetSetpoint(&g_axis[1].ppos);
            int len = snprintf(buf, sizeof(buf),
                "T_US:%lu,P:%.1f,R:%.1f,GX:%.1f,GY:%.1f,FP:%.1f,FR:%.1f,EC:%ld,EC2:%ld,OMEGA:%.1f,SP:%.1f,U:%.3f,TR:%.1f,U2:%.3f,OMEGA2:%.1f,SP2:%.1f,TR2:%.1f\r\n",
                (unsigned long)t_us,
                pitch, roll, gx_dps, gy_dps, fused_pitch, fused_roll,
                (long)counts[0], (long)counts[1], raw_w[0], sp, u, tr,
                u2, raw_w[1], sp2, tr2);
            CDC_Transmit_FS((uint8_t *)buf, (uint16_t)len);
            last_tx = now;
        }

        /* Stall event — tetik anında bir kerelik USB mesajı (eksen-başına).
         * Eksen-0 mesajı Aşama-2 scriptleriyle uyum için AYNEN korunur;
         * eksen-1 '_2' sonekli. İlgili eksenin PI integrator'u resetlenir
         * (lockout dolduktan sonra ani patlama olmasın). */
        if (MotorCh_PollStallEvent(&Motor1)) {
            SpeedPI_Reset(&g_axis[0].spi);
            static const char ev1[] = "STALL_DETECTED\r\n";
            CDC_Transmit_FS((uint8_t *)ev1, (uint16_t)(sizeof(ev1) - 1));
        }
        if (MotorCh_PollStallEvent(&Motor2)) {
            SpeedPI_Reset(&g_axis[1].spi);
            static const char ev2[] = "STALL_DETECTED_2\r\n";
            CDC_Transmit_FS((uint8_t *)ev2, (uint16_t)(sizeof(ev2) - 1));
        }

        /* LED durum kodu: normal 500 ms, herhangi bir eksen stall'da 100 ms (5 Hz) */
        bool any_stalled = MotorCh_IsStalled(&Motor1) || MotorCh_IsStalled(&Motor2);
        uint32_t led_period = any_stalled ? 100U : 500U;
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
    /* PWR_MGMT_1 = 0 → uykudan uyandır + saat kaynağı internal.
     * ⚠ SONLU timeout (eski HAL_MAX_DELAY DEĞİL): IMU/bus wedge'liyken bloklayan
     * yazı ana döngüyü (ve boot'u) sonsuza kilitliyordu — 2026-06-12 mirror
     * incident'i. Başarısız olursa main loop'taki sleep-auto-recovery tekrar dener. */
    uint8_t data = 0x00;
    HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, MPU6050_PWR_MGMT_1,
                      I2C_MEMADD_SIZE_8BIT, &data, 1, 5U);   /* 5 ms timeout */
    HAL_Delay(50);
}

HAL_StatusTypeDef MPU6050_Read(int16_t *ax, int16_t *ay, int16_t *az,
                               int16_t *gx, int16_t *gy, int16_t *gz)
{
    uint8_t raw[14];
    /* Sonlu timeout (HAL_MAX_DELAY DEĞİL): stuck bus ana kontrol döngüsünü
     * sonsuza dek bloklamasın → kendini-iyileştirme tetiklenebilsin. */
    HAL_StatusTypeDef st = HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, MPU6050_ACCEL_XOUT_H,
                     I2C_MEMADD_SIZE_8BIT, raw, 14, IMU_I2C_TIMEOUT_MS);
    if (st != HAL_OK) return st;   /* başarısız → çağıran (main loop) iyileştirir */

    *ax = (int16_t)(raw[0]  << 8 | raw[1]);
    *ay = (int16_t)(raw[2]  << 8 | raw[3]);
    *az = (int16_t)(raw[4]  << 8 | raw[5]);
    /* raw[6..7] = TEMP — atla */
    *gx = (int16_t)(raw[8]  << 8 | raw[9]);
    *gy = (int16_t)(raw[10] << 8 | raw[11]);
    *gz = (int16_t)(raw[12] << 8 | raw[13]);
    return HAL_OK;
}

/* MPU6050_Recover — I2C kendini-iyileştirme (2026-06-09): sarsıntı/güç-glitch'i
 * IMU'yu uykuya VEYA I2C bus'ını stuck'a (köle SDA'yı low tutar) sokabilir.
 * (1) Stuck-bus temizleme: I2C'yi GPIO'ya alıp SCL'yi 9 kez clock'la + STOP üret
 *     → köle SDA'yı bırakır (klasik I2C kurtarma); (2) peripheral re-init;
 * (3) çipi uykudan uyandır (MPU6050_Init, PWR_MGMT_1=0). Init artık yalnız boot'ta
 * değil → bir sarsıntıdan sonra USB çek-tak GEREKMEZ, sistem kendini toparlar. */
void MPU6050_Recover(void)
{
    __HAL_RCC_GPIOB_CLK_ENABLE();
    HAL_I2C_DeInit(&hi2c1);

    GPIO_InitTypeDef g = {0};
    g.Mode  = GPIO_MODE_OUTPUT_OD;          /* open-drain — pull-up'lar high çeker */
    g.Pull  = GPIO_PULLUP;
    g.Speed = GPIO_SPEED_FREQ_LOW;
    g.Pin   = GPIO_PIN_6 | GPIO_PIN_7;      /* SCL=PB6, SDA=PB7 */
    HAL_GPIO_Init(GPIOB, &g);

    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_7, GPIO_PIN_SET);   /* SDA serbest bırak */
    for (int i = 0; i < 9; i++) {                          /* 9 SCL pulse */
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, GPIO_PIN_RESET); HAL_Delay(1);
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, GPIO_PIN_SET);   HAL_Delay(1);
    }
    /* STOP koşulu: SCL high iken SDA low→high */
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_7, GPIO_PIN_RESET); HAL_Delay(1);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, GPIO_PIN_SET);   HAL_Delay(1);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_7, GPIO_PIN_SET);   HAL_Delay(1);

    I2C1_Init();        /* peripheral yeniden (PB6/PB7 tekrar AF4_I2C1) */
    MPU6050_Init();     /* uykudan uyandır */
}

/* IMUDIAG — I2C/IMU sağlık teşhisi (2026-05-31; tekrarlayan bağlantı arızası):
 * bus ACK (0x68 + AD0-kayma kontrolü 0x69), kimlik (WHO_AM_I 0x75 == 0x68),
 * uyku durumu (PWR_MGMT_1 0x6B bit6) — [MPU6050_RM]. HAL rc: 0=OK 1=ERR 2=BUSY 3=TIMEOUT.
 * Yorum kılavuzu:
 *   r68=0 + who=68 + sleep=1 → çip BUS'ta ama UYKUDA (güç glitch'i; IMUINIT yeter,
 *                              USB çek-tak GEREKMEZ — Init yalnız boot'ta koştuğu için)
 *   r68≠0 ve r69=0           → AD0 teması kopmuş (adres 0x69'a kaymış)
 *   ikisi de ≠0              → bus/güç seviyesi arızası (kablo teması / modül) */
void MPU6050_DiagPrint(void)
{
    uint8_t who = 0xFF, pwr = 0xFF;
    HAL_StatusTypeDef r68 = HAL_I2C_IsDeviceReady(&hi2c1, MPU6050_ADDR, 2, 50);
    HAL_StatusTypeDef r69 = HAL_I2C_IsDeviceReady(&hi2c1, (uint16_t)(0x69 << 1), 2, 50);
    HAL_StatusTypeDef rw  = HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, 0x75,
                                             I2C_MEMADD_SIZE_8BIT, &who, 1, 50);
    HAL_StatusTypeDef rp  = HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, MPU6050_PWR_MGMT_1,
                                             I2C_MEMADD_SIZE_8BIT, &pwr, 1, 50);
    char dbuf[96];
    int len = snprintf(dbuf, sizeof(dbuf),
        "IMUDIAG r68:%d r69:%d who:%02X(rc%d) pwr:%02X(rc%d) sleep:%d\r\n",
        (int)r68, (int)r69, who, (int)rw, pwr, (int)rp, ((pwr & 0x40U) != 0U) ? 1 : 0);
    if (len > 0) CDC_Transmit_FS((uint8_t *)dbuf, (uint16_t)len);
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
