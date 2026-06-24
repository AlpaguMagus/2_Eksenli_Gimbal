%% loaded_plant_id_fit.m
% ============================================================================
% Y0 — GERÇEK bench verisinden yüklü plant fit (B1 histerezis → a, s+, s−).
% Estimator loaded_plant_id_design.m'de SENTETİK doğrulandı (PASS); burada gerçek
% plantid.csv'ye uygulanır. AÇI = θ_out (encoder, çıkış mili = yük gravite-pendulumu);
% FP (IMU base'de = yasa-demosu) plant'a girmez.
% Ayrıştırma: u_asc=a·sinθ+s+ (yukarı dal), u_desc=a·sinθ−s− (aşağı dal) → birleşik LS.
% Kaynak: [Olsson1998] §6, [Ljung1999] §3.
% ============================================================================
clear; clc;
set(groot,'defaultAxesColor','w','defaultAxesXColor','k', ...
          'defaultAxesYColor','k','defaultTextColor','k');

csv = '/home/alpagumagus/workspace/2_Eksenli_Gimbal/artifacts/5/loaded_plant_id/20260624_085025/raw/plantid.csv';
T = readtable(csv);
B1 = T(strcmp(string(T.phase),"B1"), :);
t = B1.t; duty = B1.duty; thr = deg2rad(B1.th_rel);

% --- açı hızı (smooth → stick-slip gürültüsünü yumuşat) ---
ths = movmean(thr, 25);
dth = gradient(ths) ./ gradient(t);
vmin = 0.03;                          % rad/s — "hareketli" eşiği (stuck noktaları dışla)
asc  = dth >  vmin;
desc = dth < -vmin;
sel  = asc | desc;

% --- birleşik en-küçük-kareler: u = a·sinθ + s+·I_asc − s−·I_desc ---
X  = sin(thr(sel));
us = duty(sel);
ia = asc(sel); id = desc(sel);
M  = [X, double(ia), double(id)];     % [sinθ, I_asc, I_desc]
coef = M \ us;                        % [a, s+, -s-]
a_hat = coef(1); sp_hat = coef(2); sn_hat = -coef(3);
resid = us - M*coef;
R2 = 1 - sum(resid.^2)/sum((us-mean(us)).^2);

fprintf('=== Y0 GERÇEK plant fit (B1 histerezis, θ_out) ===\n');
fprintf('  Örnek: B1 %d (hareketli %d: asc %d / desc %d)\n', height(B1), nnz(sel), nnz(asc), nnz(desc));
fprintf('  a  (gravite)     = %.3f duty   [firmware default 0.21]\n', a_hat);
fprintf('  s+ (statik sürt) = %.3f duty   [firmware kff_coul 0.09]\n', sp_hat);
fprintf('  s- (statik sürt) = %.3f duty   [firmware kff_coul_rev 0.05]\n', sn_hat);
fprintf('  asimetri s+/s-   = %.2f\n', sp_hat/max(sn_hat,1e-3));
fprintf('  fit R²           = %.4f\n', R2);
% θ=90° tutmak için gereken duty (= a); kopma duty θ=0'da = s
fprintf('  → θ=90° tutma duty ≈ %.2f ; θ=0 kopma + %.2f / − %.2f\n', a_hat, sp_hat, sn_hat);

%% ---- figür ----
f = figure('Position',[100 100 980 380],'Color','w');
subplot(1,2,1);
  xs = linspace(min(X)-0.05, max(X)+0.05, 50);
  plot(sin(thr(asc)), duty(asc),'.','Color',[.85 .2 .2],'MarkerSize',6); hold on;
  plot(sin(thr(desc)),duty(desc),'.','Color',[.2 .35 .8],'MarkerSize',6);
  plot(xs, a_hat*xs + sp_hat,'-','Color',[.6 0 0],'LineWidth',1.5);
  plot(xs, a_hat*xs - sn_hat,'-','Color',[0 0 .6],'LineWidth',1.5);
  grid on; xlabel('sin(\theta_{rel})  [\theta_{out}, dip-relatif]'); ylabel('duty u');
  title(sprintf('B1 histerezis fit:  a=%.3f, s+=%.3f, s-=%.3f  (R^2=%.3f)',a_hat,sp_hat,sn_hat,R2));
  legend({'yukarı dal','aşağı dal','a\cdotsin\theta+s_+','a\cdotsin\theta-s_-'},'Location','SouthEast');
subplot(1,2,2);
  yyaxis left;  plot(t, duty,'-','LineWidth',1.1); ylabel('duty');
  yyaxis right; plot(t, rad2deg(thr),'-','LineWidth',1.1); ylabel('\theta_{rel} [deg]');
  grid on; xlabel('t [s]'); title('B1 üçgen-rampa: duty & \theta_{out}');
outdir = fullfile('results','loaded_plant_id'); if ~exist(outdir,'dir'), mkdir(outdir); end
exportgraphics(f, fullfile(outdir,'real_fit_085025.png'), 'Resolution',150);
fprintf('Fig: %s/real_fit_085025.png\n', outdir);
