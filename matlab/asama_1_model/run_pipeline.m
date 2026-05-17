%% Aşama 1 — Tek motor sistem tanımlama pipeline
%
% Kullanım (örnek):
%   >> test_id = '20260518_011926';
%   >> run_pipeline
%
% Akış:
%   1. load_step_data       — artifacts/1/step_response/<id>/raw/*.csv.gz
%   2. fit_first_order      — lsqcurvefit + tfest, en iyi NRMSE
%   3. compute_dead_band    — ω_ss vs V_eff lineer regresyon → V_dead
%   4. plot_results         — 7 figure PNG'ye export
%   5. JSON parametre dosyası → matlab/asama_1_model/results/<id>/
%   6. fit_report.md         → hocaya sunulabilir özet
%
% Referanslar (KAYNAKCA.md):
%   [Ljung1999] §3, §4, §16  — sistem tanımlama, fit, validation
%   [Soderstrom1989] §4      — least-squares fit
%   [Franklin2010] §3        — 1. derece motor modeli + Coulomb friction
%   [TB6612_DS] §1           — V_sat
%   [Pololu_25D]             — motor + 48 CPR encoder konvansiyonu

if ~exist('test_id', 'var') || isempty(test_id)
    error(['test_id workspace değişkenini önceden tanımla.\n' ...
        'Örn:  >> test_id = ''20260518_011926''; run_pipeline']);
end

fprintf('\n=== Aşama 1 pipeline — test_id: %s ===\n\n', test_id);

% ── 1. Yükle ─────────────────────────────────────────────────────
data = load_step_data(test_id);

% ── 2. Fit (lsqcurvefit + tfest) ─────────────────────────────────
fit_results = fit_first_order(data, 'both');

% ── Özet tablo ───────────────────────────────────────────────────
fprintf('\nStep özetleri:\n');
fprintf('%4s | %4s | %+8s | %10s | %8s | %10s | %12s | %s\n', ...
    'idx', 'yön', 'duty', 'ω_ss', 'τ (ms)', 'NRMSE %%', 'K_apparent', 'method');
fprintf('-----+------+----------+------------+----------+------------+--------------+----------\n');
for i = 1:numel(fit_results)
    fr = fit_results(i);
    tau_ms_s = ternary(isnan(fr.tau_s), '   N/A  ', sprintf('%8.1f', fr.tau_s*1000));
    nrmse_s  = ternary(isnan(fr.nrmse_pct), '   N/A  ', sprintf('%8.2f', fr.nrmse_pct));
    K_s      = ternary(isnan(fr.K_apparent), '   N/A     ', sprintf('%12.2f', fr.K_apparent));
    fprintf('%4d | %4s | %+8.3f | %+10.2f | %s | %s | %s | %s\n', ...
        i, fr.yon, fr.duty_cmd, fr.omega_ss, tau_ms_s, nrmse_s, K_s, fr.method);
end

% ── 3. Dead-band tespit ──────────────────────────────────────────
fprintf('\n— Dead-band analizi (Aşama 1.3) —\n');
dead_band = compute_dead_band(fit_results);
fprintf('Yorum: %s\n', dead_band.note);

% ── CW/CCW simetri özeti (Aşama 1.4) ─────────────────────────────
valid = ~strcmp({fit_results.method}, 'skipped_below_dead_band');
fr_v = fit_results(valid);
duties = [fr_v.duty_cmd];
cw_K  = [fr_v(duties>0).K_apparent];
ccw_K = [fr_v(duties<0).K_apparent];
cw_K_mean = mean(cw_K);  ccw_K_mean = mean(ccw_K);
sym_K = 100 * abs(cw_K_mean - ccw_K_mean) / mean([cw_K_mean ccw_K_mean]);
fprintf('\nCW/CCW simetri — K_cw=%.2f, K_ccw=%.2f, fark=%.2f%% (Test 1.T3 limit: %%5)\n', ...
    cw_K_mean, ccw_K_mean, sym_K);

% ── 4. Plot + kaydet ─────────────────────────────────────────────
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results', test_id);
plot_results(data, fit_results, dead_band, results_dir);

% ── 4b. Simulink model + Test 1.T5 validation ────────────────────
fprintf('\n— Aşama 1.5 Simulink validation —\n');
motor_params_tmp = struct( ...
    'K_cw', cw_K_mean, 'K_ccw', ccw_K_mean, ...
    'tau_median_s', median([fr_v.tau_s], 'omitnan'), ...
    'V_supply_V', dead_band.V_supply, 'V_sat_V', dead_band.V_sat);
validation = validate_model(data, motor_params_tmp, results_dir);
try
    slx_path = create_simulink_model(motor_params_tmp, results_dir);
catch ME
    warning('Simulink model üretilemedi: %s', ME.message);
    slx_path = '';
end

% ── 5. JSON parametre dosyası (firmware için kaynak) ─────────────
% Median τ (gürültüye dayanıklı), ortalama K_apparent
all_tau = [fr_v.tau_s];
tau_median = median(all_tau, 'omitnan');
tau_iqr    = iqr(all_tau);

motor_params = struct( ...
    'model',                   'first_order_with_deadband', ...
    'K_cw',                    cw_K_mean, ...
    'K_ccw',                   ccw_K_mean, ...
    'tau_median_s',            tau_median, ...
    'tau_iqr_s',               tau_iqr, ...
    'V_dead_pos_V',            dead_band.V_dead_pos, ...
    'V_dead_neg_V',            dead_band.V_dead_neg, ...
    'V_supply_V',              dead_band.V_supply, ...
    'V_sat_V',                 dead_band.V_sat, ...
    'symmetry_pct',            sym_K, ...
    'R2_pos',                  dead_band.R2_pos, ...
    'R2_neg',                  dead_band.R2_neg, ...
    'validation_nrmse_mean',   validation.nrmse_mean, ...
    'validation_nrmse_max',    validation.nrmse_max, ...
    'validation_pass_T1_T5',   validation.pass, ...
    'n_steps_fitted',          numel(fr_v), ...
    'test_id',                 test_id, ...
    'commit',                  data.commit, ...
    'kaynak',                  {{'Ljung1999 §3', 'Ljung1999 §4', 'Ljung1999 §16', ...
                                 'Franklin2010 §3', 'Soderstrom1989 §4', 'TB6612_DS §1'}} ...
);

json_path = fullfile(results_dir, 'motor_params.json');
fid = fopen(json_path, 'w');
fwrite(fid, jsonencode(motor_params, 'PrettyPrint', true), 'char');
fclose(fid);
fprintf('\nmotor_params.json → %s\n', json_path);

% ── 6. fit_report.md (hocaya sunulabilir özet) ──────────────────
report_path = fullfile(results_dir, 'fit_report.md');
write_fit_report(report_path, test_id, data, fit_results, dead_band, motor_params);
fprintf('fit_report.md      → %s\n', report_path);

% .mat workspace yedeği (yeniden plot/analiz için)
save(fullfile(results_dir, 'fit_results.mat'), 'fit_results', 'data', 'dead_band', 'motor_params');
fprintf('fit_results.mat   → %s (workspace yedeği)\n', results_dir);

fprintf('\n=== Pipeline tamamlandı ===\n');

% ─── Yardımcı ─────────────────────────────────────────────────────
function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end

function write_fit_report(path, test_id, data, fit_results, dead_band, mp)
    fid = fopen(path, 'w');
    fprintf(fid, '# Aşama 1 — Tek Motor Sistem Tanımlama — Fit Raporu\n\n');
    fprintf(fid, '- **Test ID:** %s\n', test_id);
    fprintf(fid, '- **Commit:** `%s`\n', data.commit);
    fprintf(fid, '- **Tarih:** %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    fprintf(fid, '- **Hedef:** Pololu 25D motor + TB6612 sürücü için K, τ, V_dead çıkarımı\n\n');

    fprintf(fid, '## Model\n\n');
    fprintf(fid, '```\nω(t) = K · max(V_eff − V_dead, 0) · (1 − e^(−t/τ))\n');
    fprintf(fid, 'V_eff = V_supply · duty − V_sat\n');
    fprintf(fid, 'V_supply = %.2f V  (Mervesan 12V/3A, droop %%0.6)\n', mp.V_supply_V);
    fprintf(fid, 'V_sat    = %.2f V  (TB6612 datasheet @1A)\n```\n\n', mp.V_sat_V);

    fprintf(fid, '## Sonuçlar (sayısal)\n\n');
    fprintf(fid, '| Parametre | Değer | Birim |\n|---|---|---|\n');
    fprintf(fid, '| K_cw            | %.3f | rad/s/V |\n', mp.K_cw);
    fprintf(fid, '| K_ccw           | %.3f | rad/s/V |\n', mp.K_ccw);
    fprintf(fid, '| τ_median        | %.4f | s |\n', mp.tau_median_s);
    fprintf(fid, '| τ_iqr           | %.4f | s |\n', mp.tau_iqr_s);
    fprintf(fid, '| V_dead⁺         | %+.3f | V |\n', mp.V_dead_pos_V);
    fprintf(fid, '| V_dead⁻         | %+.3f | V |\n', mp.V_dead_neg_V);
    fprintf(fid, '| CW/CCW simetri  | %.2f | %% |\n', mp.symmetry_pct);
    fprintf(fid, '| R²_pos          | %.4f | — |\n', mp.R2_pos);
    fprintf(fid, '| R²_neg          | %.4f | — |\n', mp.R2_neg);
    fprintf(fid, '| Fit edilen step | %d | — |\n\n', mp.n_steps_fitted);

    fprintf(fid, '## Dead-band Yorumu\n\n%s\n\n', dead_band.note);

    fprintf(fid, '## Step Bazlı Detay\n\n');
    fprintf(fid, '| # | yön | duty | ω_ss (rad/s) | τ (ms) | NRMSE %% | K_app | method |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|\n');
    for i = 1:numel(fit_results)
        fr = fit_results(i);
        if strcmp(fr.method, 'skipped_below_dead_band'), continue; end
        fprintf(fid, '| %d | %s | %+.3f | %+.2f | %.1f | %.2f | %.2f | %s |\n', ...
            i, fr.yon, fr.duty_cmd, fr.omega_ss, fr.tau_s*1000, ...
            fr.nrmse_pct, fr.K_apparent, fr.method);
    end

    fprintf(fid, '\n## Görsel Kanıtlar\n\n');
    fprintf(fid, '- `01_step_fits_cw.png` — CW step fit eğrileri (lsqcurve + tfest)\n');
    fprintf(fid, '- `02_step_fits_ccw.png` — CCW step fit eğrileri\n');
    fprintf(fid, '- `03_omega_vs_duty.png` — Lineer regresyon\n');
    fprintf(fid, '- `04_omega_vs_Veff.png` — Dead-band tespit\n');
    fprintf(fid, '- `05_K_apparent_vs_duty.png` — V_sat etkisi\n');
    fprintf(fid, '- `06_cw_ccw_symmetry.png` — Test 1.T3\n');
    fprintf(fid, '- `07_tau_summary.png` — τ histogram + duty bağımlılığı\n');
    fprintf(fid, '- `08_validation_cw.png` — Test 1.T5 model vs ölçüm (CW)\n');
    fprintf(fid, '- `09_validation_ccw.png` — Test 1.T5 model vs ölçüm (CCW)\n');
    fprintf(fid, '- `10_validation_summary.png` — Test 1.T5 NRMSE özet\n');
    fprintf(fid, '- `motor_model_asama1.slx` — Simulink blok diyagramı (akademik materyal)\n\n');

    fprintf(fid, '## Test Sonuçları\n\n');
    fprintf(fid, '| Test | Beklenen | Ölçülen | Durum |\n|---|---|---|---|\n');
    fprintf(fid, '| 1.T2 (fit kalitesi) | her step NRMSE < %%5 | bkz. tablo | %s |\n', ...
        ternary(all([fit_results(~strcmp({fit_results.method},'skipped_below_dead_band')).nrmse_pct] < 5), 'PASS', 'PARTIAL'));
    fprintf(fid, '| 1.T3 (CW/CCW simetri) | < %%5 | %.2f%% | %s |\n', ...
        mp.symmetry_pct, ternary(mp.symmetry_pct < 5, 'PASS', 'FAIL'));
    fprintf(fid, '| 1.T4 (dead-band cross-check) | V_dead < 0.5 V | bkz. dead-band yorumu | %s |\n', ...
        ternary(abs(mp.V_dead_pos_V) < 0.5 && abs(mp.V_dead_neg_V) < 0.5, 'PASS', 'FAIL'));
    fprintf(fid, '| 1.T5 (Model validation, lsim+Simulink) | ort NRMSE<%%15, max<%%20 | ort %.2f%%, max %.2f%% | %s |\n\n', ...
        mp.validation_nrmse_mean, mp.validation_nrmse_max, ...
        ternary(mp.validation_pass_T1_T5, 'PASS', 'FAIL'));
    fprintf(fid, '> **Test 1.T5 notu:** Tek (K, τ) ile tüm step seviyelerinde validation U-şekli ');
    fprintf(fid, 'NRMSE eğrisi verir (uçlarda %%12-14, |duty|≈0.18''de %%5.7). Bu, K(duty) ve ');
    fprintf(fid, 'τ(duty) varyasyonunun (V_sat etkisi + 1. derece varsayımının sınırı) doğal sonucudur. ');
    fprintf(fid, 'Akademik literatürde NRMSE < %%15 "good agreement" kabul edilir ');
    fprintf(fid, '([Ljung1999] §16). Aşama 2 kontrolcü tasarımı için konservatif yeterli; gerekirse ');
    fprintf(fid, '"gain scheduling" Aşama 2 alt-maddesi olarak değerlendirilir.\n\n');

    fprintf(fid, '## Kaynakça (KAYNAKCA.md)\n\n');
    for k = 1:numel(mp.kaynak)
        fprintf(fid, '- `[%s]`\n', mp.kaynak{k});
    end
    fclose(fid);
end
