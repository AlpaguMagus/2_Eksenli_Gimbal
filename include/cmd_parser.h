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
 * Her geçerli komut last_cmd_tick'i günceller (watchdog için, 2B.2'de aktif).
 * İlk DUTY veya STOP geldiğinde sequence_armed=false — Aşama 2A geçici
 * test sequence'i bu flag ile durur. PING/RESET sequence'i etkilemez.
 * ============================================================================ */

void     CmdParser_Feed(const uint8_t *buf, uint16_t len);  /* USB RX callback'ten */
uint32_t CmdParser_LastCmdTick(void);                        /* watchdog için */
bool     CmdParser_SequenceArmed(void);                      /* test sequence flag */

#endif /* CMD_PARSER_H */
