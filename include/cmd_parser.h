#ifndef CMD_PARSER_H
#define CMD_PARSER_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * USB CDC komut parser
 *
 * Line-buffered. '\n' görünce parse eder.
 *
 * Komut seti (Aşama 2.2 sonrası):
 *
 *   MODE:DUTY\n              → açık döngü modu (varsayılan)
 *   MODE:SP_W\n              → hız PI iç döngü modu
 *   MODE:POS\n               → pozisyon cascade modu (Aşama 2.5: poz P → hız PI)
 *   MODE:MIRROR\n            → IMU mirror (Aşama 2.7): motor fused_pitch'i takip eder
 *
 *   DUTY:<signed_float>\n    → DUTY modda: işaret yön belirler (+CW, -CCW)
 *   SP_W:<signed_float>\n    → SP_W modda: hız setpoint (rad/s, signed)
 *   POS_DEG:<signed_float>\n → POS modda: hedef çıkış mili açısı (derece, signed)
 *   KPP:<float>\n            → POS modda: pozisyon P kazancı (runtime, flash'sız)
 *
 *   STOP\n                   → Motor_Stop()  (her modda geçerli)
 *   RESET\n                  → Motor_ResetLockout() + SpeedPI_Reset()
 *   PING\n                   → 'PONG\r\n' yanıt (handshake)
 *
 * Sokratik karar (Aşama 2.2.C, kullanıcı: A — Açık mod komutu):
 *   MODE komutu ile mod değişir. DUTY ve SP_W komutları sadece ilgili modda
 *   motor sürüşünü etkiler. Yanlış modda gelen DUTY/SP_W setpoint'i set eder
 *   ama uygulanmaz — main loop'taki mode anahtarı buna bakar.
 *
 * Watchdog: her geçerli komut last_cmd_tick'i günceller (main loop watchdog'u
 * 1 sn boyunca komut yoksa Motor_Stop çağırır).
 * ============================================================================ */

typedef enum {
    CMD_MODE_DUTY   = 0,  /* varsayılan — geriye uyumlu */
    CMD_MODE_SP_W   = 1,  /* hız PI iç döngü */
    CMD_MODE_POS    = 2,  /* pozisyon cascade (poz P dış → hız PI iç) — Aşama 2.5 */
    CMD_MODE_MIRROR = 3   /* IMU mirror — setpoint = göreli fused_pitch (cascade) — Aşama 2.7 */
} CmdMode_t;

void      CmdParser_Feed(const uint8_t *buf, uint16_t len);  /* USB RX callback'ten */
uint32_t  CmdParser_LastCmdTick(void);                        /* watchdog için */
CmdMode_t CmdParser_GetMode(void);                            /* main loop mode anahtarı */

#endif /* CMD_PARSER_H */
