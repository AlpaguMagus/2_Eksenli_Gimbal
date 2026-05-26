%% Aşama 2.6.5 — Pozisyon cascade Simulink blok diyagramı (programatik)
%
% Resmi cascade kontrol blok diyagramı — tez/sunum görseli + ideal step yanıtı.
%
% Yapı (iki iç içe döngü):
%   [θ_ref] → (+) → [Kp_pos] → (+) → [PI] → [Sat±0.5] → [×Vs] → [−Vsat] → [Plant K/(τs+1)] → ω
%              ↑pos fb          ↑hız fb                                                        │
%              │                └──────────────────────────────────────────────────────────────┤
%              │                                                                    ω ↓
%              └──────────────────────── [Integrator 1/s] ← θ ←───────────────────────┘
%
% İç döngü = Aşama 2.1 hız PI (speed_loop_a2_1.slx ile aynı), dış döngü pozisyon P.
% Bu IDEAL lineer model (kontrolcü mimarisini gösterir). Gerçekçi sim — kuantizasyon
% + sürtünme — ayrık-zaman script'te: verify_realistic_cascade.m.
%
% Doğrulama: ideal step yanıtı design_position_p.m ile uyumlu olmalı
%   (OS ~%0.6, settling ~1.15 s).
%
% Referans: [Franklin2010] §6.4 (cascade mimarisi)

clear; close all; clc;

% ── Parametreler (Aşama 1 + 2.3 + design_position_p) ──────────────
K=53.89; tau=0.0605; Vs=12.15; Vsat=0.5;
Kp_i=0.002; Ki_i=0.1; Kp_pos=2.00;
theta_ref_deg=30;

mdl='cascade_pos_a2_5';
out=fullfile(fileparts(mfilename('fullpath')),'results');
if ~exist(out,'dir'), mkdir(out); end
slx=fullfile(out,[mdl '.slx']);

if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl);

% ── Bloklar ───────────────────────────────────────────────────────
add_block('simulink/Sources/Step',              [mdl '/theta_ref']);
add_block('simulink/Math Operations/Sum',       [mdl '/sum_pos']);
add_block('simulink/Math Operations/Gain',      [mdl '/Kp_pos']);
add_block('simulink/Math Operations/Sum',       [mdl '/sum_spd']);
add_block('simulink/Continuous/PID Controller', [mdl '/PI_hiz']);
add_block('simulink/Discontinuities/Saturation',[mdl '/sat']);
add_block('simulink/Math Operations/Gain',      [mdl '/Vsupply']);
add_block('simulink/Math Operations/Bias',      [mdl '/Vsat']);
add_block('simulink/Continuous/Transfer Fcn',   [mdl '/Plant']);
add_block('simulink/Continuous/Integrator',     [mdl '/Integrator']);
add_block('simulink/Sinks/To Workspace',        [mdl '/theta_out']);
add_block('simulink/Sinks/To Workspace',        [mdl '/omega_out']);

% ── Parametreler ──────────────────────────────────────────────────
set_param([mdl '/theta_ref'],'Time','0','Before','0','After',num2str(deg2rad(theta_ref_deg)),'SampleTime','0');
set_param([mdl '/sum_pos'],'Inputs','+-');
set_param([mdl '/Kp_pos'],'Gain',num2str(Kp_pos));
set_param([mdl '/sum_spd'],'Inputs','+-');
set_param([mdl '/PI_hiz'],'Controller','PI','P',num2str(Kp_i),'I',num2str(Ki_i));
set_param([mdl '/sat'],'UpperLimit','0.5','LowerLimit','-0.5');
set_param([mdl '/Vsupply'],'Gain',num2str(Vs));
set_param([mdl '/Vsat'],'Bias',num2str(-Vsat));
set_param([mdl '/Plant'],'Numerator',sprintf('[%g]',K),'Denominator',sprintf('[%g 1]',tau));
set_param([mdl '/theta_out'],'VariableName','theta_cl','SaveFormat','Timeseries');
set_param([mdl '/omega_out'],'VariableName','omega_cl','SaveFormat','Timeseries');

% ── Konum (blok diyagram düzeni) ──────────────────────────────────
set_param([mdl '/theta_ref'], 'Position',[30  140 70  180]);
set_param([mdl '/sum_pos'],   'Position',[110 145 140 175]);
set_param([mdl '/Kp_pos'],    'Position',[170 145 210 175]);
set_param([mdl '/sum_spd'],   'Position',[250 145 280 175]);
set_param([mdl '/PI_hiz'],    'Position',[310 130 370 190]);
set_param([mdl '/sat'],       'Position',[400 140 440 180]);
set_param([mdl '/Vsupply'],   'Position',[460 145 500 175]);
set_param([mdl '/Vsat'],      'Position',[520 145 560 175]);
set_param([mdl '/Plant'],     'Position',[580 130 670 190]);
set_param([mdl '/Integrator'],'Position',[710 130 750 190]);
set_param([mdl '/theta_out'], 'Position',[800 130 860 170]);
set_param([mdl '/omega_out'], 'Position',[710 240 770 280]);

% ── Bağlantılar ───────────────────────────────────────────────────
add_line(mdl,'theta_ref/1','sum_pos/1');
add_line(mdl,'sum_pos/1',  'Kp_pos/1');
add_line(mdl,'Kp_pos/1',   'sum_spd/1');
add_line(mdl,'sum_spd/1',  'PI_hiz/1');
add_line(mdl,'PI_hiz/1',   'sat/1');
add_line(mdl,'sat/1',      'Vsupply/1');
add_line(mdl,'Vsupply/1',  'Vsat/1');
add_line(mdl,'Vsat/1',     'Plant/1');
add_line(mdl,'Plant/1',    'Integrator/1');
add_line(mdl,'Integrator/1','theta_out/1');
% Hız iç döngü feedback (Plant çıkışı ω → sum_spd)
add_line(mdl,'Plant/1',    'sum_spd/2','autorouting','on');
add_line(mdl,'Plant/1',    'omega_out/1','autorouting','on');
% Pozisyon dış döngü feedback (θ → sum_pos)
add_line(mdl,'Integrator/1','sum_pos/2','autorouting','on');

set_param(mdl,'StopTime','5','Solver','ode45');
save_system(mdl,slx);

% ── Blok diyagram görselini export et (tez şekli) ─────────────────
try
    print(['-s' mdl], '-dpng', '-r150', fullfile(out,'cascade_block_diagram.png'));
    fprintf('Blok diyagram: %s/cascade_block_diagram.png\n', out);
catch ME
    fprintf('Blok diyagram export atlandı (%s)\n', ME.message);
end

% ── Simülasyon + step yanıtı ──────────────────────────────────────
so=sim(mdl,'StopTime','5');
th=so.theta_cl.Data*180/pi; t=so.theta_cl.Time;
ref=theta_ref_deg;
ss_err=abs(th(end)-ref)/ref*100;
OS=max(0,(max(th)-ref)/ref*100);
% settling ±%2
band=0.02*ref; settle=NaN;
for i=1:numel(t), if all(abs(th(i:end)-ref)<=band), settle=t(i); break; end, end

fig=figure('Visible','off','Position',[50 50 800 400],'Color','w');
plot(t,th,'b','LineWidth',1.6); hold on
yline(ref,'r--'); yline(ref*1.02,'k:'); yline(ref*0.98,'k:'); grid on
xlabel('t (s)'); ylabel('\theta_{out} (°)');
title(sprintf('Cascade Simulink ideal step — OS=%.1f%%, settling=%.2fs, ss\\_err=%.2f%%', OS, settle, ss_err));
exportgraphics(fig, fullfile(out,'cascade_simulink_step.png'),'Resolution',150);

fprintf('\nCascade Simulink (ideal lineer):\n');
fprintf('  θ_ref=%d°, Kp_pos=%.1f, iç PI=%.3f/%.1f\n', theta_ref_deg, Kp_pos, Kp_i, Ki_i);
fprintf('  OS=%.1f%%, settling=%.2fs, ss_err=%.2f%%\n', OS, settle, ss_err);
fprintf('  (design_position_p.m doğrulama: OS~%%0.6, settling~1.15s bekleniyor)\n');
fprintf('  Model: %s\n  Step yanıtı: %s/cascade_simulink_step.png\n', slx, out);

close_system(mdl,0);
