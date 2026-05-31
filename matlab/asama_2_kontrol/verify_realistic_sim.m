%% Aşama 2.3 → 2b — Gerçekçi kapalı-döngü simülasyon (sim-to-real gap doğrulama)
%
% Amaç: Aşama 2.3'te ampirik bulunan Kp=0.002'yi TEORİK doğrulamak.
% Aşama 2.1 Simulink modeli IDEAL ölçüm varsaymıştı → conservative Kp=0.1163
% mükemmel görünüyordu. Gerçek sistemde bang-bang verdi. Bu script gerçek
% sistemin efektlerini modele ekler:
%   1. Encoder kuantizasyonu (1 count ≈ 18.7 rad/s @ 7ms)
%   2. Moving-average ölçüm filtresi (WINDOW=5)
%   3. Duty saturation (±0.50)
%   4. Setpoint slew rate
%   5. V_sat sürücü kaybı
%
% Beklenti: conservative (Kp=0.1163) → bang-bang; ampirik (Kp=0.002) → stabil.
% Bu, sim-to-real gap'i kapatır ve ampirik kazancı teorik temellendirir.
%
% Referans: [Franklin2010] §6.4, [AstromMurray2008] §10.2-10.4, [Ljung1999] §16

clear; close all; clc;

% Beyaz tema zorla — dark MATLAB session'da axes panelleri siyah kalıyordu
% (figure 'Color','w' yetmiyor; axes/text de zorlanmalı). CLAUDE.md figür disiplini.
set(groot,'defaultFigureColor','w','defaultAxesColor','w', ...
    'defaultAxesXColor','k','defaultAxesYColor','k','defaultTextColor','k', ...
    'defaultAxesGridColor',[0.15 0.15 0.15]);

% ── Plant parametreleri (Aşama 1) ─────────────────────────────────
K       = 53.89;     % rad/s/V
tau     = 0.0605;    % s
V_sup   = 12.15;     % V
V_sat   = 0.5;       % V
Ts      = 0.005;     % s (200 Hz)
duty_max = 0.50;

% ── Gerçekçi efektler ─────────────────────────────────────────────
QUANT   = 18.7;      % rad/s — encoder kuantizasyon adımı (gözlemlenen)
WINDOW  = 5;         % moving-average pencere
SLEW    = 200;       % rad/s/s setpoint slew
SP      = 50;        % rad/s hedef setpoint
T_END   = 2.0;       % s simülasyon süresi

% Plant ayrık (ZOH): Veff → ω
sysc = tf(K, [tau 1]);
sysd = c2d(sysc, Ts);
[bnum, bden] = tfdata(sysd, 'v');   % ω[k] = -bden(2)*ω[k-1] + bnum(2)*Veff[k-1]

% ── İki kazanç setini simüle et ───────────────────────────────────
gains = struct('name', {'conservative (2.1)', 'ampirik (2.3)'}, ...
               'Kp',   {0.1163, 0.002}, ...
               'Ki',   {4.0447, 0.1});

N = round(T_END / Ts);
t = (0:N-1) * Ts;

figure('Visible','off','Position',[50 50 1100 700],'Color','w');

for g = 1:numel(gains)
    Kp = gains(g).Kp;  Ki = gains(g).Ki;
    T_t = Kp / Ki;     % anti-windup tracking time

    % State
    omega_true = 0;          % gerçek hız (plant çıkışı)
    Veff_prev  = 0;
    omega_prev = 0;
    integ      = 0;
    prev_err   = 0;
    sp_actual  = 0;
    win = zeros(1, WINDOW);  wi = 1; wfill = 0;

    omega_log = zeros(1,N);  u_log = zeros(1,N);  sp_log = zeros(1,N);  meas_log = zeros(1,N);

    for k = 1:N
        % Setpoint slew
        d = SP - sp_actual;
        ms = SLEW * Ts;
        if d > ms, sp_actual = sp_actual + ms;
        elseif d < -ms, sp_actual = sp_actual - ms;
        else, sp_actual = SP; end

        % Encoder kuantizasyon (gerçek hız → ölçülen)
        omega_meas = round(omega_true / QUANT) * QUANT;

        % Moving-average filtre
        win(wi) = omega_meas;  wi = mod(wi, WINDOW) + 1;
        if wfill < WINDOW, wfill = wfill + 1; end
        omega_filt = sum(win) / wfill;

        % PI (Tustin) + anti-windup
        err = sp_actual - omega_filt;
        u_p = Kp * err;
        integ = integ + Ki * Ts * 0.5 * (err + prev_err);
        u_unsat = u_p + integ;
        u_sat = max(min(u_unsat, duty_max), -duty_max);
        if T_t > 0
            integ = integ + (Ts / T_t) * (u_sat - u_unsat);
        end
        prev_err = err;

        % Duty → V_eff (işaret + V_sat kaybı)
        Veff = V_sup * u_sat - sign(u_sat) * V_sat;

        % Plant (ayrık): ω[k] = -bden(2)*ω[k-1] + bnum(2)*Veff[k-1]
        omega_true = -bden(2)*omega_prev + bnum(2)*Veff_prev;
        omega_prev = omega_true;  Veff_prev = Veff;

        omega_log(k) = omega_true;  u_log(k) = u_sat;
        sp_log(k) = sp_actual;      meas_log(k) = omega_meas;
    end

    % Metrik
    tail = round(0.6*N):N;
    om_ss = mean(omega_log(tail));  om_sd = std(omega_log(tail));
    u_sd  = std(u_log(tail));
    bang  = u_sd > 0.2 || (max(u_log(tail))-min(u_log(tail))) > 0.6;
    if bang, verdict = 'BANG-BANG'; else, verdict = 'STABIL'; end
    fprintf('%-22s Kp=%.4f Ki=%.4f → ω_ss=%.1f, ω_std=%.1f, u_std=%.3f → %s\n', ...
        gains(g).name, Kp, Ki, om_ss, om_sd, u_sd, verdict);

    % Plot
    subplot(2,2,g);
    plot(t, omega_log, 'b', 'LineWidth', 1.2); hold on
    plot(t, sp_log, 'k--', 'LineWidth', 1);
    yline(SP, 'r:');
    grid on; xlabel('t (s)'); ylabel('\omega (rad/s)');
    title(sprintf('%s — Kp=%.4f, Ki=%.3f', gains(g).name, Kp, Ki));
    lg = legend('\omega','setpoint(slew)','Location','best'); set(lg,'Color','w','TextColor','k');
    ylim([-300 300]);

    subplot(2,2,g+2);
    plot(t, u_log, 'm', 'LineWidth', 1.2); hold on
    yline(duty_max, 'r:'); yline(-duty_max, 'r:');
    grid on; xlabel('t (s)'); ylabel('U (duty)');
    title(sprintf('Kontrol çıkışı — u\\_std=%.3f (%s)', u_sd, verdict));
    ylim([-0.6 0.6]);
end

sgtitle('Aşama 2.3→2b: Gerçekçi model (kuantizasyon+filtre+saturation) — sim-to-real doğrulama','Color','k');
out = fullfile(fileparts(mfilename('fullpath')), 'results', '2_3_realistic_sim');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(gcf, fullfile(out, 'realistic_sim_verification.png'), 'Resolution', 150);
fprintf('\nPlot: %s\n', fullfile(out, 'realistic_sim_verification.png'));
