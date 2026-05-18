%% Aşama 2.1 — Hız PI tasarımı pipeline
%
% Kullanım:
%   >> run_pipeline_2_1
%   (veya: >> aşama1_test_id = '20260518_011926'; run_pipeline_2_1)
%
% Akış:
%   1. Aşama 1 motor parametreleri yükle
%   2. Pole placement (analitik, ζ=0.707, ω_n=83)
%   3. pidtune × 3 mod (Robust / Balanced / Fast)
%   4. Bode + step + margin karşılaştırma → 3 PNG
%   5. Simulink kapalı döngü modeli (programatik)
%   6. JSON parametre dosyası + Markdown rapor
%
% Çıktı: matlab/asama_2_kontrol/results/<test_id>/
%
% Referanslar:
%   [Franklin2010] §6.4 — pole placement, cascade
%   [Franklin2010] §6.7 — gain/phase margin
%   MATLAB Control System Toolbox > pidtune

if ~exist('a1_test_id', 'var')
    a1_test_id = '20260518_011926';
end

ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results', ['a2_1_' ts]);
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

fprintf('\n=== Aşama 2.1 — Hız PI Tasarımı (test_id=a2_1_%s) ===\n\n', ts);

% 1. Aşama 1 parametreleri
mp = load_motor_params(a1_test_id);

% 2a. Pole placement — agresif (ζ=0.707, Butterworth)
fprintf('\n— Pole placement (agresif, ζ=0.707) —\n');
pi_pp_agg = design_speed_pi_pole_placement(mp, 0.707, 83);
pi_pp_agg.name = 'pole_placement_aggressive';

% 2b. Pole placement — konservatif (ζ=1.0 critically damped, daha düşük ω_n)
% Overshoot ≈ 0; settling time biraz daha uzun ama görsel olarak smooth.
% IMU mirror senaryosu için ideal: kullanıcı eğince motor overshoot yapmaz.
% [Franklin2010] §3.6 — overshoot-istenmeyen sistemler için critical damping.
fprintf('\n— Pole placement (konservatif, ζ=1.0 critically damped) —\n');
pi_pp_con = design_speed_pi_pole_placement(mp, 1.0, 60);
pi_pp_con.name = 'pole_placement_conservative';

% 3. pidtune (3 mod)
fprintf('\n— pidtune (otomatik) —\n');
pi_at = design_speed_pi_autotune(mp);

% 4. Karşılaştırma — 5 kontrolcü
controllers = [struct('Kp',pi_pp_agg.Kp, 'Ki',pi_pp_agg.Ki, 'name',pi_pp_agg.name); ...
               struct('Kp',pi_pp_con.Kp, 'Ki',pi_pp_con.Ki, 'name',pi_pp_con.name); ...
               arrayfun(@(s) struct('Kp',s.Kp,'Ki',s.Ki,'name',s.name), pi_at)];
comparison = compare_speed_pi(mp, controllers, results_dir);

% 5. Simulink kapalı döngü modeli
try
    % Conservative pole placement firmware'e gidecek aday → Simulink modelini
    % onunla kur (aşama 2.2 referansı).
    slx_path = create_speed_loop_simulink(mp, controllers(2), results_dir);
    fprintf('Simulink: %s\n', slx_path);
catch ME
    warning('Simulink model üretilemedi: %s', ME.message);
end

% 6. JSON + Markdown
speed_pi_params = struct( ...
    'model_source',                       mp.source, ...
    'a1_test_id',                         mp.asama1_test_id, ...
    'K_used',                             mp.K_avg, ...
    'tau_used_s',                         mp.tau_s, ...
    'design_pole_placement_aggressive',   struct('Kp',pi_pp_agg.Kp, 'Ki',pi_pp_agg.Ki, ...
                                                  'zeta',pi_pp_agg.zeta, 'omega_n',pi_pp_agg.omega_n, ...
                                                  'tau_cl_s', pi_pp_agg.tau_cl_s), ...
    'design_pole_placement_conservative', struct('Kp',pi_pp_con.Kp, 'Ki',pi_pp_con.Ki, ...
                                                  'zeta',pi_pp_con.zeta, 'omega_n',pi_pp_con.omega_n, ...
                                                  'tau_cl_s', pi_pp_con.tau_cl_s), ...
    'design_pidtune_robust',              struct('Kp',pi_at(1).Kp,'Ki',pi_at(1).Ki, ...
                                                  'PM_deg',pi_at(1).phase_margin_deg, ...
                                                  'wc_rad_s',pi_at(1).crossover_freq_rad_s), ...
    'design_pidtune_balanced',            struct('Kp',pi_at(2).Kp,'Ki',pi_at(2).Ki, ...
                                                  'PM_deg',pi_at(2).phase_margin_deg, ...
                                                  'wc_rad_s',pi_at(2).crossover_freq_rad_s), ...
    'design_pidtune_fast',                struct('Kp',pi_at(3).Kp,'Ki',pi_at(3).Ki, ...
                                                  'PM_deg',pi_at(3).phase_margin_deg, ...
                                                  'wc_rad_s',pi_at(3).crossover_freq_rad_s), ...
    'firmware_selected',                  'pole_placement_conservative', ...
    'firmware_Kp',                        pi_pp_con.Kp, ...
    'firmware_Ki',                        pi_pp_con.Ki, ...
    'comparison',                         comparison, ...
    'Ts_firmware_s',                      0.005, ...
    'kaynak',                             {{'Franklin2010 §6.4', 'Franklin2010 §6.7', ...
                                              'Franklin2010 §3.6 (critical damping)', ...
                                              'AstromMurray2008 §10.2', 'AstromMurray2008 §10.4'}} ...
);

json_path = fullfile(results_dir, 'speed_pi_params.json');
fid = fopen(json_path, 'w');
fwrite(fid, jsonencode(speed_pi_params, 'PrettyPrint', true), 'char');
fclose(fid);
fprintf('\nspeed_pi_params.json → %s\n', json_path);

% Markdown rapor
write_speed_pi_report_(fullfile(results_dir, 'speed_pi_design_report.md'), ...
    mp, pi_pp_agg, pi_pp_con, pi_at, comparison);

save(fullfile(results_dir, 'asama_2_1.mat'), 'mp', 'pi_pp_agg', 'pi_pp_con', 'pi_at', 'comparison');
fprintf('\n=== Aşama 2.1 pipeline tamamlandı ===\n');

% ─── Helper ───────────────────────────────────────────────────────
function write_speed_pi_report_(path, mp, pi_pp_agg, pi_pp_con, pi_at, comparison)
    fid = fopen(path, 'w');
    fprintf(fid, '# Aşama 2.1 — Hız PI Tasarımı Raporu\n\n');
    fprintf(fid, '- **Tarih:** %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
    fprintf(fid, '- **Aşama 1 girişi:** K=%.3f rad/s/V, τ=%.4f s (test_id=%s)\n\n', ...
        mp.K_avg, mp.tau_s, mp.asama1_test_id);

    fprintf(fid, '## Pole Placement A — Agresif (Butterworth, [Franklin2010] §6.4)\n\n');
    fprintf(fid, '- ζ = %.3f (Butterworth)\n', pi_pp_agg.zeta);
    fprintf(fid, '- ω_n = %.1f rad/s (τ_cl = %.1f ms)\n', pi_pp_agg.omega_n, pi_pp_agg.tau_cl_s*1000);
    fprintf(fid, '- **Kp = %.4f, Ki = %.4f**\n', pi_pp_agg.Kp, pi_pp_agg.Ki);
    fprintf(fid, '- Hızlı (~60 ms settling) ama overshoot ~%%15 — gimbal mirror için fazla\n\n');

    fprintf(fid, '## Pole Placement B — Konservatif (Critically Damped, [Franklin2010] §3.6)\n\n');
    fprintf(fid, '- ζ = %.3f (critically damped, sıfır overshoot)\n', pi_pp_con.zeta);
    fprintf(fid, '- ω_n = %.1f rad/s (τ_cl = %.1f ms)\n', pi_pp_con.omega_n, pi_pp_con.tau_cl_s*1000);
    fprintf(fid, '- **Kp = %.4f, Ki = %.4f**\n', pi_pp_con.Kp, pi_pp_con.Ki);
    fprintf(fid, '- ⭐ **Firmware seçimi (Aşama 2.2)** — IMU mirror senaryosu için ideal: smooth, overshoot yok\n\n');

    fprintf(fid, '## pidtune (Otomatik, MATLAB Control System Toolbox)\n\n');
    fprintf(fid, '| Mod | Kp | Ki | ω_c (rad/s) | PM (°) |\n|---|---|---|---|---|\n');
    for k = 1:numel(pi_at)
        fprintf(fid, '| %s | %.4f | %.4f | %.1f | %.1f |\n', ...
            pi_at(k).name, pi_at(k).Kp, pi_at(k).Ki, ...
            pi_at(k).crossover_freq_rad_s, pi_at(k).phase_margin_deg);
    end

    fprintf(fid, '\n## Karşılaştırma Tablosu\n\n');
    fprintf(fid, '| Kontrolcü | Kp | Ki | GM (dB) | PM (°) | T_set (ms) | OS (%%) | ss_err (%%) |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|\n');
    for i = 1:numel(comparison)
        c = comparison(i);
        fprintf(fid, '| %s | %.4f | %.4f | %.2f | %.1f | %.1f | %.2f | %.3f |\n', ...
            c.name, c.Kp, c.Ki, c.GM_dB, c.PM_deg, ...
            c.settling_time_s*1000, c.overshoot_pct, c.ss_error_pct);
    end

    fprintf(fid, '\n## Hedef Performans (Test 2.T1)\n\n');
    fprintf(fid, '- GM ≥ 6 dB, PM ≥ 45°\n');
    fprintf(fid, '- Settling time < 5×τ_ol = 300 ms (konservatif)\n');
    fprintf(fid, '- Overshoot < %%10\n\n');

    fprintf(fid, '## Görsel Kanıtlar\n\n');
    fprintf(fid, '- `01_bode_comparison.png` — Açık döngü Bode (4 kontrolcü)\n');
    fprintf(fid, '- `02_step_response.png` — Kapalı döngü step response\n');
    fprintf(fid, '- `03_metrics_bar.png` — Margin/settling/overshoot bar chart\n');
    fprintf(fid, '- `speed_loop_a2_1.slx` — Simulink kapalı döngü modeli\n');
    fprintf(fid, '- `speed_pi_params.json` — Aşama 2.2 firmware için kaynak\n\n');

    fprintf(fid, '## Aşama 2.2''ye Önerilen Seçim\n\n');
    fprintf(fid, '> Aşağıdaki kontrolcülerden biri firmware''e aktarılacak. ');
    fprintf(fid, 'Sokratik karar: hocaya sunum için **pole placement** akademik şeffaflık, ');
    fprintf(fid, '**pidtune Robust** ise sahada güvenli margin. Aşama 2.2 öncesi onay alınır.\n\n');

    fprintf(fid, '## Kaynakça\n\n');
    fprintf(fid, '- `[Franklin2010] §6.4` — pole placement, cascade kuralları\n');
    fprintf(fid, '- `[Franklin2010] §6.7` — gain/phase margin\n');
    fprintf(fid, '- `[AstromMurray2008] §10.2` — discrete-time PID ayrıştırma\n');
    fprintf(fid, '- `[AstromMurray2008] §10.4` — back-calculation anti-windup\n');
    fclose(fid);
end
