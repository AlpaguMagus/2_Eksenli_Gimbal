function pi_at = design_speed_pi_autotune(mp, robustness_modes)
%% Aşama 2.1 — Hız PI tasarımı (pidtune, MATLAB Control System Toolbox)
%
% pidtune otomatik kontrolcü tasarımı — kapalı döngü bant genişliğini
% ve fazlık marjini optimize eder. Pole placement'ten farkı:
%   - Robustness slider (0-1) ile margin/performans tradeoff'u
%   - Bode tabanlı tasarım (frekans bölgesi)
%   - 3 standart mod karşılaştırma için döndürülür
%
% Modlar:
%   'Robust'   — Phase margin 60°+, geniş margin (default 0.7 robustness)
%   'Balanced' — MATLAB default (robustness 0.5)
%   'Fast'     — Phase margin 45°, hızlı yanıt (robustness 0.3)
%
% Referans: MathWorks Control System Toolbox > pidtune
%
% Girdi:
%   mp                  — load_motor_params çıktısı
%   robustness_modes    — cell array {'Robust','Balanced','Fast'} (default hepsi)
%
% Çıktı: pi_at struct array (her mod için 1 eleman)
%   .Kp, .Ki, .name, .robustness, .crossover_freq_rad_s, .phase_margin_deg

if nargin < 2, robustness_modes = {'Robust','Balanced','Fast'}; end

% Plant: G(s) = K / (τs + 1)
G = tf(mp.K_avg, [mp.tau_s 1]);

% pidtuneOptions ile crossover frequency override edebiliriz, ama
% varsayılan otomatik seçim akademik karşılaştırma için daha sade.
robustness_map = struct('Robust', 0.7, 'Balanced', 0.5, 'Fast', 0.3);

pi_at = repmat(struct('Kp',0,'Ki',0,'name','','robustness',0, ...
    'crossover_freq_rad_s',0,'phase_margin_deg',0), numel(robustness_modes), 1);

for k = 1:numel(robustness_modes)
    mode = robustness_modes{k};
    r = robustness_map.(mode);
    opt = pidtuneOptions('PhaseMargin', 45 + (r-0.5)*30);   % 30°..60°
    [C, info] = pidtune(G, 'PI', opt);
    pi_at(k).Kp                   = C.Kp;
    pi_at(k).Ki                   = C.Ki;
    pi_at(k).name                 = ['pidtune_' mode];
    pi_at(k).robustness           = r;
    pi_at(k).crossover_freq_rad_s = info.CrossoverFrequency;
    pi_at(k).phase_margin_deg     = info.PhaseMargin;
    fprintf('pidtune %-9s: Kp=%.4f, Ki=%.4f, ω_c=%.1f rad/s, PM=%.1f°\n', ...
        mode, C.Kp, C.Ki, info.CrossoverFrequency, info.PhaseMargin);
end
end
