# hp_tb6612_diag_20260617_172548 — HP-on-TB6612 + LP encoder teşhis bench

- **Test ID:** hp_tb6612_diag_20260617_172548
- **Tarih:** 2026-06-17 17:25
- **Commit:** 72bcd43
- **Hedef:** HP motorunu TB6612 sürücüsünden sürerek HP encoder (ec) ileri/geri yön sağlığını ve LP encoder (ec2) sayım davranışını teşhis et.
- **Komut:** `python3 scripts/hp_tb6612_diag.py`

## Sonuç (sayısal)

| Metric | Değer | Beklenen | Durum |
|---|---|---|---|
| HP forward ΔEC (HP_fwd, last-first ec) | -1 | büyük (+ veya −) sayım birikimi | ✗ ölü |
| HP reverse ΔEC (HP_rev, last-first ec) | -2408 | belirgin sayım birikimi | ✓ çalışıyor |
| LP ΔEC2 (LP, last-first ec2) | -71040 | makul/küçük | ✗ garabet |
| LP süre Δt | 1.1839 s | — | — |
| LP sayım hızı (ΔEC2/Δt) | -60005 cnt/s | ~0 (motor sürülmüyor) | ✗ garabet (~60000 cnt/s) |

## PASS/FAIL gerekçesi

HP encoder **ileri** yönde ölü: HP_fwd fazı boyunca ec hiç birikmedi (ΔEC ≈ -1, ölçüm gürültüsü mertebesinde) — oysa aynı fazda omega2/ec2 motorun döndüğünü gösteriyor, yani komut gidiyor ama ileri-yön kanalı sayım üretmiyor. HP encoder **geri** yönde sağlıklı: HP_rev fazında ec 510 → -1898 (ΔEC = -2408) düzgün birikti. LP encoder (ec2) ise motor sürülmediği fazda bile ~60000 cnt/s'lik sürekli kayan garabet sayım üretti (ΔEC2 = -71040, Δt = 1.18 s). Bu asimetrik tablo (ileri ölü + geri sağlam, ayrıca LP'de sürekli kayma) bir yazılım/tuning sorunu değil; **besleme/ortak sebep elendikten sonra iki ayrı kablo arızasına** işaret ediyor (HP encoder ileri-yön kanal hattı + LP encoder hattı). Bu nedenle status REVIEW: bulgu donanım müdahalesi (kablo kontrolü) gerektiriyor, otomatik PASS verilmez.

## Sonuç / aksiyon

Besleme (ortak güç/ground) ortak-sebep olarak elendi → kalan açıklama **iki kablo arızası** (HP encoder ileri-yön kanalı ve LP encoder). Teşhis kaydı: `docs/asama_3_mimo_model.md §12.10`.

## Artifacts

- raw/data.csv (gitignored — ham faz/encoder kaydı; sütunlar: phase, t_s, ec, ec2, omega, omega2)
