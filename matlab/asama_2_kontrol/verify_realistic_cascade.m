%% Aşama 2.6.5 — Gerçekçi cascade sim: SÜRTÜNMESİZ vs SÜRTÜNMELİ
%
% NEDEN: Aşama 2.5'te gerçekçi sim (sürtünmesiz) limit-cycle öngördü, ama
% gerçek motor temiz oturdu (Test 2.5 PASS). Hipotez: gerçek motorun STATİK
% SÜRTÜNMESİ, düşük-hız kuantizasyon gezinmesini söndürüyor.
%
% Bu script hipotezi DOĞRULAR: aynı cascade'i (a) sürtünmesiz (b) Coulomb/
% stiction sürtünmeli simüle eder. Sürtünmeli sim gerçek motorla uyumlu
% (limit-cycle yok) çıkmalı → sim-to-real gap kapanır.
%
% SÜRTÜNME MODELİ (Karnopp benzeri, minimal):
%   - Stick bandı: |ω| < ω_stick içinde, sürücü statik sürtünmeyi yenemezse
%     (|K·V_eff| < ω_coulomb) motor YAPIŞIR (ω=0). Aksi halde hareket.
%   - Coulomb eşiği Aşama 1 dead-band'inden: ω_coulomb = K·V_dead
%     (V_dead≈0.24V — yüksek hızda ihmal edilebilir AMA mikro-düzeltmede belirleyici)
%   - Kinetik sürtünme (viskoz) zaten 1. derece modelin τ,K'sında gömülü
%
% Referans: [Franklin2010] §6.4 (cascade), §8 (kuantizasyon),
%           [Olsson1998] Coulomb+stiction sürtünme modelleri (LuGre ailesi minimal hali)

clear; close all; clc;

% ── Motor + kontrol (Aşama 1 + 2.3) ───────────────────────────────
P.K=53.89; P.tau=0.0605; P.GEAR=9.7; P.Vs=12.15; P.Vsat=0.5;
P.Kp_i=0.002; P.Ki_i=0.1; P.Kp_pos=2.00;
P.dt=0.007; P.T=4.0; P.OMEGA_Q=18.7; P.POS_Q=2*pi/466; P.MA=5;
P.theta_ref=deg2rad(30);
% Sürtünme parametreleri (Aşama 1 V_dead'den)
P.V_dead=0.24;                       % Aşama 1 motor_params.json (ort |V_dead|)
P.omega_coulomb=P.K*P.V_dead;        % Coulomb hız-eşdeğeri ≈ 12.9 rad/s
P.omega_stick=P.OMEGA_Q;             % stick bandı = 1 kuantum (ölçülemeyen bölge)

% ── İki senaryo ───────────────────────────────────────────────────
r_nofric = sim_cascade(P, false);    % sürtünmesiz (Aşama 2.5 gerçekçi sim)
r_fric   = sim_cascade(P, true);     % Coulomb/stiction sürtünmeli

fprintf('Cascade gerçekçi sim — sürtünme karşılaştırması (Kp_pos=%.1f):\n', P.Kp_pos);
fprintf('  θ_ref = 30° (çıkış mili), Coulomb eşiği ω_c=%.1f rad/s\n', P.omega_coulomb);
fprintf('\n  %-14s %-10s %-10s %-12s %-s\n','Senaryo','ss_err%','OS%','θ_std(°)','Sonuç');
print_row('SÜRTÜNMESİZ', r_nofric);
print_row('SÜRTÜNMELİ',  r_fric);
fprintf('\n  Yorum: Sürtünmeli sim θ_std=%.2f° (gerçek Test 2.5: <0.7°). ', r_fric.theta_std);
if r_fric.theta_std < 1.0 && r_nofric.theta_std > 1.0
    fprintf('Sürtünme limit-cycle''ı SÖNDÜRDÜ → sim-to-real gap KAPANDI.\n');
else
    fprintf('(beklenen: sürtünmeli stabil, sürtünmesiz gezinme)\n');
end

% ── Karşılaştırma plot ────────────────────────────────────────────
fig=figure('Visible','off','Position',[40 40 1150 760],'Color','w'); ref=rad2deg(P.theta_ref);
% θ takip
subplot(3,1,1);
plot(r_nofric.t, rad2deg(r_nofric.theta),'Color',[0.85 0.33 0.1],'LineWidth',1.3); hold on
plot(r_fric.t,   rad2deg(r_fric.theta),  'b','LineWidth',1.5);
yline(ref,'k--'); yline(ref*1.02,'k:'); yline(ref*0.98,'k:'); grid on
ylabel('\theta_{out} (°)'); ylim([0 45]);
legend(sprintf('sürtünmesiz (\\theta_{std}=%.1f°, limit-cycle)',r_nofric.theta_std), ...
       sprintf('sürtünmeli (\\theta_{std}=%.1f°, stabil)',r_fric.theta_std), ...
       'hedef','Location','southeast');
title('Cascade θ takip — sürtünmenin limit-cycle''ı söndürmesi');
% ω
subplot(3,1,2);
plot(r_nofric.t, r_nofric.omega,'Color',[0.85 0.33 0.1],'LineWidth',0.9); hold on
plot(r_fric.t,   r_fric.omega,  'b','LineWidth',1.1); grid on
ylabel('\omega motor (rad/s)'); legend('sürtünmesiz','sürtünmeli','Location','northeast');
title(sprintf('Motor hızı — Coulomb eşiği %.1f rad/s altında sürtünmeli motor durur (stick)', P.omega_coulomb));
% u
subplot(3,1,3);
plot(r_nofric.t, r_nofric.u,'Color',[0.85 0.33 0.1],'LineWidth',0.9); hold on
plot(r_fric.t,   r_fric.u,  'b','LineWidth',1.1); grid on
ylabel('duty u'); xlabel('t (s)'); ylim([-0.3 0.3]);
legend('sürtünmesiz','sürtünmeli','Location','northeast');
title('Kontrol sinyali');
sgtitle('Aşama 2.6.5 — Cascade gerçekçi sim: sürtünme sim-to-real gap''i kapatıyor');

out=fullfile(fileparts(mfilename('fullpath')),'results');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out,'realistic_cascade.png'),'Resolution',150);
fprintf('\nÇıktı: %s/realistic_cascade.png\n', out);

% ════════════════════════════════════════════════════════════════
function r = sim_cascade(P, friction)
    N=round(P.T/P.dt); t=(0:N-1)*P.dt;
    om=0; th=0; ipi=0; oh=zeros(1,P.MA); ep=0; Tt=P.Kp_i/P.Ki_i;
    lt=zeros(1,N); lo=zeros(1,N); lu=zeros(1,N);
    for k=1:N
        % Dış döngü: pozisyon P (kuantize ölçüm)
        thm=round(th/P.POS_Q)*P.POS_Q;
        wref=P.Kp_pos*(P.theta_ref-thm)*P.GEAR;
        % İç döngü: hız PI (kuantize + MA ölçüm)
        oq=round(om/P.OMEGA_Q)*P.OMEGA_Q; oh=[oh(2:end) oq]; of=mean(oh);
        e=wref-of; ipi=ipi+P.Ki_i*P.dt/2*(e+ep);
        uu=P.Kp_i*e+ipi; u=max(min(uu,0.5),-0.5);
        if Tt>0, ipi=ipi+(P.dt/Tt)*(u-uu); end
        ep=e;
        % Plant: 1. derece + V_sat + (opsiyonel) Coulomb/stiction sürtünme
        Veff=sign(u)*max(abs(u)*P.Vs-P.Vsat,0);
        omega_drive=P.K*Veff;                 % sürtünmesiz hedef hız
        if friction && abs(om)<P.omega_stick && abs(omega_drive)<P.omega_coulomb
            om=0;                             % STICK: düşük hız + zayıf sürücü → yapış
        else
            om=om+P.dt/P.tau*(omega_drive-om);% normal 1. derece (viskoz gömülü)
        end
        th=th+(om/P.GEAR)*P.dt;
        lt(k)=th; lo(k)=om; lu(k)=u;
    end
    r=metrics(P,t,lt,lo,lu);
end

function r = metrics(P,t,lt,lo,lu)
    N=numel(t); td=rad2deg(lt); ref=rad2deg(P.theta_ref);
    tail=td(round(0.7*N):end);
    r.ss=abs(mean(tail)-ref)/ref*100;
    r.OS=max(0,(max(td)-ref)/ref*100);
    r.theta_std=std(tail);                    % limit-cycle göstergesi
    r.t=t; r.theta=lt; r.omega=lo; r.u=lu;
end

function print_row(name, r)
    v='STABİL'; if r.theta_std>1.0, v='⚠ LIMIT-CYCLE'; end
    fprintf('  %-14s %-10.2f %-10.1f %-12.2f %s\n', name, r.ss, r.OS, r.theta_std, v);
end
