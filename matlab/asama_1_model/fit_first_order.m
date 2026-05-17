function fit_results = fit_first_order(data, method)
%% Aşama 1.2 — Step bazlı 1. dereceden fit
%
% Her drive step için ω(t) = ω_ss · (1 − exp(−(t−t0)/τ)) fitini yapar.
% İki yöntem desteklenir (Soru 1 önerisi C — ikisini de çalıştır,
% karşılaştırma raporu için).
%
% Girdi:
%   data    — load_step_data çıktısı
%   method  — 'tfest' | 'lsqcurve' | 'both' (default 'both')
%
% Çıktı (fit_results struct array, drive step'ler için):
%   .duty_cmd, .yon ('CW'/'CCW')
%   .omega_ss, .tau_s, .K_estimate (V_eff hesabı ile)
%   .nrmse_pct, .residual_std
%   .method
%
% Referanslar:
%   [Ljung1999] §4 — tfest / output-error
%   [Soderstrom1989] §4 — least-squares closed-form
%   [Franklin2010] §3 — 1. dereceden motor modeli
%
% NOT: Bu iskelet implementasyondur. Aşama 1.2 başlarken
% sokratik tartışma sonrası `tfest` veya `lsqcurvefit` çağrıları
% somutlaştırılacak. Şu an placeholder.

if nargin < 2
    method = 'both';
end

V_supply = 12.15;
V_sat    = 0.5;

drives = data.steps(strcmp({data.steps.phase}, 'drive'));
n = numel(drives);
fit_results(n, 1) = struct('duty_cmd', 0, 'yon', '', 'omega_ss', 0, ...
    'tau_s', 0, 'K_estimate', 0, 'nrmse_pct', 0, 'residual_std', 0, 'method', '');

for i = 1:n
    s = drives(i);
    t = s.t_s - s.t_s(1);
    y = s.omega;

    % Steady-state: son %30 ortalaması
    n_pts = numel(y);
    ss_start = max(1, round(0.7 * n_pts));
    omega_ss = mean(y(ss_start:end));

    % Dead-band altı: dönmüyorsa fit yapma
    if abs(omega_ss) < 5
        fit_results(i).duty_cmd  = s.duty_cmd;
        fit_results(i).yon       = ternary(s.duty_cmd > 0, 'CW', 'CCW');
        fit_results(i).omega_ss  = omega_ss;
        fit_results(i).method    = 'skipped_below_dead_band';
        continue
    end

    switch lower(method)
        case 'lsqcurve'
            [tau, nrmse] = fit_lsqcurve_(t, y, omega_ss);
        case 'tfest'
            [tau, nrmse] = fit_tfest_(t, y, omega_ss);
        case 'both'
            [tau_a, nrmse_a] = fit_lsqcurve_(t, y, omega_ss);
            [tau_b, nrmse_b] = fit_tfest_(t, y, omega_ss);
            % Daha iyi NRMSE seçilir; rapor edilirken her ikisi de tutulur
            if nrmse_a < nrmse_b
                tau = tau_a; nrmse = nrmse_a; method_used = 'lsqcurve';
            else
                tau = tau_b; nrmse = nrmse_b; method_used = 'tfest';
            end
        otherwise
            error('Bilinmeyen method: %s', method);
    end

    V_eff = V_supply * abs(s.duty_cmd) - V_sat;
    K_est = NaN;
    if V_eff > 0
        K_est = abs(omega_ss) / V_eff;  % dead-band öncesi kaba tahmin
    end

    fit_results(i).duty_cmd      = s.duty_cmd;
    fit_results(i).yon           = ternary(s.duty_cmd > 0, 'CW', 'CCW');
    fit_results(i).omega_ss      = omega_ss;
    fit_results(i).tau_s         = tau;
    fit_results(i).K_estimate    = K_est;
    fit_results(i).nrmse_pct     = nrmse;
    fit_results(i).method        = ifelse(strcmp(method,'both'), method_used, method);
end

fprintf('fit_first_order: %d step işlendi (method=%s)\n', n, method);
end

% ── Yardımcılar ─────────────────────────────────────────────────────
function [tau, nrmse_pct] = fit_lsqcurve_(t, y, omega_ss)
    % ω(t) = omega_ss * (1 - exp(-t/tau))
    model = @(p, tt) omega_ss .* (1 - exp(-tt ./ p(1)));
    p0 = 0.1;  % τ initial guess (Aşama 0 ölçümlerinden ~80-100 ms)
    opts = optimoptions('lsqcurvefit', 'Display', 'off');
    p = lsqcurvefit(model, p0, t, y, 0.005, 5, opts);
    tau = p(1);
    y_fit = model(p, t);
    rmse = sqrt(mean((y - y_fit).^2));
    nrmse_pct = 100 * rmse / max(abs(omega_ss), 1);
end

function [tau, nrmse_pct] = fit_tfest_(t, y, omega_ss) %#ok<INUSD>
    % iddata + tfest(1, 0) → 1. derece, sıfır gecikme
    Ts = mean(diff(t));
    if Ts <= 0, Ts = 0.025; end
    data_id = iddata(y, ones(size(y)) * sign(omega_ss), Ts);
    sys = tfest(data_id, 1, 0);
    % Time constant = -1 / pole
    p = pole(sys);
    if isempty(p) || p(1) == 0
        tau = NaN;
    else
        tau = -1 / real(p(1));
    end
    [y_fit, ~] = lsim(sys, ones(size(y)) * sign(omega_ss), t);
    rmse = sqrt(mean((y - y_fit).^2));
    nrmse_pct = 100 * rmse / max(abs(omega_ss), 1);
end

function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end

function r = ifelse(cond, a, b)
    if cond, r = a; else, r = b; end
end
