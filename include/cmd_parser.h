#ifndef CMD_PARSER_H
#define CMD_PARSER_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * USB CDC komut parser — eksen-yönlendirmeli (Aşama 3.3)
 *
 * Line-buffered. '\n' görünce parse eder.
 *
 * Komut seti — temel ad → EKSEN-0 (motor-1, geriye uyumlu);
 *              '2' sonekli → EKSEN-1 (motor-2):
 *
 *   MODE:DUTY|SP_W|POS|MIRROR\n    MODE2:...\n     → eksen modu
 *   DUTY:<signed>\n                                → eksen-0, DUTY modda, RAMPALI
 *                                                    (işaret yön belirler; Aşama-0/1
 *                                                    scriptlerinin dayandığı semantik)
 *   DUTY2:<signed>\n                               → eksen-1, DUTY modda, RAMPASIZ
 *                                                    (3.2b motor2_sign_test semantiği)
 *   SP_W:<signed>\n                SP_W2:...\n     → hız setpoint (rad/s)
 *   POS_DEG:<signed>\n             POS_DEG2:...\n  → hedef çıkış mili açısı (derece)
 *   KPP:<float>\n                  KPP2:...\n      → pozisyon P kazancı (runtime)
 *   KP:<float>\n KI:<float>\n      KP2:/KI2:...\n  → hız PI kazançları (runtime)
 *   SLEW:<float>\n                 SLEW2:...\n     → hız setpoint slew (rad/s/s, 0=kapalı)
 *
 *   STOP\n     → HER İKİ eksen durdur (mod kuralları eksen-başına uygulanır)
 *   RESET\n    → HER İKİ eksen lockout temizle + PI reset
 *   PING\n     → 'PONG\r\n' yanıt (handshake)
 *   IMUDIAG\n / IMUINIT\n → IMU teşhis/uyandırma (main.c)
 *
 * Mod durumu eksen-bazlıdır ve Axis_t.mode'da yaşar (axis.h, g_axis[i].mode).
 *
 * Watchdog: her geçerli komut last_cmd_tick'i günceller (main loop watchdog'u
 * 1 sn boyunca komut yoksa tüm eksenleri durdurur).
 * ============================================================================ */

typedef enum {
    CMD_MODE_DUTY   = 0,  /* varsayılan — geriye uyumlu */
    CMD_MODE_SP_W   = 1,  /* hız PI iç döngü */
    CMD_MODE_POS    = 2,  /* pozisyon cascade (poz P dış → hız PI iç) — Aşama 2.5 */
    CMD_MODE_MIRROR = 3,  /* IMU mirror — setpoint = +göreli fused_pitch (takip/taklit) — Aşama 2.7 */
    CMD_MODE_STAB   = 4   /* IMU stabilizasyon — setpoint = −göreli fused_pitch (base'i karşıla,
                           * payload sabit) — Aşama 3.3 demo / Aşama 5 tam doğrulama */
} CmdMode_t;

void      CmdParser_Feed(const uint8_t *buf, uint16_t len);  /* USB RX callback'ten */
uint32_t  CmdParser_LastCmdTick(void);                        /* watchdog için */

#endif /* CMD_PARSER_H */
