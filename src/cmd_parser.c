#include "cmd_parser.h"
#include "axis.h"
#include "usbd_cdc_if.h"
#include "stm32f4xx_hal.h"
#include <string.h>
#include <stdlib.h>

/* main.c MPU6050 yardımcıları — IMUDIAG/IMUINIT teşhis komutları (2026-05-31) */
extern void MPU6050_Init(void);
extern void MPU6050_DiagPrint(void);

#define CMD_BUF_SIZE  64U

static char     line_buf[CMD_BUF_SIZE];
static uint16_t line_len = 0;

static uint32_t  last_cmd_tick_ms = 0;

static const char PONG[] = "PONG\r\n";

/* ── Eksen-bazlı komut işleyicileri ───────────────────────────────────────
 * Davranış Aşama-2 tek-eksen koduyla birebir; yalnız hedef eksen parametrik. */

static void cmd_set_mode(Axis_t *ax, CmdMode_t new_mode)
{
    if (ax->mode == new_mode) { ax->mode = new_mode; return; }

    switch (new_mode) {
    case CMD_MODE_DUTY:
        /* kapalı-döngü → DUTY geçiş: motoru durdur, PI'yi resetle (windup birikmesin) */
        MotorCh_Stop(ax->motor);
        SpeedPI_Reset(&ax->spi);
        SpeedFilter_Reset(&ax->filt);
        break;
    case CMD_MODE_SP_W:
        MotorCh_Stop(ax->motor);
        SpeedPI_Reset(&ax->spi);
        SpeedFilter_Reset(&ax->filt);
        break;
    case CMD_MODE_POS:
        /* → POS cascade geçiş: motoru durdur, iç PI + filtre + dış P sıfırla.
         * enc_reset: mevcut konum 0° referans olur (göreceli pozisyon).
         * Slew=0: dış P zaten yumuşak ω_ref üretir, iç döngü slew'i ekstra
         *   faz kaybı katıp cascade'i bozar (sim'de slew yoktu). */
        MotorCh_Stop(ax->motor);
        SpeedPI_Reset(&ax->spi);
        SpeedFilter_Reset(&ax->filt);
        PositionP_Reset(&ax->ppos);
        ax->enc_reset();
        SpeedPI_SetSlewRate(&ax->spi, 0.0f);
        PositionP_SetGain(&ax->ppos, 2.0f);   /* step: konservatif/overshootsuz (Aşama 2.5) */
        break;
    case CMD_MODE_MIRROR:
    case CMD_MODE_STAB:
        /* → MIRROR/STAB (Aşama 2.7 / 3.3): POS cascade ile aynı reset; ek olarak main
         * loop geçiş edge'inde pitch0 (göreli referans) kaydeder. enc_reset →
         * motor 0° = geçiş anı; θ_ref başlangıçta 0 → ani sıçrama yok.
         * Dış döngü hedefi (θ_ref) main loop'ta fused_pitch'ten slew'li üretilir
         * (MIRROR: +göreli pitch / STAB: −göreli pitch — yalnız işaret farkı). */
        MotorCh_Stop(ax->motor);
        SpeedPI_Reset(&ax->spi);
        SpeedFilter_Reset(&ax->filt);
        PositionP_Reset(&ax->ppos);
        ax->enc_reset();
        SpeedPI_SetSlewRate(&ax->spi, 0.0f);
        PositionP_SetGain(&ax->ppos, 6.0f);   /* takip kazancı — ANALİTİK ([Franklin2010] §4.2,
                                               * design_mirror_tracking.m): tip-1 sistem, Kv=Kp_pos.
                                               * Ramp e_ss=ω_in/Kv; ω_in=30°/s, hedef<5° → Kp_pos≥6.
                                               * Sinüs (30°,0.2Hz) RMS 4.63°<5° doğrular. Cascade ayrımı
                                               * 33/6≈5.5×>5× [§6.4]. Test 2.T6 deneysel 4.02°/4.68°. */
        break;
    default:
        break;
    }
    ax->mode = new_mode;
}

static void cmd_stop_axis(Axis_t *ax)
{
    MotorCh_Stop(ax->motor);
    SpeedPI_Reset(&ax->spi);
    SpeedFilter_Reset(&ax->filt);
    /* POS modda main loop PositionP'den setpoint alır → hedefi mevcut konuma
     * çek (e=0 → ω_ref=0) ki STOP sonrası motor eski hedefe gitmesin (pozisyon tut). */
    if (ax->mode == CMD_MODE_POS)
        PositionP_SetSetpoint(&ax->ppos, PositionP_GetThetaOut(&ax->ppos));
    /* MIRROR/STAB sürekli takip modu: STOP = takipten çık (yoksa main loop fused_pitch'ten
     * setpoint üretip Stop'u ezer). DUTY'ye dön → motor güvenli durur. */
    if (ax->mode == CMD_MODE_MIRROR || ax->mode == CMD_MODE_STAB) ax->mode = CMD_MODE_DUTY;
}

static void cmd_reset_axis(Axis_t *ax)
{
    /* Önce GÜVENLİ DURUM: motor durur (PWM=0, dir=STOP) — eski 3.2b RESET'i
     * motor-2'yi Motor2_Stop ile durduruyordu; davranış-denetimi (2026-06-11)
     * refactor'da bu çağrının düştüğünü yakaladı → geri eklendi ve her iki
     * eksene genellendi (DUTY modunda dönen motor RESET sonrası dönmeye devam
     * etmesin). Sonra lockout temizlenir (STBY=H). */
    MotorCh_Stop(ax->motor);
    MotorCh_ResetLockout(ax->motor);
    SpeedPI_Reset(&ax->spi);
    SpeedFilter_Reset(&ax->filt);
    if (ax->mode == CMD_MODE_POS)
        PositionP_SetSetpoint(&ax->ppos, PositionP_GetThetaOut(&ax->ppos));
    if (ax->mode == CMD_MODE_MIRROR || ax->mode == CMD_MODE_STAB) ax->mode = CMD_MODE_DUTY;
}

/* "<KÖKAD>[2]:" eşle: dönüş = arg pointer'ı (':'den sonrası), *ax_out hedef eksen.
 * Eşleşmezse NULL. Örn root="MODE" → "MODE:..." eksen-0, "MODE2:..." eksen-1. */
static const char *match_axis_cmd(const char *line, const char *root, Axis_t **ax_out)
{
    size_t n = strlen(root);
    if (strncmp(line, root, n) != 0) return 0;
    if (line[n] == ':') { *ax_out = &g_axis[0]; return line + n + 1; }
    if (line[n] == '2' && line[n + 1] == ':') { *ax_out = &g_axis[1]; return line + n + 2; }
    return 0;
}

static void parse_line(const char *line)
{
    Axis_t *ax;
    const char *arg;

    /* ── MODE / MODE2 ───────────────────────────────────────────── */
    if ((arg = match_axis_cmd(line, "MODE", &ax)) != 0) {
        if      (strcmp(arg, "DUTY")   == 0) cmd_set_mode(ax, CMD_MODE_DUTY);
        else if (strcmp(arg, "SP_W")   == 0) cmd_set_mode(ax, CMD_MODE_SP_W);
        else if (strcmp(arg, "POS")    == 0) cmd_set_mode(ax, CMD_MODE_POS);
        else if (strcmp(arg, "MIRROR") == 0) cmd_set_mode(ax, CMD_MODE_MIRROR);
        else if (strcmp(arg, "STAB")   == 0) cmd_set_mode(ax, CMD_MODE_STAB);
        else return;   /* tanınmayan mod adı → dead-letter: watchdog'u BESLEME
                        * (eski tam-dize strcmp semantiği; davranış-denetimi
                        * 2026-06-11 — geçersiz "MODE:X" akışı watchdog'u
                        * süresiz erteleyip motoru döndürmeye devam ettirirdi) */
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── DUTY / DUTY2 — yalnız ilgili eksen DUTY modundayken sürer ──
     * Eksen-0: RAMPALI yol (SetDir + SetDuty; Aşama-0/1 script semantiği).
     * Eksen-1: RAMPASIZ signed yol (3.2b motor2_sign_test semantiği).
     * Asimetri bilinçli — her iki semantik de bench artifact'lerine dayanak. */
    if ((arg = match_axis_cmd(line, "DUTY", &ax)) != 0) {
        float d = strtof(arg, NULL);
        if (ax->mode == CMD_MODE_DUTY) {
            if (ax == &g_axis[0]) {
                if (d < 0.0f) { MotorCh_SetDir(ax->motor, MOTOR_CCW); MotorCh_SetDuty(ax->motor, -d); }
                else          { MotorCh_SetDir(ax->motor, MOTOR_CW);  MotorCh_SetDuty(ax->motor,  d); }
            } else {
                MotorCh_SetDutySigned(ax->motor, d);
            }
        }
        /* DUTY komutu yanlış modda gelirse sessizce ignore — parser temiz */
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── SP_W / SP_W2 — setpoint set edilir; main loop SP_W modda sürer ── */
    if ((arg = match_axis_cmd(line, "SP_W", &ax)) != 0) {
        SpeedPI_SetSetpoint(&ax->spi, strtof(arg, NULL));
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── POS_DEG / POS_DEG2 — hedef çıkış mili açısı (derece) ── */
    if ((arg = match_axis_cmd(line, "POS_DEG", &ax)) != 0) {
        PositionP_SetSetpoint(&ax->ppos, strtof(arg, NULL));
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── KPP / KPP2 — pozisyon P kazancı runtime ayarı (flash'sız) ── */
    if ((arg = match_axis_cmd(line, "KPP", &ax)) != 0) {
        PositionP_SetGain(&ax->ppos, strtof(arg, NULL));
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── KFF / KFF2 — gyro feedforward kazancı (K2, Aşama 3.8); ≠0 FF'i AÇAR (YALNIZ STAB) ──
     * KFF2:9.7 → k_ff=9.7 + FF açık; KFF2:0 → FF kapalı. Güvenlik: default kapalı. */
    if ((arg = match_axis_cmd(line, "KFF", &ax)) != 0) {
        float v = strtof(arg, NULL);
        ax->k_ff = v;
        ax->gyro_ff_en = (v != 0.0f);
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── KP / KI / SLEW (+2) — hız PI runtime ayarı (Aşama 2.3) ── */
    if ((arg = match_axis_cmd(line, "KP", &ax)) != 0) {
        SpeedPI_SetGains(&ax->spi, strtof(arg, NULL), SpeedPI_GetKi(&ax->spi));  /* Ki korunur */
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if ((arg = match_axis_cmd(line, "KI", &ax)) != 0) {
        SpeedPI_SetGains(&ax->spi, SpeedPI_GetKp(&ax->spi), strtof(arg, NULL));  /* Kp korunur */
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if ((arg = match_axis_cmd(line, "SLEW", &ax)) != 0) {
        SpeedPI_SetSlewRate(&ax->spi, strtof(arg, NULL));  /* rad/s/s, 0=ani step */
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── Mod-bağımsız komutlar (tüm eksenler) ───────────────────── */
    if (strcmp(line, "STOP") == 0) {
        for (int i = 0; i < AXIS_COUNT; i++) cmd_stop_axis(&g_axis[i]);
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "RESET") == 0) {
        for (int i = 0; i < AXIS_COUNT; i++) cmd_reset_axis(&g_axis[i]);
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "PING") == 0) {
        CDC_Transmit_FS((uint8_t *)PONG, (uint16_t)(sizeof(PONG) - 1U));
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "IMUDIAG") == 0) {
        /* I2C/IMU sağlık teşhisi — bus/uyku/AD0 ayrımı (main.c MPU6050_DiagPrint) */
        MPU6050_DiagPrint();
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "IMUINIT") == 0) {
        /* Çipi komutla uyandır (PWR_MGMT_1=0) — güç glitch'i sonrası USB çek-tak
         * gerektirmez (Init normalde yalnız boot'ta koşar). Sonucu hemen raporla. */
        MPU6050_Init();
        MPU6050_DiagPrint();
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    /* Tanınmayan komut → sessizce ignore (dead-letter) */
}

void CmdParser_Feed(const uint8_t *buf, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        char c = (char)buf[i];

        if (c == '\n') {
            if (line_len > 0 && line_buf[line_len - 1] == '\r') {
                line_len--;
            }
            line_buf[line_len] = '\0';
            if (line_len > 0) {
                parse_line(line_buf);
            }
            line_len = 0;
        }
        else if (line_len < CMD_BUF_SIZE - 1) {
            line_buf[line_len++] = c;
        }
        else {
            line_len = 0;   /* overflow → satır atıldı */
        }
    }
}

uint32_t CmdParser_LastCmdTick(void) { return last_cmd_tick_ms; }
