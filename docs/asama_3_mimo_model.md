# Aşama 3 — İki Motor MIMO Modelleme

> **Durum:** 🟡 AKTİF (2026-06-07 açıldı, `feature/asama-3-mimo-model`).
> Bu belge ders-kitabı disipliniyle (Ne/Neden/Nasıl/Nerede/Sonuç — global CLAUDE.md)
> aşama ilerledikçe doldurulur. Ortak teori kavramları → [`00_genel_bakis.md`](00_genel_bakis.md).

## 12. Aşama 3 — İki Motor MIMO

### 12.1. Ne / Neden (vizyon)

İkinci motor + encoder eklenir; **çapraz kuplaj** (motor 1 sürülürken motor 2 ekseninde
etki) karakterize edilir: 2×2 transfer matrisi $G(s)$, RGA analizi (`[Skogestad2005] §10`),
condition number → decoupling potansiyeli. Aşama 4 (MIMO kontrol/LQG) bu modelin üzerine kurulur.

### 12.2. Donanım genişlemesi (3.1 — pin planı)

*(Pin atama önerisi onaylanınca buraya tablo + gerekçelerle işlenecek; güç & koruma planı
ROADMAP "Aşama 3 güç & koruma planı"nda: tek 3A adaptör yeterli, 2 ayrı TB6612,
dar boğaz = sürücü, ACS712 eksen-başı rezervi.)*

### 12.3. Sistem tanımlama planı (3.3–3.4)

*(SISO↔MIMO veri toplama: her motoru ayrı sür, diğer ekseni ölç; eleman-bazlı `tfest`.)*

### 12.4. Açık konular

- Pin planı onayı (3.1)
- 2. encoder 16-bit timer sayaç genişletme (TIM1 seçilirse — yazılım extended count)
- ACS712 Faz-2 entegrasyonu (duty %100 gevşetme ön koşulu)
