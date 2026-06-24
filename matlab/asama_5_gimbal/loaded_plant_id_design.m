%% loaded_plant_id_design.m
% ============================================================================
% Aşama 5 — Yüklü gimbal NONLINEER plant RIGOROUS sistem-tanımlama (Y0)
%   TASARIM + ESTIMATOR DOĞRULAMA  (motorsuz / sentetik — bench'ten ÖNCE).
%
% AMAÇ: Yüklü LP plantını (yerçekimi-yüklü sarkaç + yön-asimetrik sürtünme) Aşama-1
%   rigoruyla, gravite ↔ sürtünme ↔ atalet'i TEMİZ AYIRARAK tanımlamak. Bu betik
%   ölçüm PROTOKOLÜNÜ + AYRIŞTIRMA MATEMATİĞİNİ türetir ve estimator'ı SENTETİK
%   veride (bilinen parametre → ölç-benzet → fit → geri-kurtar) doğrular. Gerçek
%   bench verisine güvenmeden ÖNCE aracın çalıştığı kanıtlanır ("analitik-önce").
%
% PLANT MODELİ (çıkış mili, θ = gravitasyonel-nötr başlangıç/dip'ten ölçülü):
%   J·θ'' + b·θ' + τ_c(yön)·sign(θ') + m g L·sin(θ) = K_m·u
%   θ=0 = asılı denge (dip) = nötr başlangıç (kullanıcı 2026-06-24).
%
% DUTY-NORMALİZE, KONTROL-HAZIR parametreler (K_m'ye böl):
%   a    = mgL/K_m   [duty]   gravite (θ=90° tutmak için gereken duty)
%   s+,s-= τ_s±/K_m  [duty]   STATİK sürtünme (kopma eşiği), yön-asimetrik (SÜRÜLEN kontrol)
%   cc               [duty]   coast/kinetik sürtünme (<< s; pasif ring-down'da)
%   ω_n              [rad/s]  doğal frekans ; ω_n² = mgL/J = a·p  (p=K_m/J)
%   ζ                         sönüm oranı
%   FF: gravite-FF=a·sinθ, sürtünme-FF=s·sign ; cascade: ω_n,ζ,p.
%
% AYRIŞTIRMA TÜRETİMİ — iki AYRI ölçüm rejimi (mevcut tek-açı ID'nin KAÇIRDIĞI):
%  (B1) STATİK denge bandı (sürülen):  u ∈ [a·sinθ − s−,  a·sinθ + s+]
%       yukarı-kopma u_up(θ)=a·sinθ+s+ ; aşağı-kopma u_dn(θ)=a·sinθ−s−
%       ÇOK-AÇIDA → midpoint=a·sinθ+(s+−s−)/2, halfgap=(s+ + s−)/2
%       LİNEER FİT midpoint vs sinθ: EĞİM=a, KESİŞİM=(s+−s−)/2 → a,s+,s− TEMİZ AYRILIR.
%  (B2) DİNAMİK ω_n,ζ: yüklüde SÜRÜLEN-step Coulomb yüzünden OSİLE ETMEZ (sistematik
%       ID "overshoot YOK") → ω_n/ζ PASİF FREE-DECAY ring-down'dan (motor OFF), coast
%       sürtünmesi düşük → salınır; ω_n frekanstan (sürtünme büyüklüğünden bağımsız).
%
% Kaynak: [Ljung1999] §3-4-16 (ID+validasyon), [Olsson1998] §6 (sürtünme ayrıştırma),
%   [Franklin2010] §3 (2.mertebe), [Khalil2002] §1 (sarkaç nonlineeritesi).
% ============================================================================
clear; clc;
set(groot,'defaultAxesColor','w','defaultAxesXColor','k', ...
          'defaultAxesYColor','k','defaultTextColor','k');
rng(7);   % tekrarlanabilir sentetik gürültü

%% ---- 1) GERÇEK (sentetik) parametreler — sistematik-ID ön-değerlerine yakın ----
T.a    = 0.21;          % gravite [duty]
T.sp   = 0.10;          % statik sürtünme + yön [duty]
T.sn   = 0.05;          % statik sürtünme - yön [duty]
T.cc   = 0.008;         % coast/kinetik sürtünme [duty] (<< s; ring-down'da)
T.wn   = 4.0;           % doğal frekans [rad/s] (free-decay ile uyumlu)
T.zeta = 0.12;          % sönüm
T.p    = T.wn^2 / T.a;  % p = K_m/J  (ω_n² = a·p)

%% ---- 2) BÖLÜM-1: gravite haritası + statik sürtünme (çok-açılı kopma) ----
theta_k = (-50:10:50) * pi/180;     % ±50° (±90 kablo-güvenli içinde)
theta_k(theta_k==0) = [];           % dip'te gravite 0 → ayrıştırma bilgisi yok, atla
u_up =  T.a*sin(theta_k) + T.sp;    % yukarı-kopma (model)
u_dn =  T.a*sin(theta_k) - T.sn;    % aşağı-kopma

% --- ölçüm bozulması: encoder kuant (466 cnt/rev) + duty ölçüm gürültüsü ---
dpc_rad = (360/466) * pi/180;                       % encoder çözünürlüğü [rad]
qa = @(th) round(th./dpc_rad).*dpc_rad;             % açı kuantizasyonu
sig_u = 0.003;                                      % duty ölçüm gürültüsü σ
u_up_m = u_up + sig_u*randn(size(u_up));
u_dn_m = u_dn + sig_u*randn(size(u_dn));
th_m   = qa(theta_k);

% --- ESTIMATOR: lineer ayrıştırma (midpoint vs sinθ) ---
mid = (u_up_m + u_dn_m)/2;
hg  = (u_up_m - u_dn_m)/2;
P   = polyfit(sin(th_m), mid, 1);        % mid = a·sinθ + δ
a_hat   = P(1);
delta   = P(2);
hg_mean = mean(hg);
sp_hat  = hg_mean + delta;
sn_hat  = hg_mean - delta;
midfit  = polyval(P, sin(th_m));
R2_grav = 1 - sum((mid-midfit).^2)/sum((mid-mean(mid)).^2);

fprintf('=== BÖLÜM-1: gravite/statik-sürtünme AYRIŞTIRMA ===\n');
fprintf('  a   gerçek %.3f  tahmin %.3f  (hata %+.1f%%)   R²=%.4f\n', T.a, a_hat, 100*(a_hat-T.a)/T.a, R2_grav);
fprintf('  s+  gerçek %.3f  tahmin %.3f  (hata %+.1f%%)\n', T.sp, sp_hat, 100*(sp_hat-T.sp)/T.sp);
fprintf('  s-  gerçek %.3f  tahmin %.3f  (hata %+.1f%%)\n', T.sn, sn_hat, 100*(sn_hat-T.sn)/T.sn);

%% ---- 3) BÖLÜM-2: dinamik (ω_n, ζ) — FREE-DECAY (pasif coast, motor OFF) ----
odef = @(t,x,u,pp,cc) [ x(2);
    pp.p*( u - pp.a*sin(x(1)) - cc.*tanh(x(2)/0.34) ) - 2*pp.zeta*pp.wn*x(2) ];
th0 = 45*pi/180;                                  % bırakma açısı
[Ts,Xs] = ode45(@(t,x) odef(t,x,0,T,T.cc), [0 8], [th0;0]);
th_s = Xs(:,1);
[pk, ip] = local_peaks(th_s);                     % pozitif tepeler (ring-down, dip≈0)
if numel(pk) >= 3
    A = pk(:);  good = A > 1*pi/180;  A = A(good); ip = ip(good);
    % ⚠ Coulomb coast-sürtünmesi log-decrement'i ŞİŞİRİR → zeta_hat saf-viskoz DEĞİL,
    %   "efektif sönüm" (üst-sınır). Kontrol için muhafazakâr (daha çok sönüm varsayımı =
    %   güvenli). Saf viskoz için: ring-down zarfı Coulomb'da LİNEER, viskozda ÜSTEL → ikisini
    %   ayrı fit (gelecek rafine). ω_n frekanstan → sürtünmeden bağımsız, güvenilir.
    dlog = mean( log(A(1:end-1)./A(2:end)) );
    zeta_hat = dlog/sqrt(4*pi^2 + dlog^2);
    Td  = mean(diff(Ts(ip)));
    wd  = 2*pi/Td;
    wn_hat = wd/sqrt(1 - zeta_hat^2);
else
    zeta_hat = NaN; wn_hat = NaN;
end
p_hat = wn_hat^2 / a_hat;                          % K_m/J = ω_n²/a
fprintf('=== BÖLÜM-2: dinamik (free-decay ring-down) ===\n');
fprintf('  ω_n gerçek %.2f  tahmin %.2f rad/s (hata %+.1f%%)   tepe=%d\n', T.wn, wn_hat, 100*(wn_hat-T.wn)/T.wn, numel(pk));
fprintf('  ζ   gerçek %.3f  tahmin %.3f\n', T.zeta, zeta_hat);

%% ---- 4) VALİDASYON: tam nonlineer model, held-out duty profilde NRMSE ----
H.a=a_hat; H.sp=sp_hat; H.sn=sn_hat; H.wn=wn_hat; H.zeta=zeta_hat; H.p=p_hat;
% held-out duty profili (kopma ÜSTÜ → hareket eder; sabit, rastgele değil)
uprof  = @(t) 0.16.*(t>0.3) - 0.13.*(t>1.8) + 0.20.*(t>3.2);
fdrive = @(w,pp) ((w>=0)*pp.sp + (w<0)*pp.sn).*tanh(w/0.34);    % sürülen (statik≈kinetik)
odv    = @(t,x,u,pp) [ x(2); pp.p*( u - pp.a*sin(x(1)) - fdrive(x(2),pp) ) - 2*pp.zeta*pp.wn*x(2) ];
[Tv,Xv]  = ode45(@(t,x) odv(t,x,uprof(t),T), [0 4.5], [0;0]);   % "ölçüm" (gerçek param)
meas = qa(Xv(:,1));                                             % kuantize ölçüm
[~,Xh]   = ode45(@(t,x) odv(t,x,uprof(t),H), Tv, [0;0]);        % model (tahmin param)
err   = meas - Xh(:,1);
nrmse = 100*sqrt(mean(err.^2)) / (max(meas)-min(meas));
fprintf('=== VALİDASYON ===\n  NRMSE (held-out): %.2f%%  (hedef <15%%, Aşama-1 ~11%%)\n', nrmse);

%% ---- 5) HÜKÜM ----
PASS = (abs(a_hat-T.a)/T.a < 0.10) && ~isnan(wn_hat) && (abs(wn_hat-T.wn)/T.wn < 0.10) && (nrmse < 15);
if PASS, verdict='PASS — estimator bilinen parametreleri geri kurtardı, bench''e hazır';
else,    verdict='FAIL — protokol/estimator gözden geçir'; end
fprintf('\n>>> ESTIMATOR DOĞRULAMA: %s <<<\n', verdict);

%% ---- 6) FİGÜR (kanıt) ----
f = figure('Position',[100 100 980 380],'Color','w');
subplot(1,2,1);
  ths = linspace(-55,55,100)*pi/180;
  plot(sin(theta_k), u_up_m,'^','MarkerFaceColor',[.85 .2 .2],'MarkerEdgeColor','k'); hold on;
  plot(sin(theta_k), u_dn_m,'v','MarkerFaceColor',[.2 .35 .8],'MarkerEdgeColor','k');
  plot(sin(theta_k), mid,'ko','MarkerFaceColor','w');
  plot(sin(ths), a_hat*sin(ths)+delta,'k-','LineWidth',1.4);
  grid on; xlabel('sin(\theta)'); ylabel('kopma duty [u]');
  title(sprintf('B1: gravite/sürtünme ayrıştırma  (a=%.3f, R^2=%.4f)',a_hat,R2_grav));
  legend({'yukarı-kopma','aşağı-kopma','midpoint','fit a\cdotsin\theta+\delta'},'Location','SouthEast');
subplot(1,2,2);
  plot(Ts, th_s*180/pi,'-','Color',[.1 .5 .2],'LineWidth',1.3); grid on;
  xlabel('t [s]'); ylabel('\theta [deg]');
  title(sprintf('B2: free-decay ring-down (\\omega_n=%.2f, \\zeta=%.3f)',wn_hat,zeta_hat));
outdir = fullfile('results','loaded_plant_id');   % CWD = betik klasörü (MCP)
if ~exist(outdir,'dir'), mkdir(outdir); end
exportgraphics(f, fullfile(outdir,'estimator_synthetic_verify.png'), 'Resolution',150);
fprintf('Fig: %s/estimator_synthetic_verify.png\n', outdir);

%% ---- yerel fonksiyon ----
function [pks,locs] = local_peaks(y)
  pks=[]; locs=[];
  for i = 2:numel(y)-1
    if y(i) > y(i-1) && y(i) >= y(i+1)
      pks(end+1)=y(i); locs(end+1)=i; %#ok<AGROW>
    end
  end
end
