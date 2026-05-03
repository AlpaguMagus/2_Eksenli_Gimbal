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
 *   Quadrature 4× decoding → 48 CPR × 4 = 192 olay / motor devri.
 *   9.7:1 redüktör → 1862 olay / çıkış mili devri.
 *   Taşma sınırı: ~2.3M çıkış devri (pratikte sınırsız).
 *
 * Encoder beslemesi: BlackPill 5V (datasheet min 3.5V).
 *   Sinyaller 5V seviyede gelir, PA15/PB3 FT (5V tolerant) — direkt bağlanır.
 * ============================================================================ */

void    Encoder_Init(void);
int32_t Encoder_GetCount(void);          /* signed delta sayım */
void    Encoder_Reset(void);             /* sayacı sıfırla */
float   Encoder_GetSpeed(float dt_sec);  /* olay/saniye → devir/saniye dönüşümü */

#endif /* ENCODER_H */
