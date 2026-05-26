%% Aşama 2.5 — Doğrudan pozisyon PID (cascade alternatifi, gerçekçi sim)
%
% BULGU (sweep_position_strategy.m): cascade gerçekçi simde salınıyor —
% iç hız döngüsü ω_ref~0-10 rad/s'de çalışırken hız kuant. 18.7 rad/s → kör.
%
% ALTERNATİF: doğrudan pozisyon PID. Pozisyon ölçümü 0.773° çözünürlük
% (hız kuant.'dan 24× daha ince) → kuantizasyon problemi yok. İntegral terim
% dead-band'i yener (P/PD yenemez). Türev MA ile yumuşatılır.
%
% Plant (u→θ_out): G_p = K·V_s/(GEAR·s·(τ·s+1))
%   K·V_s/GEAR = 53.89·5/9.7 = 27.78  → θ_out/u = 27.78/(s(0.0605s+1))
%
% Tasarım: pidtune, hedef bandgenişliği ω_c ≈ 3 rad/s (gerçek sistemde
% kuantizasyon + dead-band ile uyumlu, agresif olmayan).
%
% Referans: [Franklin2010] §4.3 (PID pozisyon), §6.1 (pole/bandwidth), §8 (kuant.)

clear; close all; clc;

% ── Parametreler ──────────────────────────────────────────────────
P.K=53.89; P.tau=0.0605; P.GEAR=9.7; P.Vs=12.15; P.Vsat=0.5;  % Aşama 1 (12V besleme!)
P.dt=0.007; P.T=4.0; P.OMEGA_Q=18.7; P.POS_Q=2*pi/466; P.MA=5;
P.theta_ref=deg2rad(30);

% ── Plant + pidtune ───────────────────────────────────────────────
Kp_plant = P.K*P.Vs/P.GEAR;                 % 27.78 (duty→açısal kazanç)
Gp = tf(Kp_plant, [P.tau 1 0]);             % 27.78/(s(τs+1))
wc = 3.0;                                    % hedef bandgenişliği rad/s
opts = pidtuneOptions('PhaseMargin', 65);    % sağlam faz payı
C = pidtune(Gp, 'PIDF', wc, opts);
[Gm,Pm,~,~] = margin(C*Gp);
Tcl = feedback(C*Gp, 1);
info = stepinfo(Tcl);

fprintf('Doğrudan pozisyon PID (pidtune, ω_c=%.1f, PM hedef 65°):\n', wc);
fprintf('  Kp=%.4f, Ki=%.4f, Kd=%.4f, Tf=%.4f\n', C.Kp, C.Ki, C.Kd, C.Tf);
fprintf('  PM=%.1f°, GM=%.1f dB\n', Pm, 20*log10(Gm));
fprintf('  İDEAL step: settle=%.2fs, OS=%.1f%%\n', info.SettlingTime, info.Overshoot);

% ── Gerçekçi sim (kuantizasyon + dead-band + saturation) ──────────
r = sim_pid_realistic(P, C.Kp, C.Ki, C.Kd, C.Tf);
fprintf('\n  GERÇEKÇİ sim: settle=%s, OS=%.1f%%, ss_err=%.2f%%, u_std(ss)=%.3f → %s\n', ...
    tern(isnan(r.settle),'—',sprintf('%.2fs',r.settle)), r.OS, r.ss, r.ustd, ...
    tern(r.ustd>0.15,'⚠ LIMIT-CYCLE','STABİL'));

% ── Plot ──────────────────────────────────────────────────────────
fig=figure('Visible','off','Position',[40 40 1100 700],'Color','w'); ref=rad2deg(P.theta_ref);
subplot(2,1,1);
plot(r.t, rad2deg(r.theta),'b','LineWidth',1.5); hold on
yline(ref,'r--'); yline(ref*1.02,'k:'); yline(ref*0.98,'k:'); grid on
ylabel('\theta_{out} (°)');
title(sprintf('Doğrudan pozisyon PID — gerçekçi sim (OS=%.1f%%, ss=%.1f%%, settle=%s)', ...
    r.OS, r.ss, tern(isnan(r.settle),'—',sprintf('%.2fs',r.settle))));
subplot(2,1,2);
plot(r.t, r.u,'k','LineWidth',1.0); grid on; ylim([-0.55 0.55]);
ylabel('duty u'); xlabel('t (s)');
title(sprintf('Kontrol sinyali (ss u\\_std=%.3f → %s)', r.ustd, ...
    tern(r.ustd>0.15,'LIMIT-CYCLE','STABİL')));
sgtitle('Aşama 2.5 — Doğrudan pozisyon PID (cascade alternatifi)');
out=fullfile(fileparts(mfilename('fullpath')),'results','2_5_strategy');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out,'position_direct_pid.png'),'Resolution',150);

% ── JSON ──────────────────────────────────────────────────────────
params=struct('strategy','direct_position_PID','Kp',C.Kp,'Ki',C.Ki,'Kd',C.Kd,'Tf',C.Tf, ...
    'wc_rad_s',wc,'PM_deg',Pm,'GM_dB',20*log10(Gm), ...
    'sim_OS_pct',r.OS,'sim_ss_err_pct',r.ss,'sim_settle_s',r.settle,'sim_ustd',r.ustd, ...
    'unit','u=duty, theta=cikis mili rad', ...
    'note','dogrudan pozisyon PID; integral dead-band yener; pozisyon kuant 0.773deg ince', ...
    'kaynak',{{'Franklin2010 §4.3','Franklin2010 §8'}});
fid=fopen(fullfile(out,'position_direct_pid_params.json'),'w');
fwrite(fid,jsonencode(params,'PrettyPrint',true),'char'); fclose(fid);
fprintf('\nÇıktılar: %s/ (position_direct_pid.png + .json)\n', out);

% ════════════════════════════════════════════════════════════════
function r = sim_pid_realistic(P, Kp, Ki, Kd, Tf)
    N=round(P.T/P.dt); t=(0:N-1)*P.dt;
    om=0; th=0; thm_p=0; ig=0; df=0; Tt=(Ki>0)*tern(Ki>0,Kp/max(Ki,1e-9),0);
    lt=zeros(1,N); lu=zeros(1,N);
    for k=1:N
        thm=round(th/P.POS_Q)*P.POS_Q;        % pozisyon ölçümü (kuantize, ince)
        e=P.theta_ref-thm;
        % türev (ölçülen açıya, filtreli — türev kick yok)
        draw=(thm-thm_p)/P.dt; thm_p=thm;
        a=P.dt/(Tf+P.dt); df=df+a*(draw-df);  % 1.derece türev filtresi (Tf)
        ig=ig+Ki*P.dt*e;                       % integral (geriye Euler)
        uu=Kp*e+ig-Kd*df;
        u=max(min(uu,0.5),-0.5);
        if Tt>0, ig=ig+(P.dt/Tt)*(u-uu); end   % anti-windup back-calc
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
    r.t=t; r.theta=lt; r.u=lu;
end

function s=tern(c,a,b), if c, s=a; else, s=b; end, end
