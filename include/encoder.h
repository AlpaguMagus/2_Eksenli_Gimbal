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
float   Encoder_GetSpeed(float dt_sec);  /* MOTOR ŞAFTI rad/s (ham). Çıkış mili için 9.7'ye böl. */

/* ── Filtrelenmiş hız ölçümü (Aşama 2.3) ───────────────────────────────────
 * SORUN: Encoder_GetSpeed ham çıktısı çok kuantize — 1 count ≈ 18.7 rad/s
 *   (Δt≈7 ms, 48 olay/devir). Hız PI bu kuantize ölçüme tepki verince
 *   bang-bang salınım (limit cycle) oluşuyor → motor titrer, dönmez.
 * ÇÖZÜM (A+B): N-örnek moving average. Δt ≈ sabit olduğundan
 *   mean(son N ham hız) hem efektif çözünürlüğü N× artırır (B: pencere),
 *   hem yüksek frekans gürültüyü bastırır (A: filtre).
 *   WINDOW=5 → efektif çözünürlük 18.7/5 ≈ 3.74 rad/s, gecikme ~(N-1)/2·Δt ≈ 14 ms.
 * Kontrolcü faz marjına etkisi (ÇALIŞAN ampirik döngü Kp=0.002):
 *   MA-hariç PM≈60° (docs §11.12.8); MA grup gecikmesi ~14 ms (döngü ~7 ms) ωc≈34 rad/s'te
 *   ~28° faz kaybı → MA-dahil PM≈33° (kararlı, spec ≥45°'nin marjinal altında, docs §11.12.8).
 *   [Eski conservative Kp=0.1163 PM=80.8° KULLANILMIYOR — ωc=1259'da MA fazı zaten battırır.]
 * Ham Encoder_GetSpeed korunur (Aşama 1 reproducibility + stall check için). */
#define ENCODER_SPEED_WINDOW  5
float   Encoder_FilterSpeed(float raw_speed_radps);  /* moving average, SP_W PI girişi */
void    Encoder_FilterReset(void);                   /* pencere temizle (mod geçişi/STOP) */

#endif /* ENCODER_H */
