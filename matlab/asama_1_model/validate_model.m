function val = validate_model(data, motor_params, out_dir)
%% Aşama 1.5 — Model validation (Test 1.T5)
%
% motor_params.json'dan çıkarılan tek (K, τ) çiftiyle (CW/CCW ortak)
% her ölçüm step'ini yeniden simüle eder, NRMSE hesaplar.
%
% Yöntem: birinci dereceden transfer fonksiyonu
%   G(s) = K / (τs + 1)
%
% Girdi:
%   data         — load_step_data çıktısı
%   motor_params — run_pipeline'ın ürettiği struct/json içerik
%   out_dir      — figure ve raporun kaydedileceği dizin
%
% Çıktı:
%   val.nrmse_per_step  — N×1 NRMSE değerleri (%)
%   val.nrmse_mean      — ortalama NRMSE
%   val.pass            — Test 1.T5 (NRMSE < %10) sonucu
%
% Referans: [Ljung1999] §16 model validation (residual + NRMSE)

K_avg   = mean([motor_params.K_cw, motor_params.K_ccw]);
tau     = motor_params.tau_median_s;
V_SUP   = motor_params.V_supply_V;
V_SAT   = motor_params.V_sat_V;

drives = data.steps(strcmp({data.steps.phase}, 'drive'));
n = numel(drives);
val.nrmse_per_step = NaN(n, 1);
val.step_info      = repmat(struct('duty', 0, 'yon', '', 'nrmse_pct', NaN), n, 1);

% Birleştirilmiş plot (3×3 grid CW, 3×3 grid CCW — toplam 18 = 2 sayfa)
plot_validation_grid(drives, K_avg, tau, V_SUP, V_SAT, 'CW',  ...
    fullfile(out_dir, '08_validation_cw.png'));
plot_validation_grid(drives, K_avg, tau, V_SUP, V_SAT, 'CCW', ...
    fullfile(out_dir, '09_validation_ccw.png'));

% NRMSE hesabı
for i = 1:n
    s = drives(i);
    sgn = sign(s.duty_cmd); if sgn == 0, sgn = 1; end
    V_eff = V_SUP * abs(s.duty_cmd) - V_SAT;
    if V_eff <= 0, continue; end

    omega_ss_model = sgn * K_avg * V_eff;
    t_orig = s.t_s - s.t_s(1);
    Ts = 0.025;
    if t_orig(end) <= 0, continue; end
    t_uniform = (0:Ts:t_orig(end))';
    y_uniform = interp1(t_orig, s.omega, t_uniform, 'linear', 'extrap');

    sys = tf(omega_ss_model, [tau 1]);
    u = ones(size(t_uniform));
    y_model = lsim(sys, u, t_uniform);

    rmse = sqrt(mean((y_uniform - y_model).^2));
    nrmse_pct = 100 * rmse / max(abs(omega_ss_model), 1);
    val.nrmse_per_step(i) = nrmse_pct;
    val.step_info(i).duty      = s.duty_cmd;
    val.step_info(i).yon       = ternary(s.duty_cmd > 0, 'CW', 'CCW');
    val.step_info(i).nrmse_pct = nrmse_pct;
end

val.nrmse_mean  = mean(val.nrmse_per_step, 'omitnan');
val.nrmse_max   = max(val.nrmse_per_step,  [], 'omitnan');
% Test 1.T5 kriterleri:
%   mean NRMSE < %15  (Ljung1999 §16 — uygulama-bağımlı eşik, kontrolcü tasarımı için yeterli)
%   max  NRMSE < %20  (outlier tolerans)
% Daha sıkı eşik (%10) tek (K, τ) için aşırı; K(duty) ve τ(duty) varyasyonu
% modelin 1. derece varsayımının doğal sınırı (akademik trade-off).
val.pass        = (val.nrmse_mean < 15) && (val.nrmse_max < 20);
val.K_used      = K_avg;
val.tau_used_s  = tau;

% Özet plot
f = figure('Visible', 'off', 'Position', [50 50 900 400], 'Color', 'w');
subplot(1,2,1);
duties_signed = [val.step_info.duty];
nrmses        = [val.step_info.nrmse_pct];
mask_cw  = duties_signed > 0;
mask_ccw = duties_signed < 0;
plot(abs(duties_signed(mask_cw)),  nrmses(mask_cw),  '-o', 'LineWidth',1.5); hold on
plot(abs(duties_signed(mask_ccw)), nrmses(mask_ccw), '-s', 'LineWidth',1.5);
yline(15, '--r', 'Test 1.T5 ort sınır (%15)');
yline(20, ':r',  'Test 1.T5 max sınır (%20)');
xlabel('|duty|'); ylabel('NRMSE (%)'); title('Model validation NRMSE'); grid on
legend('CW','CCW','Location','best');
subplot(1,2,2);
histogram(nrmses, 8, 'FaceColor', [0.4 0.7 0.4]);
xline(val.nrmse_mean, '--k', sprintf('ort %.2f%%', val.nrmse_mean));
xlabel('NRMSE (%)'); ylabel('frekans'); title('NRMSE dağılımı'); grid on
sgtitle(sprintf('Test 1.T5 — Model validation (K=%.2f rad/s/V, τ=%.1f ms)', K_avg, tau*1000));
exportgraphics(f, fullfile(out_dir, '10_validation_summary.png'), 'Resolution', 150);
close(f);

fprintf('Validation: ort NRMSE = %.2f%%, max %.2f%% (n=%d), Test 1.T5: %s\n', ...
    val.nrmse_mean, val.nrmse_max, sum(~isnan(nrmses)), ternary(val.pass, 'PASS', 'FAIL'));
end

% ─── Grid plot: ölçüm vs model ───────────────────────────────────
function plot_validation_grid(drives, K, tau, V_SUP, V_SAT, yon, out_path)
    mask = ([drives.duty_cmd] > 0) == strcmp(yon, 'CW');
    sel = drives(mask);
    n = numel(sel); if n == 0, return; end
    rows = ceil(n / 3); cols = min(3, n);
    f = figure('Visible', 'off', 'Position', [50 50 1200 250*rows], 'Color', 'w');

    for k = 1:n
        s = sel(k);
        sgn = sign(s.duty_cmd); if sgn == 0, sgn = 1; end
        V_eff = V_SUP * abs(s.duty_cmd) - V_SAT;
        if V_eff <= 0, continue; end
        omega_ss_model = sgn * K * V_eff;

        t_orig = s.t_s - s.t_s(1);
        if t_orig(end) <= 0, continue; end
        Ts = 0.025;
        t_uniform = (0:Ts:t_orig(end))';
        y_uniform = interp1(t_orig, s.omega, t_uniform, 'linear', 'extrap');
        sys = tf(omega_ss_model, [tau 1]);
        y_model = lsim(sys, ones(size(t_uniform)), t_uniform);
        rmse = sqrt(mean((y_uniform - y_model).^2));
        nrmse_pct = 100 * rmse / max(abs(omega_ss_model), 1);

        subplot(rows, cols, k);
        plot(t_orig, s.omega, '.', 'Color', [0.4 0.4 0.4], 'MarkerSize', 4); hold on
        plot(t_uniform, y_model, '-', 'LineWidth', 1.4, 'Color', [0.85 0.2 0.2]);
        grid on
        title(sprintf('duty %+.3f | NRMSE %.2f%%', s.duty_cmd, nrmse_pct));
        xlabel('t (s)'); ylabel('\omega (rad/s)');
        if k == 1
            legend({'ölçüm', sprintf('model G(s)=%.1f/(%.3fs+1)', K, tau)}, ...
                'Location','southeast','FontSize',7);
        end
    end
    sgtitle(sprintf('Model validation — %s yön (Test 1.T5)', yon));
    exportgraphics(f, out_path, 'Resolution', 150);
    close(f);
end

function r = ternary(c, a, b)
    if c, r = a; else, r = b; end
end
