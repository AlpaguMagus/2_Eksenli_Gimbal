#ifndef CMD_PARSER_H
#define CMD_PARSER_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * USB CDC komut parser
 *
 * Line-buffered. '\n' görünce parse eder. Komut seti:
 *   DUTY:<signed_float>\n   → işaret yön belirler (+CW, -CCW)
 *   STOP\n                   → Motor_Stop()
 *   RESET\n                  → Motor_ResetLockout()
 *   PING\n                   → 'PONG\r\n' yanıt (handshake)
 *
 * Her geçerli komut last_cmd_tick'i günceller — main loop'taki watchdog
 * son komut zamanından 1 sn geçince Motor_Stop() çağırır.
 * ============================================================================ */

void     CmdParser_Feed(const uint8_t *buf, uint16_t len);  /* USB RX callback'ten */
uint32_t CmdParser_LastCmdTick(void);                        /* watchdog için */

#endif /* CMD_PARSER_H */
