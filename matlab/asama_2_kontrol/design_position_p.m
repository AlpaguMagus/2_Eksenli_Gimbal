%% Aşama 2.5 — Pozisyon dış döngü P kontrolcü tasarımı (cascade)
%
% Cascade yapısı:
%   θ_ref → (+) → [Kp_pos] → ω_ref → [hız iç döngü PI] → motor → ω → (1/s) → θ
%            ↑                                                              │
%            └──────────────── pozisyon geri besleme ─────────────────────┘
%
% İç döngü: hız PI (ÇALIŞAN kazanç, Aşama 2.3 — analitik: doyum-kısıtı + doğru-plant
%   pole placement, design_speed_pi_corrected.m):
%   Kp_i = 0.002, Ki_i = 0.1  (conservative 2.1 değil — o, yanlış plant + doyum yüzünden bang-bang)
%
% Dış döngü: P kontrolcü. Plant tip-1 (hız→pozisyon entegratör) → P ile ss_error=0
%   ([Franklin2010] §4.3). PI gereksiz (wind-up riski).
%
% Tasarım: dış döngü crossover ω_c ≈ ω_n_iç / 5 (cascade kuralı [Franklin2010] §6.4).
%
% Referans: [Franklin2010] §6.4 (cascade), §4.3 (tip-1 ss error)

clear; close all; clc;

% Beyaz tema zorla — dark MATLAB session'da axes panelleri siyah kalıyordu
% (figure 'Color','w' yetmiyor; axes/text de zorlanmalı). CLAUDE.md figür disiplini.
set(groot,'defaultFigureColor','w','defaultAxesColor','w', ...
    'defaultAxesXColor','k','defaultAxesYColor','k','defaultTextColor','k', ...
    'defaultAxesGridColor',[0.15 0.15 0.15]);

% ── İç döngü (çalışan kazanç) ─────────────────────────────────────
K   = 53.89;   tau = 0.0605;       % Aşama 1 motor modeli
Kp_i = 0.002;  Ki_i = 0.1;         % Aşama 2.3 çalışan hız PI (analitik, §11.12.3)

G       = tf(K, [tau 1]);          % plant: V_eff → ω
C_inner = pid(Kp_i, Ki_i);         % hız PI
T_inner = feedback(G * C_inner, 1);% iç döngü kapalı-döngü: ω_ref → ω

% İç döngü karakteristik
wn_inner = sqrt(abs(K*Ki_i/tau));
zeta_inner = (1 + K*Kp_i) / (2*sqrt(K*Ki_i*tau));
fprintf('İç döngü (kapalı): ω_n=%.2f rad/s, ζ=%.3f\n', wn_inner, zeta_inner);

% ── Dış döngü plant: hız→pozisyon entegratör ──────────────────────
P_outer = T_inner * tf(1, [1 0]);  % T_inner · (1/s)

% ── Pozisyon P kazancı: ω_c_dış ≈ ω_n_iç / 5 ──────────────────────
wc_target = wn_inner / 5;
% Düşük frekansta T_inner≈1, P_outer≈1/s → |L(jωc)|=Kp_pos/ωc=1 → Kp_pos≈ωc
% MATLAB ile kesin: Kp_pos tara, hedef crossover'a en yakını seç
Kp_candidates = 0.5:0.1:5.0;
best_Kp = wc_target; best_err = inf;
for kp = Kp_candidates
    L = kp * P_outer;
    [~, ~, ~, wcp] = margin(L);
    if ~isnan(wcp) && abs(wcp - wc_target) < best_err
        best_err = abs(wcp - wc_target); best_Kp = kp;
    end
end
Kp_pos = best_Kp;

% Doğrulama
L = Kp_pos * P_outer;
T_outer = feedback(L, 1);
[Gm, Pm, ~, Wcp] = margin(L);
info = stepinfo(T_outer);

fprintf('\nPozisyon P tasarımı:\n');
fprintf('  hedef ω_c = %.2f rad/s (ω_n_iç/5)\n', wc_target);
fprintf('  Kp_pos = %.2f [1/s]\n', Kp_pos);
fprintf('  ω_c (gerçek) = %.2f rad/s\n', Wcp);
fprintf('  Gain margin = %.1f dB, Phase margin = %.1f°\n', 20*log10(Gm), Pm);
fprintf('  Step: settling=%.2f s, overshoot=%.1f%%, ss_error≈0 (tip-1)\n', ...
    info.SettlingTime, info.Overshoot);

% ── Plot: step response + Bode ────────────────────────────────────
fig = figure('Visible','off','Position',[50 50 1100 450],'Color','w');
subplot(1,2,1);
[y,t] = step(T_outer, 0:0.01:5);
plot(t, y, 'b', 'LineWidth', 1.6); hold on
yline(1,'r--'); yline(0.98,'k:'); yline(1.02,'k:');
grid on; xlabel('t (s)'); ylabel('\theta / \theta_{ref}');
title(sprintf('Pozisyon step — Kp_{pos}=%.2f, settling=%.1fs, OS=%.1f%%', ...
    Kp_pos, info.SettlingTime, info.Overshoot));
subplot(1,2,2);
margin(L); grid on;   % margin() Gm/Pm oto-başlığı yeterli — ek title + sgtitle çakışıyordu

out = fullfile(fileparts(mfilename('fullpath')), 'results', '2_5_cascade');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out, 'position_p_design.png'), 'Resolution', 150);

% ── JSON (firmware için) ──────────────────────────────────────────
% BİRİM NOTU: MATLAB tasarımı tutarlı SI (θ rad, ω rad/s). Firmware'de
% encoder çıkış mili derece → rad dönüşümü + motor şaftı ω ölçeği dikkat.
%   ω_ref [motor şaftı rad/s] = Kp_pos · (θ_ref − θ) [çıkış mili rad] · 9.7
%   (çıkış mili açı hatası → motor şaftı hız referansı, redüktör 9.7)
params = struct('Kp_pos', Kp_pos, 'unit', '1/s (SI: theta rad, omega rad/s)', ...
    'wc_outer_rad_s', Wcp, 'wn_inner_rad_s', wn_inner, 'PM_deg', Pm, ...
    'GM_dB', 20*log10(Gm), 'settling_s', info.SettlingTime, 'overshoot_pct', info.Overshoot, ...
    'inner_Kp', Kp_i, 'inner_Ki', Ki_i, 'gear_ratio', 9.7, ...
    'note', 'cascade outer P; tip-1 sistem ss_error=0; firmware birim donusumu gerekli', ...
    'kaynak', {{'Franklin2010 §6.4','Franklin2010 §4.3'}});
fid = fopen(fullfile(out, 'position_p_params.json'), 'w');
fwrite(fid, jsonencode(params, 'PrettyPrint', true), 'char'); fclose(fid);
fprintf('\nÇıktılar: %s/ (position_p_design.png + position_p_params.json)\n', out);
