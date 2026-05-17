function plot_results(data, fit_results, dead_band, out_dir)
%% Aşama 1 — Fit sonuçlarını görselleştir + kaydet
%
% Üretilen figureler:
%   01_step_fits_cw.png       — CW yön drive step'leri + fit eğrileri (4×N subplot)
%   02_step_fits_ccw.png      — CCW yön drive step'leri + fit eğrileri
%   03_omega_vs_duty.png      — ω_ss vs duty (lineer regresyon)
%   04_omega_vs_Veff.png      — ω_ss vs V_eff + dead-band tespit (x-intercept)
%   05_K_apparent_vs_duty.png — K_apparent profil (Vsat etkisi)
%   06_cw_ccw_symmetry.png    — CW/CCW K, τ farkları
%   07_tau_summary.png        — τ histogramı + duty bağımlılığı
%
% Tüm figureler PNG olarak out_dir'e kaydedilir.

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

drive_mask  = strcmp({data.steps.phase}, 'drive');
drives_data = data.steps(drive_mask);

% ── 01-02: Step fit eğrileri ─────────────────────────────────────
plot_step_fits(drives_data, fit_results, 'CW',  ...
    fullfile(out_dir, '01_step_fits_cw.png'));
plot_step_fits(drives_data, fit_results, 'CCW', ...
    fullfile(out_dir, '02_step_fits_ccw.png'));

% ── 03: ω_ss vs duty (lineer regresyon) ──────────────────────────
duties = [fit_results.duty_cmd]';
omegas = [fit_results.omega_ss]';
valid  = ~strcmp({fit_results.method}, 'skipped_below_dead_band');
duties = duties(valid); omegas = omegas(valid);

f3 = figure('Visible', 'off', 'Position', [50 50 800 500], 'Color', 'w');
plot(duties, omegas, 'o', 'MarkerFaceColor', [0.2 0.4 0.8], 'MarkerSize', 8); hold on
% Lineer regresyon (sadece pozitif yön; negatif yön ayna)
p_pos = polyfit(duties(duties>0), omegas(duties>0), 1);
p_neg = polyfit(duties(duties<0), omegas(duties<0), 1);
d_pos = linspace(0, 0.5, 50); d_neg = linspace(-0.5, 0, 50);
plot(d_pos, polyval(p_pos, d_pos), '-', 'LineWidth', 1.5, 'Color', [0.8 0.2 0.2]);
plot(d_neg, polyval(p_neg, d_neg), '-', 'LineWidth', 1.5, 'Color', [0.2 0.6 0.2]);
grid on; xlabel('duty (signed)'); ylabel('\omega_{ss} (rad/s)');
title(sprintf('\\omega_{ss} vs duty — CW slope = %.1f, CCW slope = %.1f rad/s/duty', ...
    p_pos(1), p_neg(1)));
legend({'ölçüm', sprintf('CW fit: %.1f·d + %.1f', p_pos(1), p_pos(2)), ...
                 sprintf('CCW fit: %.1f·d + %.1f', p_neg(1), p_neg(2))}, ...
       'Location', 'best');
exportgraphics(f3, fullfile(out_dir, '03_omega_vs_duty.png'), 'Resolution', 150);
close(f3);

% ── 04: ω_ss vs V_eff → V_dead = x-intercept ─────────────────────
V_supply = 12.15; V_sat = 0.5;
V_eff_signed = sign(duties) .* (V_supply * abs(duties) - V_sat);
f4 = figure('Visible', 'off', 'Position', [50 50 800 500], 'Color', 'w');
plot(V_eff_signed, omegas, 'o', 'MarkerFaceColor', [0.5 0.2 0.7], 'MarkerSize', 8); hold on
% Tek lineer fit (her iki yön)
p_v = polyfit(V_eff_signed, omegas, 1);
V_range = linspace(min(V_eff_signed)-0.2, max(V_eff_signed)+0.2, 100);
plot(V_range, polyval(p_v, V_range), '-', 'LineWidth', 1.5, 'Color', [0.2 0.2 0.2]);
xline(dead_band.V_dead_pos,  '--r', sprintf('V_{dead}^{+} = %.3f V', dead_band.V_dead_pos));
xline(dead_band.V_dead_neg,  '--g', sprintf('V_{dead}^{-} = %.3f V', dead_band.V_dead_neg));
yline(0, 'k:');
grid on; xlabel('V_{eff} = sign(duty)·(V_{supply}·|duty| − V_{sat})');
ylabel('\omega_{ss} (rad/s)');
title(sprintf('Dead-band tespit: V_{dead}^{+}=%.3f V, V_{dead}^{-}=%.3f V (K_{fit}=%.1f rad/s/V)', ...
    dead_band.V_dead_pos, dead_band.V_dead_neg, abs(p_v(1))));
exportgraphics(f4, fullfile(out_dir, '04_omega_vs_Veff.png'), 'Resolution', 150);
close(f4);

% ── 05: K_apparent vs duty (Vsat etkisi) ─────────────────────────
K_app = [fit_results.K_apparent]';
K_app = K_app(valid);
f5 = figure('Visible', 'off', 'Position', [50 50 800 500], 'Color', 'w');
plot(abs(duties), K_app, 'o', 'MarkerFaceColor', [0.9 0.5 0.1], 'MarkerSize', 8);
grid on; xlabel('|duty|'); ylabel('K_{apparent} = |\omega_{ss}| / V_{eff} (rad/s/V)');
title('K_{apparent} duty bağımlılığı — V_{sat} etkisi (küçük duty\rightarrow düşük K)');
exportgraphics(f5, fullfile(out_dir, '05_K_apparent_vs_duty.png'), 'Resolution', 150);
close(f5);

% ── 06: CW/CCW simetri ─────────────────────────────────────────────
abs_duties_unique = unique(abs(duties));
cw_K  = NaN(numel(abs_duties_unique), 1);
ccw_K = NaN(numel(abs_duties_unique), 1);
cw_tau = NaN(numel(abs_duties_unique), 1);
ccw_tau = NaN(numel(abs_duties_unique), 1);
for k = 1:numel(abs_duties_unique)
    d = abs_duties_unique(k);
    fr_valid = fit_results(valid);
    cw_idx = find(strcmp({fr_valid.yon}, 'CW') & abs([fr_valid.duty_cmd]) == d, 1);
    ccw_idx = find(strcmp({fr_valid.yon}, 'CCW') & abs([fr_valid.duty_cmd]) == d, 1);
    if ~isempty(cw_idx),  cw_K(k)  = fr_valid(cw_idx).K_apparent; cw_tau(k)  = fr_valid(cw_idx).tau_s; end
    if ~isempty(ccw_idx), ccw_K(k) = fr_valid(ccw_idx).K_apparent; ccw_tau(k) = fr_valid(ccw_idx).tau_s; end
end
f6 = figure('Visible', 'off', 'Position', [50 50 900 400], 'Color', 'w');
subplot(1,2,1);
plot(abs_duties_unique, cw_K, '-o', 'LineWidth', 1.5); hold on
plot(abs_duties_unique, ccw_K, '-s', 'LineWidth', 1.5);
grid on; legend('CW', 'CCW', 'Location','best');
xlabel('|duty|'); ylabel('K_{apparent} (rad/s/V)'); title('K karşılaştırma');
subplot(1,2,2);
plot(abs_duties_unique, cw_tau*1000, '-o', 'LineWidth', 1.5); hold on
plot(abs_duties_unique, ccw_tau*1000, '-s', 'LineWidth', 1.5);
grid on; legend('CW', 'CCW', 'Location','best');
xlabel('|duty|'); ylabel('\tau (ms)'); title('\tau karşılaştırma');
sgtitle('CW/CCW simetri analizi (Test 1.T3)');
exportgraphics(f6, fullfile(out_dir, '06_cw_ccw_symmetry.png'), 'Resolution', 150);
close(f6);

% ── 07: τ özet (histogram + duty bağımlılığı) ────────────────────
taus = [fit_results.tau_s]'; taus = taus(valid);
f7 = figure('Visible', 'off', 'Position', [50 50 900 400], 'Color', 'w');
subplot(1,2,1);
histogram(taus*1000, 8, 'FaceColor', [0.3 0.6 0.8]);
xlabel('\tau (ms)'); ylabel('frekans'); title('\tau histogramı'); grid on
subplot(1,2,2);
plot(abs(duties), taus*1000, 'o', 'MarkerFaceColor', [0.3 0.6 0.8]); grid on
xlabel('|duty|'); ylabel('\tau (ms)'); title('\tau duty bağımlılığı');
sgtitle(sprintf('\\tau özet — ortalama %.1f ms, std %.1f ms (n=%d)', ...
    mean(taus)*1000, std(taus)*1000, numel(taus)));
exportgraphics(f7, fullfile(out_dir, '07_tau_summary.png'), 'Resolution', 150);
close(f7);

fprintf('Plotlar kaydedildi: %s/\n', out_dir);
end

% ─── Yardımcı: step fit eğrilerini grid'le çiz ────────────────────
function plot_step_fits(drives_data, fit_results, yon, out_path)
    mask = strcmp({fit_results.yon}, yon) & ...
           ~strcmp({fit_results.method}, 'skipped_below_dead_band');
    idx_fit = find(mask);
    n_plots = numel(idx_fit);
    if n_plots == 0, return; end

    rows = ceil(n_plots / 3);
    cols = min(3, n_plots);
    f = figure('Visible', 'off', 'Position', [50 50 1200 250*rows], 'Color', 'w');

    for k = 1:n_plots
        i_global = idx_fit(k);
        i_drive  = find_step_index(drives_data, fit_results(i_global));
        if isempty(i_drive), continue; end

        s  = drives_data(i_drive);
        fr = fit_results(i_global);
        sgn = sign(fr.duty_cmd); if sgn == 0, sgn = 1; end
        t = s.t_s - s.t_s(1);
        y_meas_abs = sgn * s.omega;

        subplot(rows, cols, k);
        plot(t, y_meas_abs, '.', 'Color', [0.4 0.4 0.4], 'MarkerSize', 4); hold on
        omega_ss_abs = abs(fr.omega_ss);
        if ~isnan(fr.tau_lsqcurve)
            y_lsq = omega_ss_abs * (1 - exp(-t / fr.tau_lsqcurve));
            plot(t, y_lsq, '-', 'LineWidth', 1.4, 'Color', [0.85 0.2 0.2]);
        end
        if ~isnan(fr.tau_tfest)
            y_tf = omega_ss_abs * (1 - exp(-t / fr.tau_tfest));
            plot(t, y_tf, '--', 'LineWidth', 1.4, 'Color', [0.2 0.5 0.85]);
        end
        grid on
        title(sprintf('duty %+.3f  |  \\tau=%.1f ms  NRMSE=%.2f%%', ...
            fr.duty_cmd, fr.tau_s*1000, fr.nrmse_pct));
        xlabel('t (s)'); ylabel('|\omega| (rad/s)');
        if k == 1
            legend({'ölçüm', 'lsqcurve', 'tfest'}, 'Location', 'southeast', 'FontSize', 7);
        end
    end
    sgtitle(sprintf('Step response fitleri — %s yön', yon));
    exportgraphics(f, out_path, 'Resolution', 150);
    close(f);
end

function idx = find_step_index(drives, fr)
    duty_diff = abs([drives.duty_cmd] - fr.duty_cmd);
    [~, idx] = min(duty_diff);
    if duty_diff(idx) > 1e-6, idx = []; end
end
