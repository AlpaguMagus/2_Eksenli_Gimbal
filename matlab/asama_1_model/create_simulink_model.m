function slx_path = create_simulink_model(motor_params, out_dir)
%% Aşama 1.5 — Simulink modelini programatik oluştur
%
% Aşama 1'in akademik çıktısı: hocaya/jüriye gösterilebilir Simulink
% blok diyagramı. Birinci derece transfer fonksiyonu + step input + scope.
%
% Yapı:
%   [Step Input] → [duty × V_supply − V_sat] → [Plant G(s) = K/(τs+1)] → [Out]
%
% Çıktı: out_dir/motor_model_asama1.slx
%
% Bu model Aşama 2'de (kontrolcü tasarımı) genişletilir (PI bloğu eklenir).

K_avg = mean([motor_params.K_cw, motor_params.K_ccw]);
tau   = motor_params.tau_median_s;
V_SUP = motor_params.V_supply_V;
V_SAT = motor_params.V_sat_V;

mdl_name = 'motor_model_asama1';
slx_path = fullfile(out_dir, [mdl_name '.slx']);

% Aynı isimde model varsa kapat
if bdIsLoaded(mdl_name)
    close_system(mdl_name, 0);
end

new_system(mdl_name);
open_system(mdl_name);

% Blocks
add_block('simulink/Sources/Step',           [mdl_name '/duty_step']);
add_block('simulink/Math Operations/Gain',   [mdl_name '/Vsupply']);
add_block('simulink/Math Operations/Bias',   [mdl_name '/Vsat']);
add_block('simulink/Continuous/Transfer Fcn',[mdl_name '/Plant']);
add_block('simulink/Sinks/To Workspace',     [mdl_name '/omega_out']);
add_block('simulink/Sinks/Scope',            [mdl_name '/Scope']);

% Block parametreleri
set_param([mdl_name '/duty_step'], 'Time', '0', 'Before', '0', 'After', '0.30', ...
    'SampleTime', '0');
set_param([mdl_name '/Vsupply'], 'Gain', num2str(V_SUP));
set_param([mdl_name '/Vsat'],    'Bias', num2str(-V_SAT));
set_param([mdl_name '/Plant'],   'Numerator', sprintf('[%g]', K_avg), ...
                                 'Denominator', sprintf('[%g 1]', tau));
set_param([mdl_name '/omega_out'], 'VariableName', 'omega_sim', ...
    'SaveFormat', 'Timeseries');

% Konumlar (görsel düzen)
set_param([mdl_name '/duty_step'], 'Position', [50  50  90  90]);
set_param([mdl_name '/Vsupply'],   'Position', [150 50  200 90]);
set_param([mdl_name '/Vsat'],      'Position', [250 50  300 90]);
set_param([mdl_name '/Plant'],     'Position', [350 50  430 90]);
set_param([mdl_name '/omega_out'], 'Position', [480 30  540 70]);
set_param([mdl_name '/Scope'],     'Position', [480 90  540 130]);

% Bağlantılar
add_line(mdl_name, 'duty_step/1', 'Vsupply/1');
add_line(mdl_name, 'Vsupply/1',   'Vsat/1');
add_line(mdl_name, 'Vsat/1',      'Plant/1');
add_line(mdl_name, 'Plant/1',     'omega_out/1');
add_line(mdl_name, 'Plant/1',     'Scope/1', 'autorouting', 'on');

% Simülasyon konfigürasyonu
set_param(mdl_name, 'StopTime', '5');

save_system(mdl_name, slx_path);
close_system(mdl_name, 0);

fprintf('Simulink model kaydedildi: %s\n', slx_path);
end
