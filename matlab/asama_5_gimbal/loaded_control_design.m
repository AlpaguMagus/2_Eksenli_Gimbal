%% loaded_control_design.m  — Y1 yüklü kontrol tasarımı/doğrulama (analitik, motorsuz)
% ============================================================================
% Y0 modelinden (a=0.23, s+=0.059, s-=0.027, ω_n≈4, ζ≈0.1) yüklü kapalı-çevrim:
%   FF (computed-torque) gravite+sürtünmeyi plant-girişinde kaldırır → residual ≈ atalet;
%   mevcut cascade (Kp_pos, iç PI) bu residual'ı kontrol eder. Bu betik:
%   (1) FF gainlerini Y0'dan belirler, (2) yüklü NONLİNEER kapalı-çevrimi (firmware cascade +
%   FF) simüle edip STABİL + takip ediyor mu doğrular → Y2 bench güvenli mi.
% Kaynak: [Franklin2010] §6.4 (cascade), §7.5 (computed-torque FF), [Olsson1998] §6.
% ============================================================================
clear; clc;
set(groot,'defaultAxesColor','w','defaultAxesXColor','k', ...
          'defaultAxesYColor','k','defaultTextColor','k');

%% ---- Y0 modeli (duty-normalize) ----
a=0.23; sp=0.059; sn=0.027; wn=4.0; zeta=0.1;
p    = wn^2/a;          % K_m/J (çıkış rad/s² per duty) = 69.6
beta = 2*zeta*wn;       % b/J = 0.8

%% ---- FF gainleri (Y0'dan; firmware'e gidecek) ----
kff_grav = a;           % 0.23  (eski 0.21)
kff_coul = sp;          % 0.059 (eski 0.09)
kff_coul_rev = sn;      % 0.027 (eski 0.05)
fprintf('=== Y1 FF gainleri (Y0''dan) ===\n');
fprintf('  kff_grav=%.3f (eski 0.21) · kff_coul=%.3f (0.09) · kff_coul_rev=%.3f (0.05)\n', kff_grav,kff_coul,kff_coul_rev);

%% ---- Cascade (mevcut firmware LP) ----
Kp_pos=6.0; Kp=0.002; Ki=0.1; gear=9.7; dt=0.008; eps_db=0.34; umax=0.5;

%% ---- NONLİNEER kapalı-çevrim simülasyon ----
T=8; N=round(T/dt);
th=0; w=0; integ=0;
refdeg=@(t) 30*(t>=0.5) -55*(t>=3.0) +25*(t>=5.5);   % çıkış açı komutu (deg): +30 -> -25 -> 0
L=zeros(N,4);
for k=1:N
  t=k*dt;  thref=deg2rad(refdeg(t));
  wref = Kp_pos*(thref - th)*gear;  wref=max(min(wref,300),-300);   % dış P → motor rad/s
  wmot = gear*w;  err = wref - wmot;
  integ = integ + Ki*dt*err;  u_fb = Kp*err + integ;               % iç PI
  uc_ff = (wref>=0)*kff_coul + (wref<0)*kff_coul_rev;
  u_ff = kff_grav*sin(th) + uc_ff*tanh(wref/(gear*eps_db));         % FF (gravite + sürtünme)
  u = max(min(u_fb+u_ff,umax),-umax);
  % plant (çıkış): th'' = p(u - a sinθ - s·sat(w)) - β w
  fr = ((w>=0)*sp+(w<0)*sn)*tanh(w/eps_db);
  acc = p*(u - a*sin(th) - fr) - beta*w;
  w = w + acc*dt;  th = th + w*dt;
  L(k,:) = [t, rad2deg(th), refdeg(t), u];
end

%% ---- metrikler ----
% son 0.5 s oturma hatası her segment (komut değişiminden önce)
segend = [3.0, 5.5, 8.0];
fprintf('=== Kapalı-çevrim doğrulama (yüklü, mevcut cascade + Y1 FF) ===\n');
ok=true;
for te=segend
  idx = L(:,1)>te-0.5 & L(:,1)<=te;
  e = mean(L(idx,2)-L(idx,3));  rip = max(L(idx,2))-min(L(idx,2));
  fprintf('  t=%.1fs ref=%+5.1f° -> ulaştı %+6.1f° (ss-hata %+5.1f°, ripple %.1f°)\n', te, mean(L(idx,3)), mean(L(idx,2)), e, rip);
  if abs(e)>5 || rip>5, ok=false; end
end
umaxabs = max(abs(L(:,4)));
stable = all(abs(L(:,2))<120) && umaxabs<=umax+1e-6;
fprintf('  |duty|max=%.3f (limit %.2f) · stabil=%d · ss-hata<5°&ripple<5°=%d\n', umaxabs, umax, stable, ok);
verdict = (stable && ok);
if verdict, vtxt='STABİL+TAKİP (Y2 bench güvenli)'; else, vtxt='GÖZDEN GEÇİR'; end
fprintf('\n>>> YÜKLÜ KAPALI-ÇEVRİM: %s <<<\n', vtxt);

%% ---- figür ----
f=figure('Position',[100 100 980 380],'Color','w');
subplot(1,2,1);
  plot(L(:,1),L(:,3),'--','Color',[.5 .5 .5],'LineWidth',1.2); hold on;
  plot(L(:,1),L(:,2),'-','Color',[.1 .4 .7],'LineWidth',1.4); grid on;
  xlabel('t [s]'); ylabel('\theta_{out} [deg]'); title('Yüklü cascade+FF: pozisyon takip');
  legend({'komut','\theta_{out}'},'Location','best');
subplot(1,2,2);
  plot(L(:,1),L(:,4),'-','Color',[.7 .2 .2],'LineWidth',1.2); grid on; ylim([-0.55 0.55]);
  xlabel('t [s]'); ylabel('duty u'); title('Kontrol çabası (±0.5 clamp)');
outdir=fullfile('results','loaded_plant_id'); if ~exist(outdir,'dir'), mkdir(outdir); end
exportgraphics(f, fullfile(outdir,'loaded_closedloop_y1.png'),'Resolution',150);
fprintf('Fig: %s/loaded_closedloop_y1.png\n', outdir);
