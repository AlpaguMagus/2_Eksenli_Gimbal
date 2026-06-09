%% §11.11.8 açık konu — AYRIK-ZAMAN + MA margin doğrulaması (C1+C2 caveat)
%
% Caveat (docs §11.11.8): sürekli-zaman PM=60.2° iki gerçek etkiyi İÇERMİYOR:
%   (C2) WINDOW=5 moving-average ölçüm filtresinin faz gecikmesi
%   (C1) PI Tustin SABIT Ts=5ms kullanır ama döngü ~7ms (efektif Ki ölçeği)
% Bu betik TAM AYRIK loop'ta margin'i hesaplar → caveat'ı resmi sayıyla kapatır.
%
% Yöntem ([Franklin2010] §6 margin; ayrık c2d ZOH):
%   Plant ZOH @ T_loop, firmware Tustin PI (Ts=5ms, T_loop-rate'te), 5-tap MA FIR.
%   margin() ayrık TF'in faz payını z-domain'de (örnekleme dahil) hesaplar.

clear; close all; clc;
set(groot,'defaultFigureColor','w','defaultAxesColor','w','defaultAxesXColor','k', ...
    'defaultAxesYColor','k','defaultTextColor','k','defaultAxesGridColor',[0.15 0.15 0.15]);

% ── Sürekli loop (mevcut 60.2° analizi, design_speed_margin_empirical.m ile aynı) ──
K=53.89; tau=0.0605; Vs=12.15; Kp=0.002; Ki=0.1;
s=tf('s'); Gd=(K*Vs)/(tau*s+1); Ce=Kp+Ki/s; Le=Ce*Gd;
[~,PM_c,~,wc_c]=margin(Le);

% ── Ayrık loop parametreleri ──────────────────────────────────────
Tloop=0.007;   % gerçek ana döngü ~7ms (~140Hz, docs asama_0 §5.4) — MA + ZOH bu hızda
Ts=0.005;      % PI Tustin SABIT adımı (firmware; C1 latent kuplaj kaynağı)
N=5;           % WINDOW=5 moving-average ölçüm filtresi

z=tf('z',Tloop);
Gd_d = c2d(Gd, Tloop, 'zoh');                  % ZOH plant @ T_loop
Ce_d = Kp + Ki*(Ts/2)*(z+1)/(z-1);             % firmware Tustin PI: 1/s→Ts/2·(z+1)/(z-1), Ts=5ms
H_MA = (1 + z^-1 + z^-2 + z^-3 + z^-4)/N;       % 5-tap MA (ölçüm/geri-besleme yolu)

Le_d0 = Ce_d*Gd_d;          % ayrık, MA YOK (ZOH + C1 etkisi)
Le_d  = Ce_d*Gd_d*H_MA;     % ayrık, MA DAHİL (tam loop)

[~,PM_d0,~,wc_d0]=margin(Le_d0);
[~,PM_d ,~,wc_d ]=margin(Le_d);

% ── MA grup gecikmesi (analitik kontrol) ──────────────────────────
tau_g=(N-1)/2*Tloop;                  % 14 ms (lineer-faz FIR)
phase_loss_anal = wc_c*tau_g*180/pi;  % wc_c'de MA faz kaybı (deg) — analitik beklenti

fprintf('=== §11.11.8 — Ayrık-zaman + MA margin doğrulaması ===\n');
fprintf('Sürekli (MA yok)       : PM=%.1f deg, wc=%.1f rad/s\n',PM_c,wc_c);
fprintf('Ayrık, MA yok (ZOH+C1) : PM=%.1f deg, wc=%.1f rad/s\n',PM_d0,wc_d0);
fprintf('Ayrık, MA dahil (TAM)  : PM=%.1f deg, wc=%.1f rad/s\n',PM_d,wc_d);
fprintf('MA grup gecikmesi=%.0f ms -> wc_c''de ~%.1f deg faz kaybi (analitik)\n',tau_g*1000,phase_loss_anal);
fprintf('-> Caveat ~33 deg iddiasi: TAM ayrik PM=%.1f deg (spec >=45 marjinal alti, kararli)\n',PM_d);

% ── Plot: Bode — sürekli vs tam-ayrık ─────────────────────────────
w=logspace(-1, log10(pi/Tloop), 600);
[mc,pc]=bode(Le,w);  mc=squeeze(mc); pc=squeeze(pc);
[md,pd]=bode(Le_d,w);md=squeeze(md); pd=squeeze(pd);

f=figure('Position',[60 60 900 640],'Color','w');
subplot(2,1,1);
semilogx(w,20*log10(mc),'b','LineWidth',1.8); hold on; grid on;
semilogx(w,20*log10(md),'r','LineWidth',1.8);
yline(0,'k:'); xline(wc_c,'b--','HandleVisibility','off'); xline(wc_d,'r--','HandleVisibility','off');
ylabel('Gain [dB]');
title('Test 2.T1 ek — Speed PI margin: continuous vs full discrete (ZOH + PI + MA)','FontWeight','bold');
lg=legend(sprintf('continuous (no MA): PM=%.0f^\\circ',PM_c), ...
          sprintf('full discrete (+ZOH +MA): PM=%.0f^\\circ',PM_d), ...
          'Location','southwest'); set(lg,'Color','w','TextColor','k');

subplot(2,1,2);
semilogx(w,pc,'b','LineWidth',1.8); hold on; grid on;
semilogx(w,pd,'r','LineWidth',1.8);
yline(-180,'k:'); xline(wc_c,'b--','HandleVisibility','off'); xline(wc_d,'r--','HandleVisibility','off');
ylabel('Phase [deg]'); xlabel('frequency \omega [rad/s]');
text(0.12,-60,sprintf('MA group delay (N-1)/2\\cdotT_{loop}=%.0f ms',tau_g*1000),'Color','r','FontSize',9);
text(0.12,-90,sprintf('\\omega_c: %.1f\\rightarrow%.1f rad/s, PM: %.0f^\\circ\\rightarrow%.0f^\\circ',wc_c,wc_d,PM_c,PM_d),'Color','k','FontSize',9);
sgtitle('§11.11.8 — Ayrik-zaman + moving-average faz payi (C1+C2 caveat dogrulama)','Color','k');

here=fileparts(mfilename('fullpath'));
outdir=fullfile(here,'results','2_1_speed_pi');
if ~exist(outdir,'dir'); mkdir(outdir); end
exportgraphics(f,fullfile(outdir,'06_margin_discrete_ma.png'),'Resolution',150); close(f);

params=struct('PM_continuous_deg',PM_c,'wc_continuous',wc_c, ...
  'PM_discrete_noMA_deg',PM_d0,'wc_discrete_noMA',wc_d0, ...
  'PM_discrete_withMA_deg',PM_d,'wc_discrete_withMA',wc_d, ...
  'Tloop_s',Tloop,'Ts_pi_s',Ts,'N_window',N,'MA_group_delay_ms',tau_g*1000, ...
  'phase_loss_anal_deg',phase_loss_anal,'spec_PM_deg',45, ...
  'kaynak',{{'Franklin2010 §6','AstromMurray2008 §10'}});
fid=fopen(fullfile(outdir,'margin_discrete_ma.json'),'w');
fwrite(fid,jsonencode(params,'PrettyPrint',true),'char'); fclose(fid);
fprintf('Cikti: %s/06_margin_discrete_ma.png + margin_discrete_ma.json\n',outdir);
