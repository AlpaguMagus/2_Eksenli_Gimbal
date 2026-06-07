# 00 — Aşamalar-Arası Ortak Teori (görseller)

> **Amaç:** [`docs/00_genel_bakis.md`](../../docs/00_genel_bakis.md) "Ortak Kontrol
> Teorisi Primer'i"nin **generic kavram görselleri** — aşamaya özel değil, üniversite
> 1. sınıf seviyesi kontrol teorisi figürleri (transfer fn, kapalı-çevrim, 1./2. derece
> yanıt, Bode). Aşama belgeleri bu kavramları tekrar etmez, primer'e atıf verir.

---

## Scriptler

| Script | Amaç | Çıktı |
|---|---|---|
| `create_theory_diagrams.m` | Primer için 5 generic figür (programatik, beyaz-tema zorlamalı) | `results/*.png` |

## Çıktılar (`results/`, git'te)

| PNG | Kavram |
|---|---|
| `00_openloop_single.png` | Açık-çevrim tek blok (kontrolcüsüz sistem) |
| `01_closed_loop_general.png` | Genel kapalı-çevrim ($\Sigma$, $C(s)$, $G(s)$, geri besleme) |
| `02_first_order_step.png` | 1. derece step yanıtı ($\tau$ zaman sabiti) |
| `03_second_order_zeta.png` | 2. derece — $\zeta$ sönüm oranı etkisi |
| `04_bode_concept.png` | Bode kavramı (kazanç/faz, PM/GM) |

> 📊 Bu 5 görsel `docs/00_genel_bakis.md`'de üreten-betik notuyla embed edilir.
> Beyaz-tema zorlaması: script başında `set(groot,'defaultAxesColor','w',...)` —
> session dark-tema olsa bile figürler ders-kitabı beyaz zeminli üretilir.
