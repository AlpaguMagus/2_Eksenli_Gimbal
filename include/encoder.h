#ifndef ENCODER_H
#define ENCODER_H

#include <stdint.h>

/* ============================================================================
 * TIM2 Quadrature Encoder Interface
 *
 * Donanım:
 *   PA15 → TIM2_CH1 (Encoder A, sarı kablo)   — SWD modunda JTDI free
 *   PB3  → TIM2_CH2 (Encoder B, beyaz kablo)  — SWD modunda JTDO free
 *   GPIO_PULLUP aktif — Pololu enkoder open-collector olabilir, emniyet için
 *
 * Sayım:
 *   TIM2 = 32-bit auto-reload counter (STM32F411 datasheet sf 28).
 *   Pololu konvansiyonu: "48 CPR" zaten quadrature-decoded sayım (her iki
 *     kanalın her iki kenarı). Kaynak: robotsepeti.com 25D LP sayfası,
 *     "Kuadratür enkoder her iki kanalda kenarlar için sayım yapması
 *     durumunda 48 CPR'lık bir çözünürlük sağlar."
 *   → 1 motor şaftı devri = 48 olay (TIM_ENCODERMODE_TI12 ile)
 *   → 1 çıkış mili devri  = 48 × 9.7 ≈ 466 olay
 *   → çıkış mili çözünürlüğü = 360° / 466 ≈ 0.77° / count
 *   Taşma sınırı: ~9.2M çıkış devri (32-bit, pratikte sınırsız).
 *
 * Encoder beslemesi: BlackPill 5V (datasheet min 3.5V).
 *   Sinyaller 5V seviyede gelir, PA15/PB3 FT (5V tolerant) — direkt bağlanır.
 * ============================================================================ */

void    Encoder_Init(void);
int32_t Encoder_GetCount(void);          /* TIM2->CNT, signed 32-bit */
void    Encoder_Reset(void);             /* sayacı sıfırla */
float   Encoder_GetSpeed(float dt_sec);  /* MOTOR ŞAFTI rad/s. Çıkış mili için 9.7'ye böl. */

#endif /* ENCODER_H */
