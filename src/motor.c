#include "motor.h"
#include "stm32f4xx_hal.h"
#include <math.h>
#include <stdbool.h>

/* ============================================================================
 * TB6612FNG sürücü — iskelet
 * Detaylar için → include/motor.h
 * ============================================================================ */

#define MOTOR_PWM_PERIOD     4799U  /* ARR for 20 kHz @ 96 MHz / (1 × 4800) */
#define MOTOR_MAX_DUTY       0.50f  /* hard cap. Stall@0.5≈0.55 A < TB6612 sürekli 1.0 A
                                     * (amper bütçesi asama_0 §8.5; sigorta yok → konservatif).
                                     * 2026-06-09: 0.70 denendi → motor-1 CW catch'i YENMEDİ
                                     * (tork↑'da rate↓ = sert mekanik catch, stiction değil) +
                                     * jam akımını 0.77 A'e çıkarıyordu → 0.50'ye geri dönüldü.
                                     * Headroom Aşama 5'te (yük + sigorta/ACS712 foldback) açılır. */
#define MOTOR_RAMP_STEP      0.01f  /* her tick'te duty değişimi */
#define MOTOR_DEAD_THRESHOLD 0.10f  /* |Δ| > 0.10 ise rampa, ≤ 0.10 ise direkt */
#define MOTOR_SOFT_STEP_MS   5U     /* SoftStart blok rampa step bekleme */

/* Stall detection — COUNT-TABANLI (2026-05-31; gerekçe → include/motor.h):
 * 200 ms pencerede |Δcount| < STALL_COUNT_TH → "dönmüyor". 1 count/200 ms
 * = 0.67 rad/s motor-şaftı çözünürlüğü (eski anlık-hız yolunun 18.7 rad/s
 * kuantizasyonuna karşı 28× ince) — yavaş takip artık yanlış tetiklemez.
 * Kaynak: [Pololu_25D] 48 CPR. Lockout 1 sn (eski 5 sn): duty-cap %50'de
 * stall ~0.55-0.8 A < TB6612 sürekli 1.0 A (docs/asama_0 §8.5 amper bütçesi)
 * → kesme dişli koruması, hızlı oto-toparlanma yeterli. */
#define STALL_COUNT_TH       2       /* count/pencere — altı "dönmüyor" (≈|ω|<1.35 rad/s motor) */
#define STALL_DUTY_TH        0.20f   /* duty eşiği */
#define STALL_DURATION_MS    200U    /* tetik penceresi */
#define LOCKOUT_DURATION_MS  1000U   /* lockout süresi (5000→1000: yumuşatma) */

static TIM_HandleTypeDef htim3;

/* Non-blocking rampa state — Motor_Tick her main iterasyonunda günceller. */
static float current_duty = 0.0f;
static float target_duty  = 0.0f;

/* Stall / lockout state */
static uint32_t stall_count_ms      = 0;
static int32_t  stall_ref_count     = 0;      /* pencere başlangıç encoder count'u */
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

    /* Hard cap MOTOR_MAX_DUTY (0.50f) — Stall'da pik akım ~0.55-0.8 A,
     * TB6612 sürekli operating limiti 1.0 A'in altında ([TB6612_DS] sf 3;
     * eski yorumdaki "1.2 A continuous" yanlıştı — 1.2 A pulse-koşullu abs-max).
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

/* Aşama 2.3 ara test — kapalı döngü için doğrudan PWM yazma.
 * Motor_SetDuty + Motor_Tick (Aşama 0 soft-start rampası) AÇIK DÖNGÜ içindi;
 * hız PI ile kullanılınca rampa + dead-band clamp kontrol sinyalini bozuyordu
 * (PI ±0.5 zıplayınca |Δ|>0.10 → rampa devreye → kontrolcü ile çakışma).
 * Bu fonksiyon: signed duty → yön + |duty|, RAMPA YOK, dead-band YOK.
 * Lockout + saturation (±MOTOR_MAX_DUTY) korunur. current/target senkron
 * tutulur (stall check current_duty kullanıyor). */
void Motor_SetDutySigned(float duty)
{
    if (stall_active) return;   /* lockout — reddet */

    /* Signed saturation ±MOTOR_MAX_DUTY */
    float d = duty;
    if (d >  MOTOR_MAX_DUTY) d =  MOTOR_MAX_DUTY;
    if (d < -MOTOR_MAX_DUTY) d = -MOTOR_MAX_DUTY;

    float mag = (d >= 0.0f) ? d : -d;
    Motor_SetDir((d >= 0.0f) ? MOTOR_CW : MOTOR_CCW);
    current_duty = mag;   /* rampa state senkron — stall check tutarlı */
    target_duty  = mag;
    _apply_pwm(mag);
}

void Motor_Tick(void)
{
    /* Main loop'tan her iterasyonda (~140 Hz, döngü ~7 ms) çağrılır.
     * current_duty → target_duty arasında 0.01 step ile yaklaşır.
     * ~30 step × ~7 ms ≈ 210 ms (büyük sıçrama için tipik rampa süresi). */
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

void Motor_StallCheck(int32_t enc_count)
{
    uint32_t now = HAL_GetTick();

    /* Lockout otomatik açılma — süre dolunca sürücüyü tekrar aktive et */
    if (stall_active && now >= lockout_until_ms) {
        stall_active     = false;
        lockout_until_ms = 0;
        HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);  /* STBY=H */
    }

    if (stall_active) {
        /* Lockout süresince kontrol yapma */
        last_check_tick = now;
        stall_count_ms  = 0;
        stall_ref_count = enc_count;
        return;
    }

    /* Rampa sırasında bypass (current ≠ target) — yanlış pozitif önleme */
    if (fabsf(current_duty - target_duty) > 0.005f) {
        stall_count_ms  = 0;
        stall_ref_count = enc_count;
        last_check_tick = now;
        return;
    }

    /* Tick periyodu — main loop ~5-10 ms, ilk çağrı veya overflow için clamp */
    uint32_t dt = (last_check_tick == 0U) ? 5U : (now - last_check_tick);
    last_check_tick = now;
    if (dt > 100U) dt = 5U;

    /* Duty eşiği altında pencereyi sıfırla — düşük güçte stall anlamsız */
    if (current_duty <= STALL_DUTY_TH) {
        stall_count_ms  = 0;
        stall_ref_count = enc_count;
        return;
    }

    /* Count deltası — fake_stall debug injection deltayı 0 zorlar (kilitli
     * rotor simülasyonu). int32 fark wrap-safe; pencere içi delta küçük. */
    int32_t delta = enc_count - stall_ref_count;
    if (fake_stall_inject) delta = 0;

    if (delta >= STALL_COUNT_TH || delta <= -STALL_COUNT_TH) {
        /* Mil dönüyor — pencereyi yeni referansla baştan başlat */
        stall_count_ms  = 0;
        stall_ref_count = enc_count;
        return;
    }

    /* |Δcount| < eşik VE duty yüksek → "dönmüyor" sayacı işlesin */
    stall_count_ms += dt;
    if (stall_count_ms >= STALL_DURATION_MS) {
        /* STALL TETİK — kesici durdurma + 1 sn lockout (oto-toparlanma) */
        stall_event_pending = true;
        stall_count_ms      = 0;
        stall_ref_count     = enc_count;
        lockout_until_ms    = now + LOCKOUT_DURATION_MS;
        Motor_EmergencyStop();
        stall_active        = true;  /* EmergencyStop sonrası set — sıra önemli */
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

/* ============================================================================
 * MOTOR-2 (Aşama 3.2b) — 2. TB6612, A-kanalı. Detay → include/motor.h.
 * htim3 PAYLAŞILIR (motor-1 ile aynı TIM3); motor-2 yalnız CH4 kullanır.
 * MİNİMAL açık-döngü sürücü: stall/lockout YOK (3.3'te eklenecek).
 * ============================================================================ */

static float current_duty2 = 0.0f;   /* son uygulanan signed duty (telemetri) */

static inline void _apply_pwm2(float mag)
{
    uint32_t ccr = (uint32_t)(mag * (float)(MOTOR_PWM_PERIOD + 1U));
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_4, ccr);
}

void Motor2_Init(void)
{
    /* GPIOB + TIM3 clock'ları Motor_Init'te zaten açıldı; tekrar zararsız. */
    __HAL_RCC_GPIOB_CLK_ENABLE();

    /* ── PB4 (AIN1), PB5 (AIN2), PB10 (STBY-2) — GPIO output, başlangıç LOW.
     * Motor-2 Hi-Z + sürücü standby → güvenli kapalı. PB4=JTRST: encoder-1
     * (PA15/PB3) zaten SW-DP modunu zorladığından PB4 GPIO olarak serbest.
     * TB6612 AIN pinlerinde dahili 200 kΩ pull-down (datasheet sf 2) → STBY=L
     * iken motor seğirmez. */
    GPIO_InitTypeDef gpio_out = {0};
    gpio_out.Pin   = GPIO_PIN_4 | GPIO_PIN_5 | GPIO_PIN_10;
    gpio_out.Mode  = GPIO_MODE_OUTPUT_PP;
    gpio_out.Pull  = GPIO_NOPULL;
    gpio_out.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOB, &gpio_out);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_4 | GPIO_PIN_5 | GPIO_PIN_10, GPIO_PIN_RESET);

    /* ── PB1 — TIM3_CH4 PWM çıkışı (AF2_TIM3, motor-1 PB0=CH3 ile aynı timer) */
    GPIO_InitTypeDef gpio_pwm = {0};
    gpio_pwm.Pin       = GPIO_PIN_1;
    gpio_pwm.Mode      = GPIO_MODE_AF_PP;
    gpio_pwm.Pull      = GPIO_NOPULL;
    gpio_pwm.Speed     = GPIO_SPEED_FREQ_HIGH;
    gpio_pwm.Alternate = GPIO_AF2_TIM3;
    HAL_GPIO_Init(GPIOB, &gpio_pwm);

    /* ── CH4'ü çalışan htim3'e ekle (base + CH3 Motor_Init'te kuruldu) */
    TIM_OC_InitTypeDef sConfigOC = {0};
    sConfigOC.OCMode     = TIM_OCMODE_PWM1;
    sConfigOC.Pulse      = 0;
    sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
    sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
    HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_4);
    HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_4);

    current_duty2 = 0.0f;
}

void Motor2_Enable(void)
{
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_10, GPIO_PIN_SET);    /* STBY-2 = HIGH */
}

void Motor2_Disable(void)
{
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_10, GPIO_PIN_RESET);  /* STBY-2 = LOW  */
}

void Motor2_SetDir(MotorDir_t dir)
{
    /* TB6612 H-SW (motor-1 ile aynı, datasheet sf 4): AIN1=PB4, AIN2=PB5 */
    GPIO_PinState a1, a2;
    switch (dir) {
        case MOTOR_CW:    a1 = GPIO_PIN_SET;   a2 = GPIO_PIN_RESET; break;
        case MOTOR_CCW:   a1 = GPIO_PIN_RESET; a2 = GPIO_PIN_SET;   break;
        case MOTOR_BRAKE: a1 = GPIO_PIN_SET;   a2 = GPIO_PIN_SET;   break;
        case MOTOR_STOP:
        default:          a1 = GPIO_PIN_RESET; a2 = GPIO_PIN_RESET; break;
    }
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_4, a1);   /* AIN1-2 */
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_5, a2);   /* AIN2-2 */
}

void Motor2_SetDutySigned(float duty)
{
    /* signed → yön + |duty|, RAMPASIZ (açık-döngü test aktüatörü).
     * ±MOTOR_MAX_DUTY (0.50) clamp — motor-1 ile aynı emniyet kapağı. */
    float d = duty;
    if (d >  MOTOR_MAX_DUTY) d =  MOTOR_MAX_DUTY;
    if (d < -MOTOR_MAX_DUTY) d = -MOTOR_MAX_DUTY;

    float mag = (d >= 0.0f) ? d : -d;
    Motor2_SetDir((d >= 0.0f) ? MOTOR_CW : MOTOR_CCW);
    _apply_pwm2(mag);
    current_duty2 = d;
}

void Motor2_Stop(void)
{
    Motor2_SetDir(MOTOR_STOP);
    _apply_pwm2(0.0f);
    current_duty2 = 0.0f;
}

void Motor2_EmergencyStop(void)
{
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_10, GPIO_PIN_RESET);  /* STBY-2=L önce */
    _apply_pwm2(0.0f);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_4 | GPIO_PIN_5, GPIO_PIN_RESET);  /* AIN=0 */
    current_duty2 = 0.0f;
}

float Motor2_GetDutySigned(void)
{
    return current_duty2;
}
