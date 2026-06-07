function verify_antiwindup()
% VERIFY_ANTIWINDUP  Test 2.T3 (sim) — anti-windup recovery doğrulaması.
%
% Anti-windup back-calculation (§11.6) mekanizmasının integrator wind-up'ı
% önlediğini SİMÜLASYONDA gösterir. Analitik-önce sıra: önce sim teoriyi
% kanıtlar, sonra gerçek motorda doğrulanır (scripts/antiwindup_test.py).
%
% Senaryo: ULAŞILAMAZ step 0→450 rad/s (u=0.5 ile max ω=K·Vs·0.5=327 → setpoint
% asla ulaşılamaz, error sürekli pozitif, integrator durmadan şişer = wind-up),
% sonra 450→50 rad/s. Wind-up etkisi iniş geçişinde görünür: anti-windup kapalıysa
% şişmiş integratör boşalana kadar u yüksek kalır, ω 50'ye geç iner (recovery gecikir).
%
% Firmware ile uyumlu ayrık PI (Ts=5 ms, çalışan Kp=0.002, Ki=0.1, T_t=Kp/Ki),
% saturation ±0.5 duty, plant duty→ω = K·Vs/(τs+1).
%
% Kaynak: [AstromMurray2008] §10.4 (back-calculation anti-windup)
% Çalıştırma: matlab -batch "cd('matlab/asama_2_kontrol'); verify_antiwindup"

    K = 53.89; tau = 0.0605; Vs = 12.15;
    Ts = 0.005; Kp = 0.002; Ki = 0.1; Tt = Kp/Ki; umax = 0.5;

    % plant ayrık (duty→ω), 1. derece exact:  ω[k]=a·ω[k-1]+b·u[k-1]
    a = exp(-Ts/tau);  b = K*Vs*(1-a);

    % setpoint profili
    T = 0:Ts:3.0;  N = numel(T);
    sp = 450*ones(1,N);  sp(T>=1.0) = 50;   % 1.0 s'de 450→50 (recovery testi)

    [w_aw, u_aw, i_aw] = run_pi(sp, a, b, Kp, Ki, Ts, Tt, umax, true);
    [w_no, u_no, i_no] = run_pi(sp, a, b, Kp, Ki, Ts, Tt, umax, false);

    % recovery metriği: 450→50 geçişinden sonra 50'ye ±%5 (±2.5) oturma
    rec_aw = settle_time(T, w_aw, 1.0, 50, 2.5);
    rec_no = settle_time(T, w_no, 1.0, 50, 2.5);
    Imax_aw = max(i_aw);  Imax_no = max(i_no);

    fprintf('=== Test 2.T3 (sim) — anti-windup recovery (450->50, saturation) ===\n');
    fprintf('anti-windup ACIK : recovery=%.0f ms, max integrator=%.2f\n', rec_aw*1000, Imax_aw);
    fprintf('anti-windup KAPALI: recovery=%.0f ms, max integrator=%.2f\n', rec_no*1000, Imax_no);
    fprintf('-> anti-windup integratör şişmesini sınırlar → recovery hızlanır\n');

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '2_3_realistic_sim');
    if ~exist(outdir, 'dir'); mkdir(outdir); end
    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultTextColor','k', 'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    f = figure('Position', [80 80 900 640], 'Color', 'w');
    subplot(3,1,1);
    plot(T, sp, 'k:', 'LineWidth',1.2); hold on; grid on;
    plot(T, w_aw, 'b', 'LineWidth',1.8);
    plot(T, w_no, 'r--', 'LineWidth',1.5);
    yline(50,'Color',[0.5 0.5 0.5]);
    ylabel('\omega [rad/s]'); title('Test 2.T3 (sim) — Anti-Windup Recovery (step 450\rightarrow50, saturation)', 'FontWeight','bold');
    legend('setpoint','anti-windup ON','anti-windup OFF','Location','northeast', ...
        'TextColor','k','Color','w','EdgeColor',[0.6 0.6 0.6]);

    subplot(3,1,2);
    plot(T, u_aw, 'b', 'LineWidth',1.5); hold on; grid on;
    plot(T, u_no, 'r--', 'LineWidth',1.3);
    yline(umax,'k:'); yline(-umax,'k:');
    ylabel('u (duty)'); legend('ON','OFF','Location','northeast','TextColor','k','Color','w','EdgeColor',[0.6 0.6 0.6]);

    subplot(3,1,3);
    plot(T, i_aw, 'b', 'LineWidth',1.5); hold on; grid on;
    plot(T, i_no, 'r--', 'LineWidth',1.3);
    ylabel('integrator'); xlabel('time [s]');
    legend('ON (sinirli)','OFF (wind-up)','Location','northeast','TextColor','k','Color','w','EdgeColor',[0.6 0.6 0.6]);

    exportgraphics(f, fullfile(outdir, 'antiwindup_recovery.png'), 'Resolution',150);
    close(f);
    fprintf('Gorsel: %s/antiwindup_recovery.png\n', outdir);
end

% ── ayrık PI (firmware uyumlu) ───────────────────────────────────────
function [w, u, ival] = run_pi(sp, a, b, Kp, Ki, Ts, Tt, umax, aw)
    N = numel(sp);
    w = zeros(1,N); u = zeros(1,N); ival = zeros(1,N);
    I = 0; uprev = 0;
    for k = 2:N
        w(k) = a*w(k-1) + b*uprev;          % plant
        e = sp(k) - w(k);
        I = I + Ki*Ts*e;                    % integratör (backward Euler)
        u_unsat = Kp*e + I;
        u(k) = max(-umax, min(umax, u_unsat));  % saturation
        if aw
            I = I + (Ts/Tt)*(u(k) - u_unsat);   % back-calculation
        end
        ival(k) = I;
        uprev = u(k);
    end
end

% ── oturma süresi (t0 sonrası hedefe ±tol içinde kalış) ──────────────
function ts = settle_time(T, y, t0, target, tol)
    idx = find(T >= t0);
    ts = NaN;
    for j = 1:numel(idx)
        seg = idx(j):numel(T);
        if all(abs(y(seg) - target) <= tol)
            ts = T(idx(j)) - t0; return;
        end
    end
end
