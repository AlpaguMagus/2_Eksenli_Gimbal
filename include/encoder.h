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

/* ── Encoder-2 (Aşama 3 MIMO — TIM1 quadrature, PA8/PA9) ───────────────────
 * Motor-2'nin encoder'ı. TIM1 **16-bit** (TIM2 enc-1 32-bit'ti) → donanım sayacı
 * 0..65535 sarar; Encoder2_GetCount yazılımda 32-bit'e genişletir (int16 delta
 * birikimi — her çağrıda |Δ|<32768 varsayımı, ~31 Hz loop'ta fazlasıyla güvenli:
 * 48 CPR'de 32768 count = ~682 motor devri/loop, fiziksel olarak imkânsız).
 * Pinler: PA8=CH1 (🟡 sarı), PA9=CH2 (⚪ beyaz), AF1. 48 CPR (motor şaftı, 4× decoded).
 * Pin planı + şema → docs/asama_3_mimo_model.md §12.2. */
void    Encoder2_Init(void);
int32_t Encoder2_GetCount(void);         /* yazılım-genişletilmiş 32-bit signed */
void    Encoder2_Reset(void);            /* sayacı + birikimi sıfırla */
float   Encoder2_GetSpeed(float dt_sec); /* MOTOR ŞAFTI rad/s (ham) — enc-1 GetSpeed eşdeğeri
                                          * (kendi last-count state'i; GetCount'tan bağımsız) */

/* ── Filtrelenmiş hız ölçümü (Aşama 2.3) ───────────────────────────────────
 * SORUN: Encoder_GetSpeed ham çıktısı çok kuantize — 1 count ≈ 18.7 rad/s
 *   (Δt≈7 ms Aşama 0-2; ÖLÇÜLEN ~32ms → 1 count ~4 rad/s, §12.12.5). Hız PI bu kuantize ölçüme tepki verince
 *   bang-bang salınım (limit cycle) oluşuyor → motor titrer, dönmez.
 * ÇÖZÜM (A+B): N-örnek moving average. Δt ≈ sabit olduğundan
 *   mean(son N ham hız) hem efektif çözünürlüğü N× artırır (B: pencere),
 *   hem yüksek frekans gürültüyü bastırır (A: filtre).
 *   WINDOW=5 → efektif çözünürlük 18.7/5 ≈ 3.74 rad/s, gecikme ~(N-1)/2·Δt ≈ 14 ms.
 * Kontrolcü faz marjına etkisi (ÇALIŞAN döngü Kp=0.002, analitik §11.11.3):
 *   MA-hariç sürekli PM≈60°; MA grup gecikmesi ~14 ms (döngü 32→6ms, GPIO_PULLUP §12.13 → MA gecikmesi 6ms'te ~12ms; 32ms'te ~64ms idi). TAM AYRIK margin
 *   (ZOH + Tustin PI + MA; verify_speed_margin_discrete.m): PM≈40°, ωc≈29 rad/s — kararlı,
 *   spec ≥45°'nin marjinal altında (C1 efektif-Ki düşüklüğü ωc'yi indirip kısmen telafi eder; docs §11.11.8).
 *   [Eski conservative Kp=0.1163 PM=80.8° KULLANILMIYOR — ωc=1259'da MA fazı zaten battırır.]
 * Ham Encoder_GetSpeed korunur (Aşama 1 reproducibility için; stall check
 * 2026-05-31'den beri COUNT-tabanlı — Encoder_GetCount + motor.h gerekçesi).
 *
 * Aşama 3.3: filtre INSTANCE-BASED (SpeedFilter_t) — her eksen kendi penceresini
 * taşır (g_axis[i].filt). Davranış tek-pencereli Aşama-2 koduyla birebir. */
#define ENCODER_SPEED_WINDOW  5

typedef struct {
    float hist[ENCODER_SPEED_WINDOW];
    int   idx;
    int   fill;
} SpeedFilter_t;

float   SpeedFilter_Step(SpeedFilter_t *f, float raw_speed_radps); /* moving average, PI girişi */
void    SpeedFilter_Reset(SpeedFilter_t *f);                       /* pencere temizle (mod geçişi/STOP) */

#endif /* ENCODER_H */
