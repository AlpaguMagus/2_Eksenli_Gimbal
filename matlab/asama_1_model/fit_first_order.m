function fit_results = fit_first_order(data, method)
%% Aşama 1.2 — Step bazlı 1. dereceden fit (TOOLBOX TABANLI)
%
% Her drive step için ω(t) = ω_ss · (1 − exp(−(t−t0)/τ)) fitini yapar.
% İki bağımsız yöntem — Soru 1 önerisi C (ikisini de çalıştır, karşılaştır):
%
%   YÖNTEM A — lsqcurvefit (Optimization Toolbox)
%     Doğrudan nonlinear least-squares fit. ω_ss, τ, t0 üçü birden parametre.
%     Avantaj: tam model kontrolü, dead-band gömme genişletilebilir.
%     Referans: [Soderstrom1989] §4
%
%   YÖNTEM B — tfest (System Identification Toolbox)
%     Output-error / prediction-error tahmini. iddata formatı, 1. derece,
%     sıfır gecikme TF. Akademik standart, residual analizine elverişli.
%     Referans: [Ljung1999] §4
%
% Toolbox doğrulaması:
%   exist('lsqcurvefit', 'file') == 2
%   exist('tfest', 'file')       == 2
%
% Girdi:
%   data    — load_step_data çıktısı (struct, .steps array)
%   method  — 'lsqcurve' | 'tfest' | 'both' (default 'both')
%
% Çıktı: fit_results (struct array, drive step başına bir eleman)
%   .duty_cmd, .yon ('CW'|'CCW')
%   .omega_ss              — son %30 ortalaması (rad/s, signed)
%   .tau_s                 — seçilen yöntem sonucu (saniye)
%   .tau_lsqcurve, .tau_tfest
%   .nrmse_pct             — en iyi yöntem NRMSE (%)
%   .nrmse_lsqcurve_pct, .nrmse_tfest_pct
%   .V_eff                 — 12.15·|duty| − 0.5
%   .K_apparent            — |ω_ss| / V_eff (V_eff > 0 ise)
%   .method                — 'lsqcurve' | 'tfest' | 'skipped_below_dead_band'

if nargin < 2
    method = 'both';
end

V_SUPPLY = 12.15;
V_SAT    = 0.5;
DEAD_THRESHOLD_RAD_S = 5.0;

run_lsq = any(strcmp(method, {'lsqcurve', 'both'}));
run_tf  = any(strcmp(method, {'tfest',    'both'}));

if run_lsq && exist('lsqcurvefit', 'file') ~= 2
    error('lsqcurvefit bulunamadı — Optimization Toolbox kurulu mu?');
end
if run_tf && exist('tfest', 'file') ~= 2
    error('tfest bulunamadı — System Identification Toolbox kurulu mu?');
end

drives = data.steps(strcmp({data.steps.phase}, 'drive'));
n = numel(drives);

fit_results = repmat(struct(...
    'duty_cmd', 0, 'yon', '', 'omega_ss', 0, ...
    'tau_s', NaN, 'tau_lsqcurve', NaN, 'tau_tfest', NaN, ...
    'nrmse_pct', NaN, 'nrmse_lsqcurve_pct', NaN, 'nrmse_tfest_pct', NaN, ...
    'V_eff', NaN, 'K_apparent', NaN, 'method', ''), n, 1);

for i = 1:n
    s = drives(i);
    t = s.t_s - s.t_s(1);
    y = s.omega;
    sgn = sign(s.duty_cmd); if sgn == 0, sgn = 1; end
    y_abs = sgn * y;   % CCW için işaret flip — fit pozitif eksende

    n_pts = numel(y_abs);
    ss_start = max(1, round(0.7 * n_pts));
    omega_ss_abs = mean(y_abs(ss_start:end));

    fit_results(i).duty_cmd   = s.duty_cmd;
    fit_results(i).yon        = ternary(s.duty_cmd > 0, 'CW', 'CCW');
    fit_results(i).omega_ss   = sgn * omega_ss_abs;
    fit_results(i).V_eff      = V_SUPPLY * abs(s.duty_cmd) - V_SAT;
    if fit_results(i).V_eff > 0
        fit_results(i).K_apparent = omega_ss_abs / fit_results(i).V_eff;
    end

    if omega_ss_abs < DEAD_THRESHOLD_RAD_S
        fit_results(i).method = 'skipped_below_dead_band';
        continue
    end

    if run_lsq
        [tau_a, nrmse_a] = fit_lsqcurve_(t, y_abs, omega_ss_abs);
        fit_results(i).tau_lsqcurve       = tau_a;
        fit_results(i).nrmse_lsqcurve_pct = nrmse_a;
    end
    if run_tf
        [tau_b, nrmse_b] = fit_tfest_(t, y_abs);
        fit_results(i).tau_tfest          = tau_b;
        fit_results(i).nrmse_tfest_pct    = nrmse_b;
    end

    if run_lsq && run_tf
        if nrmse_a <= nrmse_b
            fit_results(i).tau_s = tau_a; fit_results(i).nrmse_pct = nrmse_a;
            fit_results(i).method = 'lsqcurve';
        else
            fit_results(i).tau_s = tau_b; fit_results(i).nrmse_pct = nrmse_b;
            fit_results(i).method = 'tfest';
        end
    elseif run_lsq
        fit_results(i).tau_s = tau_a; fit_results(i).nrmse_pct = nrmse_a;
        fit_results(i).method = 'lsqcurve';
    else
        fit_results(i).tau_s = tau_b; fit_results(i).nrmse_pct = nrmse_b;
        fit_results(i).method = 'tfest';
    end
end

fprintf('fit_first_order: %d step işlendi (method=%s)\n', n, method);
end

% ─── Yöntem A: lsqcurvefit ────────────────────────────────────────
function [tau, nrmse_pct] = fit_lsqcurve_(t, y, omega_ss)
    % Model: ω(t) = ω_ss * (1 - exp(-(t-t0)/τ)), p = [τ, t0]
    model = @(p, tt) omega_ss .* max(1 - exp(-(tt - p(2)) ./ p(1)), 0);
    p0 = [0.1, 0.0];               % τ=100 ms, t0=0
    lb = [0.005, -0.05];
    ub = [5.0,    0.5];
    opts = optimoptions('lsqcurvefit', 'Display', 'off', ...
        'FunctionTolerance', 1e-8, 'OptimalityTolerance', 1e-8);
    p = lsqcurvefit(model, p0, t, y, lb, ub, opts);
    tau = p(1);
    if tau <= 0 || ~isfinite(tau), tau = NaN; nrmse_pct = Inf; return; end
    y_fit = model(p, t);
    rmse = sqrt(mean((y - y_fit).^2));
    nrmse_pct = 100 * rmse / max(abs(omega_ss), 1);
end

% ─── Yöntem B: tfest (System Identification Toolbox) ─────────────
% Firmware T_US örneklemesi non-uniform (~28-30 ms dalgalanma) → tfest+lsim
% sabit Ts ister. Uniform grid'e interpolate + 10 örnek pre-zero (step öncesi
% equilibrium): tfest doc önerisi (model_order < n_prefix).
function [tau, nrmse_pct] = fit_tfest_(t, y)
    Ts = 0.025;   % 40 Hz hedef (firmware throttle); uniform grid bu adımda
    if t(end) <= 0 || numel(t) < 5
        tau = NaN; nrmse_pct = Inf; return
    end
    t_uniform = (0:Ts:t(end))';
    y_uniform = interp1(t, y, t_uniform, 'linear', 'extrap');

    % Pre-zero: 10 örnek ω=0, u=0, sonra step başlar
    n_pre = 10;
    y_padded = [zeros(n_pre, 1); y_uniform];
    u_padded = [zeros(n_pre, 1); ones(size(y_uniform))];
    t_padded = (0:Ts:Ts*(numel(y_padded)-1))';

    data_id = iddata(y_padded, u_padded, Ts);
    opt = tfestOptions('Display', 'off', 'InitMethod', 'iv');
    try
        sys = tfest(data_id, 1, 0, opt);     % 1 pole, 0 zero
    catch
        tau = NaN; nrmse_pct = Inf; return
    end
    p = pole(sys);
    if isempty(p) || real(p(1)) == 0
        tau = NaN; nrmse_pct = Inf; return
    end
    tau = -1 / real(p(1));
    if tau <= 0 || ~isfinite(tau), tau = NaN; nrmse_pct = Inf; return; end

    % NRMSE — orijinal (non-uniform) ölçüm vs fit, uniform t'de hesaplayıp interp
    y_fit_padded = lsim(sys, u_padded, t_padded);
    y_fit_uniform = y_fit_padded(n_pre+1:end);
    y_fit_at_orig = interp1(t_uniform, y_fit_uniform, t, 'linear', 'extrap');
    rmse = sqrt(mean((y - y_fit_at_orig).^2));
    nrmse_pct = 100 * rmse / max(abs(y(end)), 1);
end

function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end
