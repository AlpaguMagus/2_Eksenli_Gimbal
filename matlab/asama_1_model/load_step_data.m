function data = load_step_data(test_id)
%% Aşama 1 — Step response veri yükleyici
%
% artifacts/1/step_response/<test_id>/raw/data.csv.gz dosyasını okur,
% step bazlı segmentlere ayırır, MATLAB struct döndürür.
%
% Girdi:
%   test_id (char) — örn. '20260518_141520'
%
% Çıktı:
%   data.steps         — N×1 struct array, her elemanın alanları:
%       .step_idx      — 1-based
%       .phase         — 'drive' | 'coast'
%       .duty_cmd      — float, signed
%       .t_s           — örnekleme zamanı (sn, step başlangıcından)
%       .omega         — motor şaftı rad/s
%       .ec            — encoder count (int32)
%   data.meta          — meta.json içeriği (struct)
%   data.test_id, data.commit
%
% Referans:
%   [Ljung1999] §3 — iddata formatı (output-error model için sonraki adım)
%   CLAUDE.md — artifacts/ klasör yapısı, gzip eşiği 50 KB

if nargin < 1 || isempty(test_id)
    error('test_id zorunlu — örn. load_step_data(''20260518_141520'')');
end

% Proje kök dizinine göre yol
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
base = fullfile(root, 'artifacts', '1', 'step_response', test_id);
raw_gz = fullfile(base, 'raw', 'data.csv.gz');
raw_csv = fullfile(base, 'raw', 'data.csv');
meta_json = fullfile(base, 'meta.json');

% Gzip çöz (varsa)
if isfile(raw_gz) && ~isfile(raw_csv)
    gunzip(raw_gz, fullfile(base, 'raw'));
end
if ~isfile(raw_csv)
    error('Ham veri bulunamadı: %s', raw_csv);
end

% CSV oku
T = readtable(raw_csv);

% meta.json yükle (varsa)
data.meta = struct();
if isfile(meta_json)
    data.meta = jsondecode(fileread(meta_json));
end
data.test_id = test_id;
if isfield(data.meta, 'commit')
    data.commit = data.meta.commit;
else
    data.commit = 'UNKNOWN';
end

% Step bazlı segmentasyon — step_idx + phase'e göre grupla
keys = strcat(string(T.phase), '__', string(T.step_idx));
[unique_keys, ~, idx] = unique(keys, 'stable');
n = numel(unique_keys);

data.steps = repmat(struct( ...
    'step_idx', [], 'phase', '', 'duty_cmd', [], ...
    't_s', [], 'omega', [], 'ec', []), n, 1);

for i = 1:n
    mask = (idx == i);
    sub = T(mask, :);
    if isempty(sub)
        continue
    end
    t_us = double(sub.t_us_fw);
    % T_US wrap koruması: monotonic olmayan fark varsa 2^32 ekle
    dt_us = [0; diff(t_us)];
    dt_us(dt_us < 0) = dt_us(dt_us < 0) + 2^32;
    t_s = cumsum(dt_us) * 1e-6;

    data.steps(i).step_idx = sub.step_idx(1);
    data.steps(i).phase    = char(sub.phase(1));
    data.steps(i).duty_cmd = sub.duty_cmd(1);
    data.steps(i).t_s      = t_s;
    data.steps(i).omega    = sub.omega;
    data.steps(i).ec       = sub.ec;
end

fprintf('Yüklenen step sayısı: %d (commit=%s)\n', n, data.commit);
end
