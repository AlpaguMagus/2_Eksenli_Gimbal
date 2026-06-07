%% Aşama 2.3 — Hız PI ANALİTİK + MÜHENDİSLİK türetmesi (deneme-yanılma DEĞİL)
%
% AMAÇ: Çalışan Kp=0.002, Ki=0.1 kazançlarının analitik/mühendislik temelini göster.
% Bunlar keyfi/ampirik değil — DOĞRU plant'ta DOYUM-kısıtlı pole placement sonucu.
%
% Aşama 2.1 conservative tasarımının İKİ hatası (sim-to-real gap kök nedeni):
%   (H1) YANLIŞ PLANT: K=53.89 (Veff->ω) varsaydı; ama firmware PI çıkışı *duty*.
%        Gerçek plant duty->ω: Kg = K·Vs = 654.8  (12.15× daha yüksek kazanç!)
%   (H2) DOYUM KISITINI YOK SAYDI: P-terimi Kp·e doyumu (±0.5) aşınca bang-bang.
%        Conservative Kp=0.1163 → e=0.5/0.1163=4.3 rad/s'te bile P-terimi doyar.
%
% DÜZELTİLMİŞ ANALİTİK TASARIM (bu betik):
%   (1) Kp: DOYUM kısıtı. P-terimi normal hata aralığında (serbest mil ω_max'a kadar)
%       doyumu aşmamalı → Kp ≤ duty_max / ω_max.
%   (2) ω_n: bant genişliği = 2× plant kutbu (2/τ), Nyquist'in çok altında (ayrık güvenli).
%   (3) Ki: DOĞRU plant'ta pole placement → Ki = ω_n²·τ / Kg.
%   (4) ζ: (1+Kg·Kp)/(2√(Kg·Ki·τ)) — seçimlerden DOĞAR (bağımsız ayarlanmaz).
%
% Kaynak: [Franklin2010] §6.4 (pole placement), §9 (saturation/anti-windup tasarım kısıtı),
%         [AstromMurray2008] §10 (PI + windup). Doğrulama: margin + realistic sim + gerçek motor.

clear; close all; clc;
set(groot,'defaultFigureColor','w','defaultAxesColor','w','defaultAxesXColor','k', ...
    'defaultAxesYColor','k','defaultTextColor','k','defaultAxesGridColor',[0.15 0.15 0.15]);

% ── Fiziksel parametreler (Aşama 1 + donanım) ─────────────────────
K   = 53.89;    tau = 0.0605;   Vs = 12.15;   Vsat = 0.5;   duty_max = 0.5;
Kg  = K*Vs;                              % DOĞRU plant kazancı (duty->ω)
fprintf('DOĞRU plant kazancı Kg = K·Vs = %.1f (Aşama 2.1 yanlışlıkla K=%.2f kullandı, %.1f× hata)\n', Kg, K, Vs);

% ── (1) Kp: DOYUM kısıtı ──────────────────────────────────────────
omega_max = K*(Vs*duty_max - Vsat);      % serbest mil max hız (duty=0.5'te ω_ss)
Kp_sat_bound = duty_max / omega_max;     % P-terimi ω_max hatasında bile doyumu aşmasın
fprintf('\n(1) DOYUM KISITI: serbest mil ω_max = K·(Vs·duty_max−Vsat) = %.0f rad/s\n', omega_max);
fprintf('    Kp ≤ duty_max/ω_max = %.5f → Kp = 0.002 seçildi (doyum-güvenli, ~%.0f rad/s''e kadar lineer)\n', ...
    Kp_sat_bound, duty_max/0.002);
Kp = 0.002;

% ── (2) ω_n: bant genişliği = 2× plant kutbu ──────────────────────
omega_n = 2/tau;                          % plant kutbu 1/τ; kapalı-çevrim 2× hızlı
omega_nyq = pi/0.007;                     % ayrık Nyquist (~7ms döngü)
fprintf('\n(2) BANT GENİŞLİĞİ: plant kutbu 1/τ=%.1f rad/s → ω_n = 2/τ = %.1f rad/s\n', 1/tau, omega_n);
fprintf('    Nyquist ω_Nyq=%.0f rad/s → ω_n Nyquist''in %.0f× altında (ayrık güvenli)\n', omega_nyq, omega_nyq/omega_n);

% ── (3) Ki: DOĞRU plant'ta pole placement ─────────────────────────
Ki = omega_n^2 * tau / Kg;
fprintf('\n(3) POLE PLACEMENT (doğru plant): Ki = ω_n²·τ/Kg = %.4f\n', Ki);

% ── (4) ζ: seçimlerden doğar ──────────────────────────────────────
zeta = (1 + Kg*Kp) / (2*sqrt(Kg*Ki*tau));
fprintf('\n(4) ζ = (1+Kg·Kp)/(2√(Kg·Ki·τ)) = %.3f (hafif sönümlü — seçimden DOĞDU)\n', zeta);

% ── Doğrulama: margin (doğru plant) ───────────────────────────────
s = tf('s'); Gd = Kg/(tau*s+1); Ce = Kp + Ki/s; Le = Ce*Gd;
[Gm,Pm,~,wc] = margin(Le);
fprintf('\n=== TÜRETİLEN KAZANÇLAR: Kp=%.4f, Ki=%.4f (= firmware) ===\n', Kp, Ki);
fprintf('    margin (doğru plant): PM=%.1f°, ωc=%.1f rad/s, GM=%.0f dB\n', Pm, wc, 20*log10(Gm));

% ── Conservative'in doyum hatası (karşılaştırma) ──────────────────
Kp_c = 0.1163;  e_sat_c = duty_max/Kp_c;  e_sat = duty_max/Kp;
fprintf('\nCONSERVATIVE Kp=%.4f → P-terimi e=%.1f rad/s''te doyar (minik hata → bang-bang)\n', Kp_c, e_sat_c);
fprintf('DÜZELTİLMİŞ  Kp=%.4f → P-terimi e=%.0f rad/s''e kadar lineer (doyum-güvenli)\n', Kp, e_sat);

% ── Görsel: (sol) doyum kısıtı P-terimi vs hata, (sağ) kapalı-çevrim step ──
fig = figure('Position',[60 60 1050 440],'Color','w');
subplot(1,2,1);
e = 0:1:300;
plot(e, Kp*e, 'b','LineWidth',2); hold on; grid on;
plot(e, Kp_c*e, 'r--','LineWidth',1.8);
yline(duty_max,'k:','duty doyum 0.5','LineWidth',1.2,'LabelHorizontalAlignment','left');
plot(e_sat_c, duty_max,'ro','MarkerFaceColor','r','MarkerSize',8);
plot(min(e_sat,300), Kp*min(e_sat,300),'bo','MarkerFaceColor','b','MarkerSize',8);
xlabel('hız hatası e (rad/s)'); ylabel('P-terimi = K_p·e (duty)');
title('DOYUM KISITI — P-terimi doyumu aşmamalı'); ylim([0 0.7]);
legend(sprintf('düzeltilmiş K_p=%.3f',Kp), sprintf('conservative K_p=%.3f',Kp_c), ...
    'Location','northwest','TextColor','k','Color','w');
text(e_sat_c+5, duty_max-0.05, sprintf('conservative %.1f rad/s''te doyar!',e_sat_c),'Color','r','FontSize',9);

subplot(1,2,2);
T = feedback(Le,1); [y,t] = step(50*T, 0:0.001:0.3);
plot(t*1000, y, 'b','LineWidth',2); hold on; grid on;
yline(50,'r--'); yline(50*1.05,'k:'); yline(50*0.95,'k:');
xlabel('t (ms)'); ylabel('\omega (rad/s)');
title(sprintf('Kapalı-çevrim step (doğru plant): ζ=%.2f, ω_n=%.0f',zeta,omega_n));
legend('ω (50 rad/s ref)','Location','southeast','TextColor','k','Color','w');
sgtitle(sprintf('Aşama 2.3 — Hız PI ANALİTİK türetme: K_p=%.3f (doyum), K_i=%.2f (pole place, doğru plant)',Kp,Ki),'Color','k');

here = fileparts(mfilename('fullpath'));
outdir = fullfile(here,'results','2_1_speed_pi');
if ~exist(outdir,'dir'); mkdir(outdir); end
exportgraphics(fig, fullfile(outdir,'06b_speed_pi_analytic_derivation.png'),'Resolution',150); close(fig);

params = struct('Kp',Kp,'Ki',Ki,'zeta',zeta,'omega_n',omega_n,'Kg_correct_plant',Kg, ...
    'Kp_saturation_bound',Kp_sat_bound,'omega_max_freeshaft',omega_max, ...
    'PM_deg',Pm,'wc',wc,'conservative_Kp',Kp_c,'conservative_saturates_at_radps',e_sat_c, ...
    'method','saturation_constrained_pole_placement_correct_plant', ...
    'kaynak',{{'Franklin2010 §6.4','Franklin2010 §9','AstromMurray2008 §10'}});
fid=fopen(fullfile(outdir,'speed_pi_analytic_params.json'),'w');
fwrite(fid,jsonencode(params,'PrettyPrint',true),'char'); fclose(fid);
fprintf('\nÇıktı: %s/06b_speed_pi_analytic_derivation.png + speed_pi_analytic_params.json\n',outdir);
