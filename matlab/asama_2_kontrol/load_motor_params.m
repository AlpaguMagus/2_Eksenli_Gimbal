function mp = load_motor_params(test_id)
%% Aşama 1 motor parametrelerini yükle
%
% Aşama 1 pipeline'ının ürettiği motor_params.json'dan
% K, τ, V_dead, V_supply, V_sat değerlerini okur.
%
% Girdi:
%   test_id — Aşama 1 test_id (default: en son üretilen)
%
% Çıktı: mp struct
%   .K_avg, .tau_s, .V_dead_avg, .V_supply, .V_sat
%   .K_cw, .K_ccw, .symmetry_pct
%   .source (path)

if nargin < 1 || isempty(test_id)
    test_id = '20260518_011926';   % en son Aşama 1 koşusu (default)
end

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
src = fullfile(root, 'matlab', 'asama_1_model', 'results', test_id, 'motor_params.json');
if ~isfile(src)
    error('motor_params.json bulunamadı: %s\nAşama 1 pipeline çalıştırılmadı mı?', src);
end

raw = jsondecode(fileread(src));
mp.K_cw         = raw.K_cw;
mp.K_ccw        = raw.K_ccw;
mp.K_avg        = (raw.K_cw + raw.K_ccw) / 2;
mp.tau_s        = raw.tau_median_s;
mp.V_dead_avg   = (abs(raw.V_dead_pos_V) + abs(raw.V_dead_neg_V)) / 2;
mp.V_supply     = raw.V_supply_V;
mp.V_sat        = raw.V_sat_V;
mp.symmetry_pct = raw.symmetry_pct;
mp.source       = src;
mp.asama1_test_id = test_id;

fprintf('Aşama 1 motor parametreleri yüklendi (test_id=%s):\n', test_id);
fprintf('  K_avg = %.3f rad/s/V (CW %.3f, CCW %.3f, simetri %%%.2f)\n', ...
    mp.K_avg, mp.K_cw, mp.K_ccw, mp.symmetry_pct);
fprintf('  τ     = %.4f s = %.1f ms\n', mp.tau_s, mp.tau_s*1000);
fprintf('  V_dead (avg) = %.3f V (ihmal edilebilir)\n', mp.V_dead_avg);
end
