# Pololu HP 12V 25D Motor (48 CPR Enkoderli) — PL-4840

> **Kaynak:** robotsepeti.com/pololu-hp-12v-motor-48-cpr-enkoderli-25d-reduktorlerle-uyumlu-pl-4840
> (Pololu ürün no **PL-4840**); WebFetch 2026-06-13. Boyut diyagramı: bu klasördeki
> `25d-metal-gearmotor-dimension-diagram.pdf` (25D gövde — LP ile AYNI fiziksel boyut).

| Özellik | Değer |
|---|---|
| Motor tipi | **HP (High Power)** |
| Nominal voltaj | 12 V |
| Boşta dönüş hızı (motor şaftı, redüktörsüz) | **10200 RPM** |
| Boşta akım | **150 mA** |
| **Stall (kilitli rotor) akımı** | **5600 mA (5.6 A) @ 12V** |
| Stall tork (redüktörsüz motor) | 0.396 kg·cm (5.5 oz·in) |
| Enkoder | **48 CPR** kuadratür Hall (motor şaftı; LP ile AYNI) |
| Türetilen K (motor şaftı) | ≈ **89 rad/s/V** (10200 RPM = 1068 rad/s ÷ 12 V) |
| Gearbox | Standart 25D redüktörlere uyumlu (redüktörsüz gelir) |

## ⚠ LP vs HP — KRİTİK FARK (bu projeye etkisi)

Projenin orijinal/karakterize motoru **LP 12V** (`datasheets/Pololu 9.7_1 ... LP 12V`).
HP ≠ LP — farklı sargı, farklı akım/hız:

| | LP 12V (orijinal, K=53.89 ölçülen) | **HP 12V (PL-4840)** | Oran |
|---|---|---|---|
| Boşta hız (motor şaftı) | ~5800 RPM (K≈50) | 10200 RPM (K≈89) | ~1.75× |
| Boşta akım | ~70 mA | 150 mA | ~2× |
| **Stall akımı @12V** | **1.1 A** | **5.6 A** | **~5×** |
| Stall tork | ~0.2 kg·cm | 0.396 kg·cm | ~2× |

**Sonuç:**
- HP stall (5.6 A) **TB6612FNG'nin 3.2 A pikini AŞAR** → HP doğrudan TB6612'ye **bağlanamaz** (sürücü yanar). HW-039/BTS7960 gibi yüksek-akım sürücü gerekir.
- Enkoder **48 CPR** (LP ile aynı) → `encoder.h` / `k_ff` (gear=9.7) **değişmez**; yalnız K/τ yeniden karakterize edilir.
- Ölçülen K=53.89 (LP) HP'de geçerli DEĞİL (HP K≈89). Aşama-1 karakterizasyonu HP eksen için tekrarlanır.
