#include "cmd_parser.h"
#include "motor.h"
#include "speed_pi.h"
#include "usbd_cdc_if.h"
#include "stm32f4xx_hal.h"
#include <string.h>
#include <stdlib.h>

#define CMD_BUF_SIZE  64U

static char     line_buf[CMD_BUF_SIZE];
static uint16_t line_len = 0;

static uint32_t  last_cmd_tick_ms = 0;
static CmdMode_t current_mode     = CMD_MODE_DUTY;   /* varsayılan, geriye uyumlu */

static const char PONG[] = "PONG\r\n";

static void parse_line(const char *line)
{
    /* ── MODE komutları ─────────────────────────────────────────── */
    if (strcmp(line, "MODE:DUTY") == 0) {
        /* SP_W → DUTY geçiş: motoru durdur, PI'yi resetle (windup birikmesin) */
        if (current_mode != CMD_MODE_DUTY) {
            Motor_Stop();
            SpeedPI_Reset();
        }
        current_mode = CMD_MODE_DUTY;
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "MODE:SP_W") == 0) {
        if (current_mode != CMD_MODE_SP_W) {
            /* DUTY → SP_W geçiş: motoru durdur, PI'yi sıfırla (eski state varsa) */
            Motor_Stop();
            SpeedPI_Reset();
        }
        current_mode = CMD_MODE_SP_W;
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── DUTY komutu — sadece DUTY modda motor sürer ────────────── */
    if (strncmp(line, "DUTY:", 5) == 0) {
        float d = strtof(line + 5, NULL);
        if (current_mode == CMD_MODE_DUTY) {
            if (d < 0.0f) {
                Motor_SetDir(MOTOR_CCW);
                Motor_SetDuty(-d);
            } else {
                Motor_SetDir(MOTOR_CW);
                Motor_SetDuty(d);
            }
        }
        /* DUTY komutu yanlış modda gelirse sessizce ignore — log yok, parser temiz */
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── SP_W komutu — sadece SP_W modda etkili ──────────────────── */
    if (strncmp(line, "SP_W:", 5) == 0) {
        float r = strtof(line + 5, NULL);
        /* Setpoint set edilir (PI bu değeri kullanır); main loop SP_W modda
         * SpeedPI_Step çağırır ve Motor_SetDir/Duty'yi yönetir. */
        SpeedPI_SetSetpoint(r);
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }

    /* ── Mod-bağımsız komutlar ──────────────────────────────────── */
    if (strcmp(line, "STOP") == 0) {
        Motor_Stop();
        SpeedPI_Reset();
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "RESET") == 0) {
        Motor_ResetLockout();
        SpeedPI_Reset();
        last_cmd_tick_ms = HAL_GetTick();
        return;
    }
    if (strcmp(line, "PING") == 0) {
        CDC_Transmit_FS((uint8_t *)PONG, (uint16_t)(sizeof(PONG) - 1U));
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
CmdMode_t CmdParser_GetMode(void)    { return current_mode; }
