function pi_pp = design_speed_pi_pole_placement(mp, zeta, omega_n)
%% Aşama 2.1 — Hız PI tasarımı (Pole placement, analitik)
%
% Plant:  G(s) = K / (τs + 1)
% Controller: C(s) = Kp + Ki/s = (Kp·s + Ki)/s
%
% Closed-loop transfer:
%   T(s) = G·C / (1 + G·C)
%        = K(Kp·s + Ki) / [τs² + (1 + K·Kp)s + K·Ki]
%
% İkinci derece standart form: s² + 2ζω_n·s + ω_n²
% Eşitlik (denominator τ ile bölünür):
%   s² + ((1 + K·Kp)/τ)·s + (K·Ki/τ) = s² + 2ζω_n·s + ω_n²
%
% Çözüm:
%   Ki = ω_n² · τ / K
%   Kp = (2·ζ·ω_n·τ − 1) / K
%
% Referans: [Franklin2010] §6.4 (cascade + pole placement)
%
% Girdi:
%   mp       — load_motor_params çıktısı
%   zeta     — kapalı döngü damping ratio (default 0.707 ≈ Butterworth)
%   omega_n  — kapalı döngü doğal frekans (rad/s, default 83 ≈ τ_cl=12 ms)
%
% Çıktı: pi_pp struct
%   .Kp, .Ki
%   .zeta, .omega_n, .tau_cl_s
%   .name = 'pole_placement'

if nargin < 2, zeta = 0.707; end
if nargin < 3, omega_n = 83; end   % τ_cl ≈ 1/ω_n = 12 ms (≈ τ_ol/5)

K = mp.K_avg;
tau = mp.tau_s;

Ki = omega_n^2 * tau / K;
Kp = (2 * zeta * omega_n * tau - 1) / K;

pi_pp.Kp        = Kp;
pi_pp.Ki        = Ki;
pi_pp.zeta      = zeta;
pi_pp.omega_n   = omega_n;
pi_pp.tau_cl_s  = 1 / omega_n;
pi_pp.name      = 'pole_placement';
pi_pp.formula   = sprintf('Kp=(2ζω_nτ−1)/K=%.4f, Ki=ω_n²τ/K=%.4f', Kp, Ki);

fprintf('Pole placement (ζ=%.3f, ω_n=%.1f rad/s, τ_cl=%.1f ms):\n', ...
    zeta, omega_n, pi_pp.tau_cl_s*1000);
fprintf('  Kp = %.4f, Ki = %.4f\n', Kp, Ki);
end
