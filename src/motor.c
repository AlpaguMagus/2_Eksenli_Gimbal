#include "motor.h"
#include "stm32f4xx_hal.h"
#include <math.h>
#include <stdbool.h>

/* ============================================================================
 * TB6612FNG sürücü — kanal-instance (Aşama 3.3 refactor)
 * Detaylar için → include/motor.h
 * Davranış tek-kanallı Aşama-2 koduyla birebir; tek fark state'in struct'ta
 * taşınması (iki bağımsız örnek) + stall'ın motor-2'de de aktif olması.
 * ============================================================================ */

#define MOTOR_PWM_PERIOD     4799U  /* TB6612 ARR — 20 kHz @ 96 MHz / (1 × 4800); hızlı MOSFET kaldırır */
/* BTS7960/HW-039 — 20 kHz (işitme-üstü). [BTS7960_module_DS] (handsontec) sf1: "PWM capability of
 * up to 25 kHz" → önceki 1 kHz GEREKSİZ düşüktü. 1 kHz semptomları (teşhis 2026-06-15): işitilebilir
 * tiz whine (1 kHz tam işitme bandında) + yüksek tork-ripple ("geri tepme") + düşük-hız startup
 * stiction dropout'u (0.30/0.40'ta aralıklı dönmeme, İKİ HP'de de). Önceki "20 kHz'de tık-tık dönmez"
 * gözlemi aslında FİŞSİZ 12V idi (slew-rate DEĞİL) → yeniden-tanı 20 kHz'e çıkardı.
 * @96MHz: (0+1)×(4799+1)=4800 → 20 kHz (TB6612 ile aynı, datasheet ≤25 kHz içinde). */
#define BTS7960_PWM_ARR      4799U
#define BTS7960_PWM_PRESC    0U
#define MOTOR_MAX_DUTY       0.50f  /* hard cap. Stall@0.5≈0.55 A < TB6612 sürekli 1.0 A
                                     * (amper bütçesi asama_0 §8.5; sigorta yok → konservatif).
                                     * 2026-06-09: 0.70/0.85 denendi → motor-1 CW catch'i YENMEDİ
                                     * (tork↑'da rate↓ = sert mekanik catch, stiction değil) +
                                     * jam akımını artırıyordu → 0.50'de kalındı.
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

/* TIM3 = TB6612 PWM (motor-2); TIM4 = BTS7960 RPWM/LPWM (motor-1 HP). Base bir kez kurulur. */
static TIM_HandleTypeDef htim3;
static bool              tim3_base_ready = false;
static TIM_HandleTypeDef htim4;
static bool              tim4_base_ready = false;

/* ── Kanal örnekleri — pin haritası 00_donanim_semasi.md §2 ───────────────
 * Motor1 = eksen-0: HP Pololu (PL-4840, stall 5.6A) + HW-039/BTS7960 (Aşama 3.5,
 *          2026-06-14; eski TB6612-1+LP yerine — bozuk LP değişti, HP TB6612'yi aşar).
 *          RPWM=PB8(TIM4_CH3), LPWM=PB9(TIM4_CH4), R_EN+L_EN köprü=PB14. Enkoder DEĞİŞMEZ (PA15/PB3).
 * Motor2 = eksen-1: SAĞLIKLI LP Pololu + TB6612 (K=53.89/τ=60.5ms, DOĞRULANMIŞ — dokunma). */
MotorCh_t Motor1 = {
    .is_bts7960 = true,
    .pwm_channel  = TIM_CHANNEL_3, .pwm_pin  = GPIO_PIN_8,   /* RPWM = PB8 = TIM4_CH3 */
    .pwm_channel2 = TIM_CHANNEL_4, .pwm_pin2 = GPIO_PIN_9,   /* LPWM = PB9 = TIM4_CH4 */
    .stby_pin = GPIO_PIN_14,                                  /* R_EN+L_EN köprü = PB14 (enable) */
    .ain1_pin = 0, .ain2_pin = 0,                            /* BTS7960'da kullanılmaz */
};
MotorCh_t Motor2 = {
    .is_bts7960 = false,
    .pwm_channel = TIM_CHANNEL_4, .pwm_pin = GPIO_PIN_1,
    .ain1_pin = GPIO_PIN_4,  .ain2_pin = GPIO_PIN_5,  .stby_pin = GPIO_PIN_10,
};

static inline void _apply_pwm(MotorCh_t *m, float d)
{
    if (m->is_bts7960) {
        /* BTS7960: yöne göre RPWM VEYA LPWM; diğer kanal 0 (shoot-through koruması —
         * iki PWM aynı anda asla HIGH olmaz). STOP/BRAKE → ikisi de 0 (coast).
         * ccr BTS7960'ın KENDİ ARR'siyle (~1 kHz), TB6612'den FARKLI. */
        uint32_t ccr = (uint32_t)(d * (float)(BTS7960_PWM_ARR + 1U));
        if (m->bts_dir == MOTOR_CW) {
            __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel,  ccr);   /* RPWM */
            __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel2, 0);     /* LPWM */
        } else if (m->bts_dir == MOTOR_CCW) {
            __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel,  0);
            __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel2, ccr);
        } else {
            __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel,  0);
            __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel2, 0);
        }
        return;
    }
    /* TB6612 — TIM3, 20 kHz */
    __HAL_TIM_SET_COMPARE(&htim3, m->pwm_channel, (uint32_t)(d * (float)(MOTOR_PWM_PERIOD + 1U)));
}

static inline float _clamp_duty(float d)
{
    if (d < 0.0f)             return 0.0f;
    if (d > MOTOR_MAX_DUTY)   return MOTOR_MAX_DUTY;
    return d;
}

void MotorCh_Init(MotorCh_t *m)
{
    __HAL_RCC_GPIOB_CLK_ENABLE();

    TIM_OC_InitTypeDef sConfigOC = {0};
    sConfigOC.OCMode     = TIM_OCMODE_PWM1;
    sConfigOC.Pulse      = 0;
    sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
    sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;

    if (m->is_bts7960) {
        /* ── BTS7960/HW-039 (motor-1 HP): RPWM(PB8)+LPWM(PB9) TIM4 AF2, EN(PB14) GPIO ── */
        __HAL_RCC_TIM4_CLK_ENABLE();
        /* EN (R_EN+L_EN köprü) — GPIO output, LOW = sürücü KAPALI (güvenli başlangıç) */
        GPIO_InitTypeDef gpio_en = {0};
        gpio_en.Pin = m->stby_pin; gpio_en.Mode = GPIO_MODE_OUTPUT_PP;
        gpio_en.Pull = GPIO_NOPULL; gpio_en.Speed = GPIO_SPEED_FREQ_LOW;
        HAL_GPIO_Init(GPIOB, &gpio_en);
        HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_RESET);
        /* RPWM + LPWM — TIM4 AF2 */
        GPIO_InitTypeDef gpio_pwm = {0};
        gpio_pwm.Pin = m->pwm_pin | m->pwm_pin2;
        gpio_pwm.Mode = GPIO_MODE_AF_PP; gpio_pwm.Pull = GPIO_NOPULL;
        gpio_pwm.Speed = GPIO_SPEED_FREQ_HIGH; gpio_pwm.Alternate = GPIO_AF2_TIM4;
        HAL_GPIO_Init(GPIOB, &gpio_pwm);
        if (!tim4_base_ready) {
            htim4.Instance               = TIM4;
            htim4.Init.Prescaler         = BTS7960_PWM_PRESC;  /* 20 kHz (datasheet ≤25 kHz; 1 kHz whine'dı) */
            htim4.Init.Period            = BTS7960_PWM_ARR;
            htim4.Init.CounterMode       = TIM_COUNTERMODE_UP;
            htim4.Init.ClockDivision     = TIM_CLOCKDIVISION_DIV1;
            htim4.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
            HAL_TIM_PWM_Init(&htim4);
            tim4_base_ready = true;
        }
        HAL_TIM_PWM_ConfigChannel(&htim4, &sConfigOC, m->pwm_channel);
        HAL_TIM_PWM_ConfigChannel(&htim4, &sConfigOC, m->pwm_channel2);
        HAL_TIM_PWM_Start(&htim4, m->pwm_channel);
        HAL_TIM_PWM_Start(&htim4, m->pwm_channel2);
        m->bts_dir = MOTOR_STOP;
    } else {
        /* ── TB6612 (motor-2): AIN1/AIN2/STBY GPIO + PWM TIM3 AF2 ──
         * TB6612 input pinlerinde dahili 200 kΩ pull-down (datasheet sf 2) → STBY=L'de motor seğirmez. */
        __HAL_RCC_TIM3_CLK_ENABLE();
        GPIO_InitTypeDef gpio_out = {0};
        gpio_out.Pin   = m->ain1_pin | m->ain2_pin | m->stby_pin;
        gpio_out.Mode  = GPIO_MODE_OUTPUT_PP;
        gpio_out.Pull  = GPIO_NOPULL;
        gpio_out.Speed = GPIO_SPEED_FREQ_LOW;
        HAL_GPIO_Init(GPIOB, &gpio_out);
        HAL_GPIO_WritePin(GPIOB, m->ain1_pin | m->ain2_pin | m->stby_pin, GPIO_PIN_RESET);

        GPIO_InitTypeDef gpio_pwm = {0};
        gpio_pwm.Pin       = m->pwm_pin;
        gpio_pwm.Mode      = GPIO_MODE_AF_PP;
        gpio_pwm.Pull      = GPIO_NOPULL;
        gpio_pwm.Speed     = GPIO_SPEED_FREQ_HIGH;
        gpio_pwm.Alternate = GPIO_AF2_TIM3;
        HAL_GPIO_Init(GPIOB, &gpio_pwm);

        if (!tim3_base_ready) {
            htim3.Instance               = TIM3;
            htim3.Init.Prescaler         = 0;
            htim3.Init.Period            = MOTOR_PWM_PERIOD;
            htim3.Init.CounterMode       = TIM_COUNTERMODE_UP;
            htim3.Init.ClockDivision     = TIM_CLOCKDIVISION_DIV1;
            htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
            HAL_TIM_PWM_Init(&htim3);
            tim3_base_ready = true;
        }
        HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, m->pwm_channel);
        HAL_TIM_PWM_Start(&htim3, m->pwm_channel);
    }

    m->current_duty       = 0.0f;
    m->target_duty        = 0.0f;
    m->last_signed_duty   = 0.0f;
    m->stall_count_ms     = 0;
    m->stall_ref_count    = 0;
    m->stall_active       = false;
    m->lockout_until_ms   = 0;
    m->stall_event_pending = false;
    m->fake_stall_inject  = false;
    m->stall_disabled     = false;   /* algılama AÇIK (emniyet default) */
    m->last_check_tick    = 0;
}

void MotorCh_Enable(MotorCh_t *m)
{
    if (m->stall_active) return;   /* Lockout aktif — STBY=L'de kalır */
    HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_SET);
}

void MotorCh_Disable(MotorCh_t *m)
{
    HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_RESET);
}

void MotorCh_SetDir(MotorCh_t *m, MotorDir_t dir)
{
    if (m->is_bts7960) {
        /* BTS7960: yön = hangi PWM kanalı aktif (donanım dir-pini yok). Geçişte İKİ kanalı
         * da 0'la (shoot-through + eski-yön artığı önleme); _apply_pwm bts_dir'e göre aktif
         * kanalı sürer. CW→RPWM, CCW→LPWM. */
        m->bts_dir = dir;
        __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel,  0);
        __HAL_TIM_SET_COMPARE(&htim4, m->pwm_channel2, 0);
        return;
    }

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
    HAL_GPIO_WritePin(GPIOB, m->ain1_pin, a1);
    HAL_GPIO_WritePin(GPIOB, m->ain2_pin, a2);
}

void MotorCh_SetDuty(MotorCh_t *m, float duty01)
{
    if (m->stall_active) return;   /* Lockout — duty komutu reddedilir */

    /* Hard cap MOTOR_MAX_DUTY (0.50f) — Stall'da pik akım ~0.55-0.8 A,
     * TB6612 sürekli operating limiti 1.0 A'in altında ([TB6612_DS] sf 3).
     *
     * |Δduty| > MOTOR_DEAD_THRESHOLD (0.10) ise sadece target güncellenir,
     * MotorCh_Tick her iterasyonda 0.01 step ile yaklaştırır (non-blocking).
     * Küçük adımlar (PI çıktısı tipik) anında uygulanır. */
    float d = _clamp_duty(duty01);
    m->target_duty = d;

    if (fabsf(d - m->current_duty) <= MOTOR_DEAD_THRESHOLD) {
        /* Küçük adım — direkt uygula, kontrol döngüsü için kritik */
        m->current_duty = d;
        _apply_pwm(m, d);
    }
    /* else: büyük sıçrama — MotorCh_Tick yumuşatır */
}

/* Aşama 2.3 — kapalı döngü için doğrudan PWM yazma.
 * SetDuty + Tick (Aşama 0 soft-start rampası) AÇIK DÖNGÜ içindi;
 * hız PI ile kullanılınca rampa + dead-band clamp kontrol sinyalini bozuyordu
 * (PI ±0.5 zıplayınca |Δ|>0.10 → rampa devreye → kontrolcü ile çakışma).
 * Bu fonksiyon: signed duty → yön + |duty|, RAMPA YOK, dead-band YOK.
 * Lockout + saturation (±MOTOR_MAX_DUTY) korunur. current/target senkron
 * tutulur (stall check current_duty kullanıyor). */
void MotorCh_SetDutySigned(MotorCh_t *m, float duty)
{
    if (m->stall_active) return;   /* lockout — reddet */

    /* Signed saturation ±MOTOR_MAX_DUTY */
    float d = duty;
    if (d >  MOTOR_MAX_DUTY) d =  MOTOR_MAX_DUTY;
    if (d < -MOTOR_MAX_DUTY) d = -MOTOR_MAX_DUTY;

    float mag = (d >= 0.0f) ? d : -d;
    MotorCh_SetDir(m, (d >= 0.0f) ? MOTOR_CW : MOTOR_CCW);
    m->current_duty     = mag;   /* rampa state senkron — stall check tutarlı */
    m->target_duty      = mag;
    m->last_signed_duty = d;
    _apply_pwm(m, mag);
}

void MotorCh_Tick(MotorCh_t *m)
{
    /* Main loop'tan her iterasyonda (~140 Hz, döngü ~7 ms) çağrılır.
     * current_duty → target_duty arasında 0.01 step ile yaklaşır.
     * ~30 step × ~7 ms ≈ 210 ms (büyük sıçrama için tipik rampa süresi). */
    if (m->current_duty == m->target_duty) return;

    if (m->current_duty < m->target_duty) {
        m->current_duty += MOTOR_RAMP_STEP;
        if (m->current_duty > m->target_duty) m->current_duty = m->target_duty;
    } else {
        m->current_duty -= MOTOR_RAMP_STEP;
        if (m->current_duty < m->target_duty) m->current_duty = m->target_duty;
    }
    _apply_pwm(m, m->current_duty);
}

void MotorCh_SoftStart(MotorCh_t *m, float target01)
{
    /* Bloklayan rampa — init/start-up için. 0'dan target'a ~200 ms.
     * Kontrol döngüsü öncesi tek seferlik kullanım; main loop bloklanır.
     * Runtime için MotorCh_SetDuty + MotorCh_Tick kullan (non-blocking). */
    float t = _clamp_duty(target01);
    m->target_duty  = t;
    m->current_duty = 0.0f;
    _apply_pwm(m, 0.0f);

    while (m->current_duty < t - 0.005f) {
        m->current_duty += MOTOR_RAMP_STEP;
        if (m->current_duty > t) m->current_duty = t;
        _apply_pwm(m, m->current_duty);
        HAL_Delay(MOTOR_SOFT_STEP_MS);
    }
    m->current_duty = t;
    _apply_pwm(m, t);
}

void MotorCh_Stop(MotorCh_t *m)
{
    /* Yumuşak durdurma — PWM target'ı 0, dir STOP. Motor sürtünme/atalete bırakılır. */
    MotorCh_SetDir(m, MOTOR_STOP);
    m->target_duty      = 0.0f;
    m->current_duty     = 0.0f;   /* anında — ramping istemiyoruz, motor zaten dur isteği */
    m->last_signed_duty = 0.0f;
    _apply_pwm(m, 0.0f);
}

void MotorCh_EmergencyStop(MotorCh_t *m)
{
    /* Kesici durdurma — STBY=L (en hızlı, donanım kesim) + duty=0 + AIN=0.
     * Stall detection ve manuel kill için. */
    HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_RESET);  /* STBY=L önce */
    m->target_duty      = 0.0f;
    m->current_duty     = 0.0f;
    m->last_signed_duty = 0.0f;
    _apply_pwm(m, 0.0f);
    HAL_GPIO_WritePin(GPIOB, m->ain1_pin | m->ain2_pin, GPIO_PIN_RESET);  /* AIN=0 */
}

/* ── Stall detection + lockout ─────────────────────────────────────────── */

void MotorCh_StallCheck(MotorCh_t *m, int32_t enc_count)
{
    uint32_t now = HAL_GetTick();

    /* Runtime KAPALI (STALLEN:0) — yük altında stick-slip yanlış-pozitif verir.
     * Pencereyi sıfırla, varsa lockout'u temizle (STBY=H), tetikleme. Duty-cap %50
     * birincil akım koruması olarak AKTİF kalır (motor.h stall_disabled notu). */
    if (m->stall_disabled) {
        if (m->stall_active) {
            m->stall_active     = false;
            m->lockout_until_ms = 0;
            HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_SET);
        }
        m->stall_count_ms  = 0;
        m->stall_ref_count = enc_count;
        m->last_check_tick = now;
        return;
    }

    /* Lockout otomatik açılma — süre dolunca sürücüyü tekrar aktive et */
    if (m->stall_active && now >= m->lockout_until_ms) {
        m->stall_active     = false;
        m->lockout_until_ms = 0;
        HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_SET);  /* STBY=H */
    }

    if (m->stall_active) {
        /* Lockout süresince kontrol yapma */
        m->last_check_tick = now;
        m->stall_count_ms  = 0;
        m->stall_ref_count = enc_count;
        return;
    }

    /* Rampa sırasında bypass (current ≠ target) — yanlış pozitif önleme */
    if (fabsf(m->current_duty - m->target_duty) > 0.005f) {
        m->stall_count_ms  = 0;
        m->stall_ref_count = enc_count;
        m->last_check_tick = now;
        return;
    }

    /* Tick periyodu — main loop ~5-10 ms, ilk çağrı veya overflow için clamp */
    uint32_t dt = (m->last_check_tick == 0U) ? 5U : (now - m->last_check_tick);
    m->last_check_tick = now;
    if (dt > 100U) dt = 5U;

    /* Duty eşiği altında pencereyi sıfırla — düşük güçte stall anlamsız */
    if (m->current_duty <= STALL_DUTY_TH) {
        m->stall_count_ms  = 0;
        m->stall_ref_count = enc_count;
        return;
    }

    /* Count deltası — fake_stall debug injection deltayı 0 zorlar (kilitli
     * rotor simülasyonu). int32 fark wrap-safe; pencere içi delta küçük. */
    int32_t delta = enc_count - m->stall_ref_count;
    if (m->fake_stall_inject) delta = 0;

    if (delta >= STALL_COUNT_TH || delta <= -STALL_COUNT_TH) {
        /* Mil dönüyor — pencereyi yeni referansla baştan başlat */
        m->stall_count_ms  = 0;
        m->stall_ref_count = enc_count;
        return;
    }

    /* |Δcount| < eşik VE duty yüksek → "dönmüyor" sayacı işlesin */
    m->stall_count_ms += dt;
    if (m->stall_count_ms >= STALL_DURATION_MS) {
        /* STALL TETİK — kesici durdurma + 1 sn lockout (oto-toparlanma) */
        m->stall_event_pending = true;
        m->stall_count_ms      = 0;
        m->stall_ref_count     = enc_count;
        m->lockout_until_ms    = now + LOCKOUT_DURATION_MS;
        MotorCh_EmergencyStop(m);
        m->stall_active        = true;  /* EmergencyStop sonrası set — sıra önemli */
    }
}

bool MotorCh_IsStalled(const MotorCh_t *m)
{
    return m->stall_active;
}

bool MotorCh_PollStallEvent(MotorCh_t *m)
{
    bool e = m->stall_event_pending;
    m->stall_event_pending = false;
    return e;
}

void MotorCh_ResetLockout(MotorCh_t *m)
{
    /* Erken kapatma — RESET komutu için. */
    m->stall_active     = false;
    m->lockout_until_ms = 0;
    m->stall_count_ms   = 0;
    HAL_GPIO_WritePin(GPIOB, m->stby_pin, GPIO_PIN_SET);  /* STBY=H */
}

float MotorCh_GetDutySigned(const MotorCh_t *m)
{
    return m->last_signed_duty;
}

void MotorCh_InjectFakeStall(MotorCh_t *m, bool on)
{
    m->fake_stall_inject = on;
}

void MotorCh_SetStallDetect(MotorCh_t *m, bool enabled)
{
    m->stall_disabled = !enabled;
    if (!enabled) MotorCh_ResetLockout(m);   /* kapatınca mevcut lockout'u da temizle */
}
