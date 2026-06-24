%% Yüklü tek-eksen — sürtünme + gravite FEEDFORWARD tasarımı (computed-torque)
%
% NEDEN: Serbest-mil cascade kazançları (Aşama 2.5/2.7) YÜK altında limit-cycle
% veriyor (bench probe artifacts/3/cascade_m2/20260613_loaded_empty_probe: 20°/50°
% limit-cycle, 35° temiz). Kök neden YÜKLÜ ID ile ölçüldü
% (artifacts/3/loaded_id_m2/20260613_loaded_id_run1):
%     u = u_coulomb·sign(ω) + (mgL/K)·sin(θ)
%     stiction breakaway u_s = 0.107 duty,  Coulomb u_c = 0.090 duty,  gravite a = 0.097 duty
% Coulomb sürtünme (0.090) ≥ gravite katkısı → STICK-SLIP → limit-cycle.
%
% ÇÖZÜM (analitik, computed-torque feedforward [Franklin2010 §7.5; Olsson1998 §6]):
% Bilinen bozucuyu (gravite + Coulomb) plant-girişine (duty) PI'dan ÖNCE/PARALEL
% enjekte et → PI artık sürtünmeyi yenmek için integral biriktirmez → slip yok.
%     u_total = u_PI + u_ff(θ,ω_ref)
% 3 FF yapısı kıyaslanır (Sokratik karar verisi):
%   none                : FF yok (limit-cycle referansı — bench'i doğrula)
%   grav                : u_ff = a·sin(θ)                          (sürekli, chatter yok)
%   grav_coulomb_sign   : u_ff = a·sin(θ) + u_c·sign(ω_ref)        (baskın nedeni çözer; gürültüsüz
%                         simde ideal AMA setpoint'te ω_ref→0 işaret-chatter riski — firmware'de gyro/enc dither)
%   grav_coulomb_db     : u_ff = a·sin(θ) + u_c·sign(ω_ref)·[|err|>db]  (chatter-korumalı: setpoint
%                         ölü-bantında Coulomb FF kapalı → yapışık-stabil; yaklaşımda tam u_c → FIRMWARE TERCİHİ)
%
% Plant modeli: Aşama 2.6.5 verify_realistic_cascade.m'in Karnopp stick-slip'i
% + ÖLÇÜLEN yüklü gravite/Coulomb (serbest-milin küçük V_dead'i yerine).
% İç-döngü duty-domeni: ω_drive = K·Veff,  Veff = sign·max(|u|·Vs − Vsat, 0)  (Kg=K·Vs=654.8, H1).
%
% Referans:
%   [Franklin2010] §7.5  — feedforward / 2-DOF kontrol; bilinen bozucu telafisi
%   [Olsson1998]   §6    — Coulomb/stiction model-tabanlı sürtünme telafisi (feedforward)
%   [AstromMurray2008] §10 — sürtünmenin PID'de integral-windup / limit-cycle etkisi
%   Ölçüm: artifacts/3/loaded_id_m2/20260613_loaded_id_run1/meta.json

clear; close all; clc;
set(groot,'defaultAxesColor','w','defaultAxesXColor','k','defaultAxesYColor','k', ...
          'defaultTextColor','k','defaultFigureColor','w');   % ders-kitabı: beyaz zemin/siyah metin

% ── Motor + kontrol (Aşama 1 + 2.3, H1-düzeltilmiş duty-domeni) ──────────
P.K=53.89; P.tau=0.0605; P.GEAR=9.7; P.Vs=12.15; P.Vsat=0.5;
P.Kp_i=0.002; P.Ki_i=0.1; P.Kp_pos=2.00;
P.dt=0.007; P.T=5.0; P.OMEGA_Q=18.7; P.POS_Q=2*pi/466; P.MA=5;

% ── ÖLÇÜLEN yüklü plant (loaded_id_run1) ────────────────────────────────
P.a_grav   = 0.097;     % gravite a = mgL/K [duty] — yatay(90°) holding bileşeni
P.uc_coul  = 0.090;     % Coulomb (kinetik) sürtünme [duty]
P.us_break = 0.107;     % stiction breakaway (statik) [duty]
P.omega_stick = P.OMEGA_Q;     % stick hız-bandı (ölçülemeyen bölge, 1 kuantum)
P.err_db_deg  = 1.0;           % Coulomb-FF ölü-bantı (POS_Q=0.77°'nin biraz üstü → kuantum-içi uygulamaz)
P.wref_db = P.Kp_pos*deg2rad(P.err_db_deg)*P.GEAR;   % eşdeğer ω_ref eşiği (rad/s)

% ── Setpoint'ler: bench'in limit-cycle gördüğü açılar + temiz açı ───────
setpoints_deg = [20 35 50];
ff_modes = {'none','grav','grav_coulomb_sign','grav_coulomb_db'};
ff_label = {'FF yok','gravite','grav+Coulomb sign','grav+Coulomb+ölü-bant'};

fprintf('Yüklü cascade — feedforward karşılaştırması (ölçülen: u_c=%.3f, a=%.3f, u_s=%.3f duty)\n', ...
        P.uc_coul, P.a_grav, P.us_break);
fprintf('Kp_pos=%.1f, iç PI Kp=%.3f Ki=%.2f.  θ_std>1° → limit-cycle.\n\n', P.Kp_pos, P.Kp_i, P.Ki_i);

R = struct();
for si = 1:numel(setpoints_deg)
    P.theta_ref = deg2rad(setpoints_deg(si));
    fprintf('── θ_ref = %d° ──\n', setpoints_deg(si));
    fprintf('  %-22s %-10s %-10s %-12s %-s\n','FF yapısı','ss_err°','OS%','θ_std(°)','Sonuç');
    for mi = 1:numel(ff_modes)
        r = sim_cascade_loaded(P, ff_modes{mi});
        R(si,mi).r = r; R(si,mi).mode = ff_modes{mi}; R(si,mi).sp = setpoints_deg(si);
        v='STABİL'; if r.theta_std>1.0, v='⚠ LIMIT-CYCLE'; end
        fprintf('  %-22s %-10.2f %-10.1f %-12.2f %s\n', ff_label{mi}, r.ss_deg, r.OS, r.theta_std, v);
    end
    fprintf('\n');
end

% ════════════════════════════════════════════════════════════════════════
% PLOT 1 — 50° (en kötü) tüm FF yapıları θ takip
% ════════════════════════════════════════════════════════════════════════
si50 = find(setpoints_deg==50,1);
fig1=figure('Visible','off','Position',[40 40 1150 800],'Color','w');
cols = lines(numel(ff_modes));
subplot(2,1,1); hold on
for mi=1:numel(ff_modes)
    r=R(si50,mi).r;
    plot(r.t, rad2deg(r.theta), 'Color',cols(mi,:),'LineWidth',1.3, ...
         'DisplayName',sprintf('%s (\\theta_{std}=%.2f°)',ff_label{mi},r.theta_std));
end
yline(50,'k--','HandleVisibility','off'); grid on; ylabel('\theta_{out} (°)');
legend('Location','southeast'); title('Yüklü cascade \theta takip — \theta_{ref}=50° (FF yapı kıyası)');
subplot(2,1,2); hold on
for mi=1:numel(ff_modes)
    r=R(si50,mi).r; plot(r.t, r.u, 'Color',cols(mi,:),'LineWidth',1.0,'DisplayName',ff_label{mi});
end
grid on; ylabel('duty u_{total}'); xlabel('t (s)'); legend('Location','northeast');
title('Kontrol sinyali — FF chatter / stick-slip görünürlüğü');
sgtitle('Sürtünme+gravite feedforward: stick-slip limit-cycle bastırma');

out=fullfile(fileparts(mfilename('fullpath')),'results','loaded_ff');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig1, fullfile(out,'loaded_ff_compare_50deg.png'),'Resolution',150);

% ════════════════════════════════════════════════════════════════════════
% PLOT 2 — θ_std barları: FF yapı × setpoint (limit-cycle haritası)
% ════════════════════════════════════════════════════════════════════════
fig2=figure('Visible','off','Position',[40 40 950 520],'Color','w');
M = zeros(numel(setpoints_deg), numel(ff_modes));
for si=1:numel(setpoints_deg), for mi=1:numel(ff_modes), M(si,mi)=R(si,mi).r.theta_std; end, end
b=bar(M); grid on; set(gca,'XTickLabel',compose('%d°',setpoints_deg));
for mi=1:numel(ff_modes), b(mi).DisplayName=ff_label{mi}; end
yline(1.0,'r--','limit-cycle eşiği (1°)','LabelHorizontalAlignment','left','HandleVisibility','off');
ylabel('\theta_{std} (°) — limit-cycle göstergesi'); xlabel('setpoint');
legend('Location','northeast'); title('Feedforward yapısı × setpoint: limit-cycle bastırma haritası');
exportgraphics(fig2, fullfile(out,'loaded_ff_thetastd_map.png'),'Resolution',150);

fprintf('Çıktı: %s/{loaded_ff_compare_50deg, loaded_ff_thetastd_map}.png\n', out);

% ── Karar özeti (en iyi FF) ─────────────────────────────────────────────
mean_std = mean(M,1);   % FF yapısı başına ortalama θ_std
[~,best] = min(mean_std);
fprintf('\n── KARAR VERİSİ ──\n');
for mi=1:numel(ff_modes)
    fprintf('  %-22s ort. θ_std = %.3f°%s\n', ff_label{mi}, mean_std(mi), ...
            tern(mi==best,'   ← en iyi',''));
end
fprintf('\nÖneri: "%s" — ortalama θ_std %.3f° (FF-yok %.3f°''den %.1f× iyi).\n', ...
        ff_label{best}, mean_std(best), mean_std(1), mean_std(1)/max(mean_std(best),1e-3));

% ════════════════════════════════════════════════════════════════════════
function r = sim_cascade_loaded(P, ff_mode)
% Yüklü cascade: dış P → iç hız PI → duty (+ FF) → ÖLÇÜLEN yüklü plant (gravite+Coulomb stick-slip)
    N=round(P.T/P.dt); t=(0:N-1)*P.dt;
    om=0; th=0; ipi=0; oh=zeros(1,P.MA); ep=0; Tt=P.Kp_i/P.Ki_i;
    stuck=true;                                   % başta dipte yapışık
    lt=zeros(1,N); lo=zeros(1,N); lu=zeros(1,N); lf=zeros(1,N);
    for k=1:N
        % ── Dış döngü: pozisyon P (kuantize ölçüm) ──
        thm=round(th/P.POS_Q)*P.POS_Q;
        wref=P.Kp_pos*(P.theta_ref-thm)*P.GEAR;
        % ── İç döngü: hız PI (kuantize + MA ölçüm) ──
        oq=round(om/P.OMEGA_Q)*P.OMEGA_Q; oh=[oh(2:end) oq]; of=mean(oh);
        e=wref-of; ipi=ipi+P.Ki_i*P.dt/2*(e+ep);
        upi=P.Kp_i*e+ipi;
        % ── FEEDFORWARD (computed-torque, duty-domeni) ──
        uff = feedforward(P, ff_mode, thm, wref);
        uu = upi + uff;
        u=max(min(uu,0.5),-0.5);
        if Tt>0, ipi=ipi+(P.dt/Tt)*(u-uu); end   % anti-windup back-calc (FF dahil doyum)
        ep=e;
        % ── YÜKLÜ PLANT: net duty = uygulanan − gravite; Coulomb stick-slip ──
        u_net = u - P.a_grav*sin(th);             % gravite her zaman dipe çeker
        if stuck
            % statik: |u_net| breakaway'i aşana dek yapışık (gravite dahil net)
            if abs(u_net) > P.us_break
                stuck=false;                       % kopuş
            else
                om=0;                              % yapışık → hareket yok
            end
        end
        if ~stuck
            % kinetik Coulomb: hareket yönüne ters u_c kadar duty yenir
            u_drive = u_net - P.uc_coul*sign_nz(om, u_net);
            Veff=sign(u_drive)*max(abs(u_drive)*P.Vs-P.Vsat,0);
            omega_drive=P.K*Veff;
            om=om+P.dt/P.tau*(omega_drive-om);
            % düşük hızda + net duty breakaway altı → yeniden yapış (slip biter)
            if abs(om)<P.omega_stick && abs(u_net) < P.us_break
                om=0; stuck=true;
            end
        end
        th=th+(om/P.GEAR)*P.dt;
        lt(k)=th; lo(k)=om; lu(k)=u; lf(k)=uff;
    end
    r=metrics(P,t,lt,lo,lu); r.uff=lf;
end

function uff = feedforward(P, mode, thm, wref)
    switch mode
        case 'none',              uff = 0;
        case 'grav',              uff = P.a_grav*sin(thm);
        case 'grav_coulomb_sign', uff = P.a_grav*sin(thm) + P.uc_coul*sign(wref);
        case 'grav_coulomb_db'                                  % ölü-bant korumalı Coulomb
            uc_term = 0; if abs(wref) > P.wref_db, uc_term = P.uc_coul*sign(wref); end
            uff = P.a_grav*sin(thm) + uc_term;
        otherwise, error('bilinmeyen FF mode: %s', mode);
    end
end

function s = sign_nz(om, u_net)
% hareket yönü: ω≈0 ise net-duty yönünü kullan (kopuş anı), aksi halde ω yönü
    if abs(om) < 1e-6, s = sign(u_net); else, s = sign(om); end
end

function r = metrics(P,t,lt,lo,lu)
    N=numel(t); td=rad2deg(lt); ref=rad2deg(P.theta_ref);
    tail=td(round(0.6*N):end);
    r.ss_deg=abs(mean(tail)-ref);                 % mutlak derece hatası
    r.OS=max(0,(max(td)-ref)/ref*100);
    r.theta_std=std(tail);                        % limit-cycle göstergesi
    r.t=t; r.theta=lt; r.omega=lo; r.u=lu;
end

function s = tern(c,a,b), if c, s=a; else, s=b; end, end
