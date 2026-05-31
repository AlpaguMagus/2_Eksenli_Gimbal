# Aşama 1 — Tek Motor Sistem Tanımlama

> **Amaç:** Pololu 25D motorun parametrik modelini (K, τ, dead-band) çıkarmak.
> Akademik raporlama için MATLAB tabanlı fit + Simulink doğrulaması.

---

## Hedef Model

**1. dereceden, dead-band gömülü:**

```
ω(t) = K · max(V_eff − V_dead, 0) · (1 − e^(−t/τ))

V_eff    = V_supply · duty − V_sat
V_supply = 12.15 V    (Mervesan ölçüm ortalaması, droop %0.6)
V_sat    = 0.5 V      (TB6612 datasheet @1A)
```

Parametreler: **K** (rad/s/V), **τ** (s), **V_dead** (V).

**Kaynak:** `[Ljung1999] §3` (parametrik model yapıları), `[Franklin2010] §3` (1. derece motor modeli), `[TB6612_DS] §1` (Vsat).

## Scriptler (planlı)

| Script | Amaç | Girdi | Çıktı |
|---|---|---|---|
| `load_step_data.m` | artifacts CSV'lerini `iddata` formatına çevir | `artifacts/1/step_response/raw/*.csv.gz` | `data` (iddata) |
| `fit_first_order.m` | Her step için `tfest`/`curve_fit` | `data` | step bazlı (K_i, τ_i) |
| `fit_dead_band.m` | ω_ss vs V_eff lineer regresyon → V_dead = x-intercept | step bazlı (K_i, τ_i) | V_dead |
| `validate_model.m` | Simulink ile model çıktısı vs gerçek ölçüm | model params + raw data | RMSE, NRMSE |
| `plot_results.m` | Üç panel: step fit, dead-band intercept, validation | her şey | `results/*.png` |

> **Not:** `results/<test_id>/motor_model_asama1.slx` `create_simulink_model.m` ile **programatik üretilir** — el-yazımı kaynak değil, üretilen çıktıdır (PNG/JSON gibi), bu yüzden `results/`'ta. İki test-id (`20260518_011926` kanonik + `20260518_dogrulama` bağımsız teyit) reproducibility kanıtıdır (docs §10.5).

## Veri Toplama Planı (Aşama 1 firmware tarafı)

`scripts/step_response.py` çalıştırılır (gerçekleşen değerler — docs/asama_1_model.md §10.3):
- 9 duty seviyesi × 2 yön (CW/CCW) = 18 step (drive)
- Her step: 5 sn sürüş + 2 sn coast (drive+coast segment = 36)
- USB telemetri ~36 Hz (TX throttle 40 Hz nominal) — ölçülen 4497 örnek / 126 s
- CSV (13 kolon): `t_us_fw, t_host_s, phase, step_idx, duty_cmd, omega, encoder_count, pitch, roll, gx, gy, fused_pitch, fused_roll`

Çıktı: `artifacts/1/step_response/<test_id>/raw/data.csv.gz`

## Çıktı Formatı

> ⚠ Aşağıdaki değerler **şablon/örnektir** (ilk plandan kalma yer-tutucu). Gerçek üretilen değerler farklı: `K_cw≈54.22`, `tau≈60.5 ms`, ve model `first_order` (dead-band tespit **edilmedi**, `V_dead≈0` — §1.3). Kanonik değerler: `results/20260518_011926/motor_params.json` + `docs/asama_1_model.md` §10.5.

`results/motor_params.json`:
```json
{
  "model": "first_order_with_deadband",
  "K_cw": 12.45,
  "K_ccw": 12.38,
  "tau_cw_s": 0.082,
  "tau_ccw_s": 0.085,
  "V_dead_cw_V": 1.85,
  "V_dead_ccw_V": 1.92,
  "V_supply_V": 12.15,
  "V_sat_V": 0.5,
  "fit_rmse_rad_s": 1.34,
  "kaynak": ["Ljung1999 §3", "Franklin2010 §3", "TB6612_DS §1"]
}
```

Bu JSON Aşama 2'de (kontrolcü tasarımı) `load_motor_params.m` ile okunur.

## Akademik Çıktı

`results/` klasörü hocaya sunum için:
- `step_fit_cw.png`, `step_fit_ccw.png` — her step için ölçüm + fit
- `dead_band_regression.png` — x-intercept ile V_dead tespiti
- `simulink_validation.png` — model output vs ölçüm
- `fit_report.md` — sayısal sonuçlar + kaynak referansları
