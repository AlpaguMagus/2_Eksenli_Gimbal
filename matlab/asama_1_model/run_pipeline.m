%% Aşama 1 — Tek motor sistem tanımlama pipeline
% Çağrı:
%   >> test_id = '20260518_141520';  % artifacts/1/step_response/<test_id>/
%   >> run_pipeline
%
% Adımlar:
%   1. Veri yükle (artifacts/1/step_response/<test_id>/raw/data.csv.gz)
%   2. Step bazlı 1. derece fit (tfest + lsqcurvefit, Soru 1 önerisi C)
%   3. Dead-band tespit (ω_ss vs V_eff, x-intercept = V_dead) — TODO 1.3
%   4. CW/CCW simetri analizi — TODO 1.4
%   5. Sonuçları matlab/asama_1_model/results/<test_id>/ altına kaydet
%
% Referanslar:
%   [Ljung1999] §3, §16
%   [Franklin2010] §3
%   [TB6612_DS] §1 (V_sat)

if ~exist('test_id', 'var') || isempty(test_id)
    error('test_id workspace değişkenini önceden tanımla (örn. ''20260518_141520'')');
end

fprintf('=== Aşama 1 pipeline — test_id: %s ===\n', test_id);

% 1. Yükle
data = load_step_data(test_id);

% 2. Fit (ikisi de)
fit_results = fit_first_order(data, 'both');

% Step özet tablosu
fprintf('\nStep özetleri:\n');
fprintf('%4s | %4s | %+8s | %10s | %10s | %12s | %s\n', ...
    'idx', 'yön', 'duty', 'ω_ss', 'τ (ms)', 'K_est', 'method');
fprintf('-----+------+----------+------------+------------+--------------+----------\n');
for i = 1:numel(fit_results)
    fr = fit_results(i);
    if isempty(fr.tau_s) || isnan(fr.tau_s)
        tau_ms_s = '   N/A';
    else
        tau_ms_s = sprintf('%8.1f', fr.tau_s * 1000);
    end
    fprintf('%4d | %4s | %+8.3f | %+10.2f | %s | %12.3f | %s\n', ...
        i, fr.yon, fr.duty_cmd, fr.omega_ss, tau_ms_s, fr.K_estimate, fr.method);
end

% 3-4. TODO: dead-band tespit + CW/CCW simetri (alt-aşama 1.3 + 1.4)
fprintf('\nTODO 1.3: dead-band tespit (V_dead) — sonraki alt-aşama\n');
fprintf('TODO 1.4: CW/CCW simetri analizi — sonraki alt-aşama\n');

% 5. Kaydet
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results', test_id);
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
save(fullfile(results_dir, 'fit_results.mat'), 'fit_results', 'data');
fprintf('\nKaydedildi: %s\n', results_dir);
