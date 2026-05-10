#include "cmd_parser.h"
#include "motor.h"
#include "usbd_cdc_if.h"
#include "stm32f4xx_hal.h"
#include <string.h>
#include <stdlib.h>

#define CMD_BUF_SIZE  64U

static char     line_buf[CMD_BUF_SIZE];
static uint16_t line_len = 0;

static uint32_t last_cmd_tick_ms = 0;

static const char PONG[] = "PONG\r\n";

static void parse_line(const char *line)
{
    if (strncmp(line, "DUTY:", 5) == 0) {
        float d = strtof(line + 5, NULL);
        if (d < 0.0f) {
            Motor_SetDir(MOTOR_CCW);
            Motor_SetDuty(-d);
        } else {
            Motor_SetDir(MOTOR_CW);
            Motor_SetDuty(d);
        }
        last_cmd_tick_ms = HAL_GetTick();
    }
    else if (strcmp(line, "STOP") == 0) {
        Motor_Stop();
        last_cmd_tick_ms = HAL_GetTick();
    }
    else if (strcmp(line, "RESET") == 0) {
        Motor_ResetLockout();
        last_cmd_tick_ms = HAL_GetTick();
    }
    else if (strcmp(line, "PING") == 0) {
        CDC_Transmit_FS((uint8_t *)PONG, (uint16_t)(sizeof(PONG) - 1U));
        last_cmd_tick_ms = HAL_GetTick();
    }
    /* Tanınmayan komut → sessizce ignore (dead-letter) */
}

void CmdParser_Feed(const uint8_t *buf, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        char c = (char)buf[i];

        if (c == '\n') {
            /* Satır sonu — \r varsa kaldır */
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
            /* Overflow — buffer reset, satır atıldı */
            line_len = 0;
        }
    }
}

uint32_t CmdParser_LastCmdTick(void)
{
    return last_cmd_tick_ms;
}
