function slx_path = create_speed_loop_simulink(mp, controller, out_dir)
%% Aşama 2.1 — Hız kapalı döngü Simulink modeli (programatik)
%
% Yapı:
%   [Setpoint Step] → (+) → [PI Kontrolcü] → [Saturasyon ±0.5] → [Plant K/(τs+1)] → omega_out
%                       ↑                                                                ↓
%                       └────────────────────────────────────────────────────────────────┘
%
% Saturasyon = MOTOR_MAX_DUTY (±0.5) — firmware ile uyumlu.
%
% Aşama 2.2'de bu model anti-windup (back-calculation) eklenerek genişletilir.

mdl = 'speed_loop_a2_1';
slx_path = fullfile(out_dir, [mdl '.slx']);

if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
open_system(mdl);

% Blocks
add_block('simulink/Sources/Step',           [mdl '/setpoint']);
add_block('simulink/Math Operations/Sum',    [mdl '/sum_err']);
add_block('simulink/Continuous/PID Controller', [mdl '/PI']);
add_block('simulink/Discontinuities/Saturation',[mdl '/satr']);
add_block('simulink/Math Operations/Gain',   [mdl '/Vsupply']);
add_block('simulink/Math Operations/Bias',   [mdl '/Vsat_minus']);
add_block('simulink/Continuous/Transfer Fcn',[mdl '/Plant']);
add_block('simulink/Sinks/To Workspace',     [mdl '/omega_out']);
add_block('simulink/Sinks/Scope',            [mdl '/Scope']);

% Parametreler
set_param([mdl '/setpoint'], 'Time','0','Before','0','After','50','SampleTime','0');
set_param([mdl '/sum_err'],  'Inputs','+-');
set_param([mdl '/PI'], 'Controller','PI', 'P', num2str(controller.Kp), ...
                       'I', num2str(controller.Ki));
set_param([mdl '/satr'], 'UpperLimit','0.5', 'LowerLimit','-0.5');
set_param([mdl '/Vsupply'], 'Gain', num2str(mp.V_supply));
set_param([mdl '/Vsat_minus'], 'Bias', num2str(-mp.V_sat));
set_param([mdl '/Plant'], 'Numerator', sprintf('[%g]', mp.K_avg/mp.V_supply * mp.V_supply), ...
                          'Denominator', sprintf('[%g 1]', mp.tau_s));
set_param([mdl '/omega_out'], 'VariableName','omega_cl', 'SaveFormat','Timeseries');

% Konum
set_param([mdl '/setpoint'],    'Position',[50 90 100 130]);
set_param([mdl '/sum_err'],     'Position',[140 95 170 125]);
set_param([mdl '/PI'],          'Position',[200 80 270 140]);
set_param([mdl '/satr'],        'Position',[290 90 330 130]);
set_param([mdl '/Vsupply'],     'Position',[350 90 400 130]);
set_param([mdl '/Vsat_minus'],  'Position',[420 90 470 130]);
set_param([mdl '/Plant'],       'Position',[490 80 580 140]);
set_param([mdl '/omega_out'],   'Position',[620 70 680 110]);
set_param([mdl '/Scope'],       'Position',[620 130 680 170]);

% Bağlantılar
add_line(mdl, 'setpoint/1',   'sum_err/1');
add_line(mdl, 'sum_err/1',    'PI/1');
add_line(mdl, 'PI/1',         'satr/1');
add_line(mdl, 'satr/1',       'Vsupply/1');
add_line(mdl, 'Vsupply/1',    'Vsat_minus/1');
add_line(mdl, 'Vsat_minus/1', 'Plant/1');
add_line(mdl, 'Plant/1',      'omega_out/1');
add_line(mdl, 'Plant/1',      'Scope/1', 'autorouting','on');
add_line(mdl, 'Plant/1',      'sum_err/2', 'autorouting','on');   % feedback

set_param(mdl, 'StopTime', '0.5');

save_system(mdl, slx_path);
close_system(mdl, 0);

fprintf('Simulink kapalı döngü model kaydedildi: %s\n', slx_path);
end
