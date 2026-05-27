%% Aşama 2.5 — Pozisyon kontrol stratejisi taraması (gerçekçi sim)
%
% BULGU: verify_realistic_cascade.m'de cascade (Kp_pos=2.0) büyük salınım
% verdi (OS %31, hedefe oturmadı). Neden: iç hız döngüsü ω_ref ~0-10 rad/s
% aralığında çalışırken hız kuantizasyonu 18.7 rad/s → iç döngü kör + MA
% gecikmesi → dış döngü kararsız.
%
% Bu script iki ekseni gerçekçi koşullarda (aynı kuantizasyon katmanları)
% karşılaştırır:
%   (A) CASCADE: Kp_pos taraması {0.3, 0.5, 1.0, 2.0}
%   (B) DOĞRUDAN POZİSYON PD: u = Kp_θ·e_θ + Kd_θ·dθ/dt
%       (pozisyon ölçümü 0.773° çözünürlük → hız kuantizasyonundan bağımsız)
%
% Amaç: gerçek sistemde hangisi salınımsız, oturan, ss_error küçük.
%
% Referans: [Franklin2010] §6.4 (cascade), §4.3 (PD pozisyon), §8 (kuantizasyon)

clear; close all; clc;

% ── Ortak motor + gerçekçilik ─────────────────────────────────────
P.K=53.89; P.tau=0.0605; P.GEAR=9.7; P.Vs=12.15; P.Vsat=0.5;  % Aşama 1 (12V besleme!)
P.dt=0.007; P.T=4.0; P.OMEGA_Q=18.7; P.POS_Q=2*pi/466; P.MA=5;
P.theta_ref=deg2rad(30);
P.Kp_i=0.002; P.Ki_i=0.1;

% ══ (A) CASCADE taraması ══════════════════════════════════════════
kps = [0.3 0.5 1.0 2.0];
fprintf('═══ (A) CASCADE — pozisyon P × hız PI ═══\n');
fprintf('%-8s %-8s %-8s %-10s %-8s\n','Kp_pos','OS%','ss_err%','settle_s','u_std');
cascade_res = struct([]);
for j=1:numel(kps)
    r = sim_cascade(P, kps(j));
    cascade_res(j).kp=kps(j); cascade_res(j).r=r;
    fprintf('%-8.1f %-8.1f %-8.1f %-10s %-8.3f\n', kps(j), r.OS, r.ss, ...
        tern(isnan(r.settle),'—',sprintf('%.2f',r.settle)), r.ustd);
end

% ══ (B) DOĞRUDAN POZİSYON PD ══════════════════════════════════════
% Tasarım: 2. derece kapalı döngü hedef ω_n≈3 rad/s, ζ≈0.8
% Plant pozisyon: θ/u = K/(GEAR·s·(τs+1)). PD: u=Kp_θ·e+Kd_θ·ė
% Basit ayar: ω_n, ζ → Kp_θ, Kd_θ (motor 1.derece+entegratör yaklaşımı)
wn_d=3.0; zeta_d=0.8;
% θ_out/u ≈ K/(GEAR·τ·s²+GEAR·s) ; düşük frek: ~K/(GEAR·s) (entegratör)
% Pole placement (PD, plant ~ K/(GEAR·s(τs+1))):
Kp_th = wn_d^2 * P.GEAR * P.tau / P.K;
Kd_th = (2*zeta_d*wn_d*P.GEAR*P.tau - P.GEAR) / P.K;
if Kd_th<0, Kd_th=0; end
fprintf('\n═══ (B) DOĞRUDAN POZİSYON PD (ω_n=%.1f, ζ=%.1f) ═══\n', wn_d, zeta_d);
fprintf('  Kp_θ=%.3f, Kd_θ=%.4f\n', Kp_th, Kd_th);
rb = sim_direct_pd(P, Kp_th, Kd_th);
fprintf('  OS=%.1f%%, ss_err=%.1f%%, settle=%s, u_std=%.3f\n', rb.OS, rb.ss, ...
    tern(isnan(rb.settle),'—',sprintf('%.2f',rb.settle)), rb.ustd);

% ── Karşılaştırma plot ────────────────────────────────────────────
fig=figure('Visible','off','Position',[40 40 1200 700],'Color','w');
subplot(2,1,1); hold on
ref=rad2deg(P.theta_ref);
clr=lines(numel(kps));
for j=1:numel(kps)
    plot(cascade_res(j).r.t, rad2deg(cascade_res(j).r.theta), ...
        'LineWidth',1.3,'Color',clr(j,:),'DisplayName',sprintf('cascade Kp=%.1f',kps(j)));
end
yline(ref,'r--','HandleVisibility','off'); grid on
ylabel('\theta_{out} (°)'); legend('Location','southeast'); ylim([0 45]);
title('(A) Cascade — Kp_{pos} taraması (gerçekçi sim, hız kuant. 18.7 rad/s)');
subplot(2,1,2); hold on
plot(rb.t, rad2deg(rb.theta),'b','LineWidth',1.5,'DisplayName','doğrudan PD');
yline(ref,'r--','HandleVisibility','off'); yline(ref*1.02,'k:','HandleVisibility','off');
yline(ref*0.98,'k:','HandleVisibility','off'); grid on
ylabel('\theta_{out} (°)'); xlabel('t (s)'); legend('Location','southeast'); ylim([0 45]);
title(sprintf('(B) Doğrudan pozisyon PD — OS=%.1f%%, ss=%.1f%%, settle=%s', ...
    rb.OS, rb.ss, tern(isnan(rb.settle),'—',sprintf('%.2fs',rb.settle))));
sgtitle('Aşama 2.5 — Pozisyon stratejisi: cascade vs doğrudan PD (gerçekçi)');

out=fullfile(fileparts(mfilename('fullpath')),'results','2_5_strategy');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out,'position_strategy_sweep.png'),'Resolution',150);
fprintf('\nÇıktı: %s/position_strategy_sweep.png\n', out);

% ════════════════════════════════════════════════════════════════
function r = sim_cascade(P, Kp_pos)
    N=round(P.T/P.dt); t=(0:N-1)*P.dt;
    om=0; th=0; ipi=0; oh=zeros(1,P.MA); ep=0; Tt=P.Kp_i/P.Ki_i;
    lt=zeros(1,N); lu=zeros(1,N);
    for k=1:N
        thm=round(th/P.POS_Q)*P.POS_Q;
        e_th=P.theta_ref-thm;
        wref=Kp_pos*e_th*P.GEAR;
        oq=round(om/P.OMEGA_Q)*P.OMEGA_Q; oh=[oh(2:end) oq]; of=mean(oh);
        e=wref-of; ipi=ipi+P.Ki_i*P.dt/2*(e+ep);
        uu=P.Kp_i*e+ipi; u=max(min(uu,0.5),-0.5);
        if Tt>0, ipi=ipi+(P.dt/Tt)*(u-uu); end
        ep=e;
        Veff=sign(u)*max(abs(u)*P.Vs-P.Vsat,0);
        om=om+P.dt/P.tau*(P.K*Veff-om); th=th+(om/P.GEAR)*P.dt;
        lt(k)=th; lu(k)=u;
    end
    r=metrics(P,t,lt,lu);
end

function r = sim_direct_pd(P, Kp_th, Kd_th)
    N=round(P.T/P.dt); t=(0:N-1)*P.dt;
    om=0; th=0; thm_p=0; dh=zeros(1,P.MA);
    lt=zeros(1,N); lu=zeros(1,N);
    for k=1:N
        thm=round(th/P.POS_Q)*P.POS_Q;
        e_th=P.theta_ref-thm;
        dthm=(thm-thm_p)/P.dt; thm_p=thm;     % pozisyon türevi (kuantize ama entegre büyüklük → temiz)
        dh=[dh(2:end) dthm]; dthf=mean(dh);   % türev MA
        uu=Kp_th*e_th - Kd_th*dthf;           % PD (D ölçülen açıya, türev kick yok)
        u=max(min(uu,0.5),-0.5);
        Veff=sign(u)*max(abs(u)*P.Vs-P.Vsat,0);
        om=om+P.dt/P.tau*(P.K*Veff-om); th=th+(om/P.GEAR)*P.dt;
        lt(k)=th; lu(k)=u;
    end
    r=metrics(P,t,lt,lu);
end

function r = metrics(P,t,lt,lu)
    N=numel(t); td=rad2deg(lt); ref=rad2deg(P.theta_ref);
    tail=td(round(0.7*N):end);
    r.ss=abs(mean(tail)-ref)/ref*100;
    r.OS=max(0,(max(td)-ref)/ref*100);
    band=0.02*ref; r.settle=NaN;
    for k=1:N, if all(abs(td(k:end)-ref)<=band), r.settle=t(k); break; end, end
    r.ustd=std(lu(round(0.7*N):end));
    r.t=t; r.theta=lt;
end

function s=tern(c,a,b), if c, s=a; else, s=b; end, end
