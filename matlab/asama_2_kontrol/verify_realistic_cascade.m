%% Aşama 2.5 — Gerçekçi cascade simülasyonu (kuantizasyon dahil)
%
% NEDEN: Aşama 2.3'te ideal Simulink sim bang-bang'i ÖNGÖREMEDİ; gerçekçi
% sim (kuantizasyon + moving-avg + saturation) öngördü ve gerçek motorla
% birebir tuttu. Aynı disiplini cascade'e uyguluyoruz.
%
% KRİTİK SORU: pozisyon hedefe yaklaşırken e_θ→0 → ω_ref→0. Ama hız ölçümü
% 18.7 rad/s'den küçüğü ayırt edemiyor (encoder kuantizasyon). Son yaklaşma
% fazında hız PI "ω=0" görüp duty verir mi → sürünme / limit-cycle?
%
% YAPI (ayrık zaman, gerçek firmware'i taklit):
%   Dış döngü (40 Hz): θ_ref → e_θ → ω_ref = Kp_pos·e_θ (çıkış mili)
%   İç döngü  (40 Hz): ω_ref_motor = ω_ref·9.7 → hız PI → duty
%   Plant: 1. derece motor (K,τ) + redüktör + entegratör (açı)
%
% GERÇEKÇİLİK katmanları (verify_realistic_sim.m'den):
%   - Hız ölçümü kuantizasyonu: 18.7 rad/s (1 count @ dt~7ms)
%   - Hız moving-average: 5 örnek
%   - Duty saturation: ±0.5 (lockout)
%   - V_sat: TB6612 doyma gerilimi
%   + Pozisyon ölçümü kuantizasyonu: 466 event/rev çıkış mili = 0.773°/count
%
% Referans: [Franklin2010] §6.4 (cascade), §8 (ayrık kontrol kuantizasyon)

clear; close all; clc;

% ── Motor + kontrol parametreleri ─────────────────────────────────
K   = 53.89;   tau = 0.0605;          % Aşama 1
Kp_i = 0.002;  Ki_i = 0.1;            % Aşama 2.3 ampirik hız PI
Kp_pos = 2.00;                        % design_position_p.m (çıkış mili düzlemi)
GEAR = 9.7;                           % redüktör (motor şaftı / çıkış mili)
V_supply = 12.15; V_sat = 0.5;        % Aşama 1 motor_params.json (12V besleme!)

% ── Ayrık zaman ───────────────────────────────────────────────────
dt = 0.007;                           % ~7 ms (gerçek döngü periyodu, DWT ölçümü)
T  = 4.0; N = round(T/dt);
t  = (0:N-1)*dt;

% Kuantizasyon
OMEGA_Q = 18.7;                       % rad/s (hız, motor şaftı)
POS_Q   = 2*pi/466;                   % rad (çıkış mili açısı, 466 event/rev)
MA = 5;                               % hız moving-average penceresi

% ── Referans: 30° çıkış mili step ─────────────────────────────────
theta_ref = deg2rad(30) * ones(1,N);

% ── Durum değişkenleri ────────────────────────────────────────────
omega_m = 0;          % motor şaftı gerçek hız (rad/s)
theta_out = 0;        % çıkış mili gerçek açı (rad)
i_pi = 0;             % PI integral durumu
omega_hist = zeros(1,MA);
u_prev = 0; e_prev = 0;
Ts_t = Kp_i/Ki_i;     % back-calculation zaman sabiti (PI: Kp/Ki)

% Kayıt
log_theta = zeros(1,N); log_omega = zeros(1,N);
log_u = zeros(1,N); log_wref = zeros(1,N);

for k = 1:N
    % ── Pozisyon ölçümü (kuantize, çıkış mili) ───────────────────
    theta_meas = round(theta_out/POS_Q)*POS_Q;

    % ── DIŞ DÖNGÜ: pozisyon P ────────────────────────────────────
    e_theta = theta_ref(k) - theta_meas;          % çıkış mili rad
    omega_ref_out = Kp_pos * e_theta;             % çıkış mili rad/s
    omega_ref_m = omega_ref_out * GEAR;           % motor şaftı rad/s

    % ── Hız ölçümü (kuantize + moving-avg) ───────────────────────
    omega_q = round(omega_m/OMEGA_Q)*OMEGA_Q;
    omega_hist = [omega_hist(2:end), omega_q];
    omega_f = mean(omega_hist);

    % ── İÇ DÖNGÜ: hız PI (Tustin + back-calculation) ─────────────
    e = omega_ref_m - omega_f;
    i_pi = i_pi + Ki_i*dt/2*(e + e_prev);         % Tustin integral
    u_unsat = Kp_i*e + i_pi;
    u = max(min(u_unsat, 0.5), -0.5);             % saturation (lockout)
    if Ts_t > 0                                   % anti-windup back-calc
        i_pi = i_pi + (dt/Ts_t)*(u - u_unsat);
    end
    e_prev = e;

    % ── Plant: motor 1. derece + V_sat ───────────────────────────
    V_eff = sign(u)*max(abs(u)*V_supply - V_sat, 0);
    omega_ss = K * V_eff;                         % kararlı hal hızı (motor şaftı)
    omega_m = omega_m + dt/tau*(omega_ss - omega_m);  % 1. derece
    theta_out = theta_out + (omega_m/GEAR)*dt;    % çıkış mili açı entegratörü

    log_theta(k)=theta_out; log_omega(k)=omega_m;
    log_u(k)=u; log_wref(k)=omega_ref_m;
end

% ── Metrikler ─────────────────────────────────────────────────────
theta_deg = rad2deg(log_theta);
ref_deg = rad2deg(theta_ref(1));
tail = theta_deg(round(0.7*N):end);
ss_err = abs(mean(tail)-ref_deg)/ref_deg*100;
overshoot = max(0, (max(theta_deg)-ref_deg)/ref_deg*100);
% Settling ±%5: pozisyon kuant. 0.773° = %2.6 of 30° → ±%2 fiziksel imkansız
band = 0.05*ref_deg;  settle=NaN;
for k=1:N
    if all(abs(theta_deg(k:end)-ref_deg)<=band), settle=t(k); break; end
end
% Limit-cycle / sürünme kontrolü: kararlı halde u std
u_tail = log_u(round(0.7*N):end);
u_std = std(u_tail);
verdict = 'STABİL'; if u_std>0.15, verdict='⚠ LIMIT-CYCLE'; end

fprintf('Gerçekçi cascade sim (Kp_pos=%.2f, iç PI=%.3f/%.1f):\n', Kp_pos, Kp_i, Ki_i);
fprintf('  θ_ref = %.0f° (çıkış mili)\n', ref_deg);
fprintf('  ss_error = %.2f%%, overshoot = %.1f%%, settling = %.2f s\n', ss_err, overshoot, settle);
fprintf('  kararlı hal u_std = %.3f → %s\n', u_std, verdict);
fprintf('  POS_Q = %.3f° (pozisyon çözünürlük), OMEGA_Q = %.1f rad/s (hız)\n', rad2deg(POS_Q), OMEGA_Q);

% ── Plot ──────────────────────────────────────────────────────────
fig = figure('Visible','off','Position',[50 50 1100 700],'Color','w');
subplot(3,1,1);
plot(t, theta_deg,'b','LineWidth',1.4); hold on
yline(ref_deg,'r--'); yline(ref_deg*1.02,'k:'); yline(ref_deg*0.98,'k:');
grid on; ylabel('\theta_{out} (°)');
title(sprintf('Gerçekçi cascade — θ takip (ss_err=%.1f%%, OS=%.1f%%, settle=%.2fs)', ss_err, overshoot, settle));
subplot(3,1,2);
plot(t, log_wref,'m','LineWidth',1.0); hold on
plot(t, log_omega,'b','LineWidth',1.2);
grid on; ylabel('\omega motor (rad/s)'); legend('\omega_{ref}','\omega gerçek','Location','northeast');
title('İç döngü hız referansı vs gerçek hız');
subplot(3,1,3);
plot(t, log_u,'k','LineWidth',1.0);
grid on; ylabel('duty u'); xlabel('t (s)'); ylim([-0.55 0.55]);
title(sprintf('Kontrol sinyali (kararlı hal u\\_std=%.3f → %s)', u_std, verdict));
sgtitle('Aşama 2.5 — Gerçekçi cascade simülasyonu (kuantizasyon dahil)');

out = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out, 'realistic_cascade.png'), 'Resolution', 150);
fprintf('\nÇıktı: %s/realistic_cascade.png\n', out);
