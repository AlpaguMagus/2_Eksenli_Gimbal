function design_lqr_lqi_singleaxis()
% DESIGN_LQR_LQI_SINGLEAXIS  Aşama 4 (K6) — tek-eksen LQR/LQI tasarım + cascade kıyası.
%
% Tezin §2.10'da SİMÜLE ettiği ama repoda OLMAYAN "LQG vs cascade" iddiasının GERÇEK,
% doğrulanabilir karşılığı: motor-2'nin Aşama-1 modeli üzerinde analitik LQR/LQI tasarımı,
% Aşama-2.5 cascade ile AYNI plant'ta step-yanıt kıyası. Donanımsız (tasarım/sim).
%
% ANALİTİK-ÖNCE (CLAUDE.md): LQR = optimal kontrol → maliyet fonksiyoneli + Riccati ile
% TÜRETİLİR; Q/R Bryson kuralıyla fiziksel limitlerden seçilir; lqr() yalnız DOĞRULAMA
% (Riccati artığı ‖A'S+SA−SBR⁻¹B'S+Q‖ ≈ 0 kontrol edilir).
%
% DURUM-UZAYI (çıkış pozisyon kontrolü, SI):
%   x1 = θ_out [rad],  x2 = ω_m [rad/s] (motor mili),  u = duty
%   ẋ1 = x2/gear,  ẋ2 = −x2/τ + (Kg/τ)·u       (Kg=K·Vs=654.8 duty-domeni, H1)
%   A=[0,1/gear; 0,−1/τ],  B=[0; Kg/τ],  C=[1,0]
%
% Kaynak: [Anderson2007] §2-3 (LQR+Riccati), [Franklin2010] §7.9/§9 (integral/durum-FB),
%         Bryson kuralı (Q/R fiziksel-limit normalizasyonu). Plant [Aşama 2.1].
% Çalıştırma: matlab -batch "cd('matlab/asama_4_mimo_kontrol'); design_lqr_lqi_singleaxis"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '4_1_lqr_lqi');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k', ...
        'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    % ── plant (motor-2, Aşama 1) ──
    K=53.89; Vs=12.15; Kg=K*Vs; tau=0.0605; gear=9.7;
    A = [0, 1/gear; 0, -1/tau];   B = [0; Kg/tau];   C = [1, 0];

    % ── Bryson kuralı: Q/R fiziksel limitlerden ──
    th_max = deg2rad(90); wm_max = 251; u_max = 0.50;
    Q = diag([1/th_max^2, 1/wm_max^2]);   R = 1/u_max^2;

    % ── LQR (regülatör) + referans ölçekleme Nbar ──
    [Klqr, S] = lqr(A, B, Q, R);
    ric_res = norm(A'*S + S*A - S*B*(R\(B'*S)) + Q);
    Nbar = -1 / (C * ((A - B*Klqr) \ B));
    Acl_lqr = A - B*Klqr;
    sys_lqr = ss(Acl_lqr, B*Nbar, C, 0);

    fprintf('\n=== K6 tek-eksen LQR/LQI ===\n');
    fprintf('Plant: Kg=%.1f, tau=%.1f ms, gear=%.1f\n', Kg, tau*1000, gear);
    fprintf('LQR K=[%.4g, %.4g], Nbar=%.4g, Riccati artığı=%.2e\n', Klqr(1),Klqr(2),Nbar,ric_res);
    fprintf('LQR kutuplar: '); fprintf('%.2f ', sort(real(eig(Acl_lqr)))); fprintf('\n');

    % ── LQI (integral augment) — sıfır ss-hata + bozucu reddi ──
    Aa=[A, zeros(2,1); -C, 0];  Ba=[B; 0];
    q_i = (1/deg2rad(2)^2) * 50;          % integral ağırlığı (2° hedef, ×50 otorite)
    Qa = blkdiag(Q, q_i);
    Klqi = lqr(Aa, Ba, Qa, R);            % [K1 K2 Ki]
    sys_lqi = ss(Aa - Ba*Klqi, [0;0;1], [C 0], 0);   % ref x3'e [0;0;1]·r ile girer
    fprintf('LQI K=[%.4g, %.4g | Ki=%.4g]\n', Klqi(1),Klqi(2),Klqi(3));

    % ── cascade (Aşama 2.5) — AYNI plant, SI-eşdeğer Kp_pos ──
    Cin = pid(0.002, 0.1);
    Tin = feedback(tf(Kg,[tau 1])*Cin, 1);     % ω_m_ref → ω_m
    Pos = Tin * tf(1,[gear 0]);                % ω_m_ref → θ_out
    Kp_pos_si = 1.93*gear;                     % dominant kutbu ~−2'ye (Aşama-2.5 ωc~1.93)
    Tout_casc = feedback(Kp_pos_si*Pos, 1);
    TFu_casc  = Cin*(1-Tin)*Kp_pos_si*feedback(1, Kp_pos_si*Pos);   % r→u (duty)
    fprintf('Cascade Kp_pos(SI)=%.1f, dominant kutup ~%.2f\n', Kp_pos_si, max(real(pole(Tout_casc))));

    % ── step yanıtı (0 → 30°) + kontrol eforu ──
    ref = deg2rad(30); tend = 2.5; t = (0:0.001:tend).';
    y_casc = rad2deg(ref) * step(Tout_casc, t);
    y_lqr  = rad2deg(ref) * step(sys_lqr, t);
    y_lqi  = rad2deg(ref) * step(sys_lqi, t);
    u_casc = ref * step(TFu_casc, t);                              % T×1 duty
    u_lqr  = ref * ( statetraj(sys_lqr,t)*(-Klqr.') + Nbar );      % T×1
    u_lqi  = ref * ( statetraj(sys_lqi,t)*(-Klqi.') );             % T×1

    m_casc=metr(t,y_casc,rad2deg(ref)); m_lqr=metr(t,y_lqr,rad2deg(ref)); m_lqi=metr(t,y_lqi,rad2deg(ref));
    fprintf('\n%-10s %-12s %-11s %-11s %-8s\n','Kontrolcü','settling(s)','OS(%)','ss-err(°)','maxduty');
    prn('cascade',m_casc,max(abs(u_casc))); prn('LQR+Nbar',m_lqr,max(abs(u_lqr))); prn('LQI',m_lqi,max(abs(u_lqi)));

    % ── figür ──
    f=figure('Position',[40 40 1100 580],'Color','w','Visible','off');
    subplot(2,1,1); hold on; grid on; box on;
    yline(rad2deg(ref),'k:','HandleVisibility','off');
    plot(t,y_casc,'LineWidth',1.5,'Color',[0.0 0.35 0.75],'DisplayName',sprintf('cascade (t_s %.2fs, OS %.0f%%)',m_casc.ts,m_casc.os));
    plot(t,y_lqr ,'LineWidth',1.5,'Color',[0.85 0.4 0.1],'DisplayName',sprintf('LQR+Nbar (t_s %.2fs, OS %.0f%%)',m_lqr.ts,m_lqr.os));
    plot(t,y_lqi ,'LineWidth',1.7,'Color',[0.15 0.6 0.15],'DisplayName',sprintf('LQI (t_s %.2fs, OS %.0f%%)',m_lqi.ts,m_lqi.os));
    ylabel('$\theta_{out}$ (deg)','Interpreter','latex'); xlim([0 tend]);
    title('Single-axis position step 0$\rightarrow$30$^\circ$: LQR/LQI vs cascade (same motor-2 plant)','Interpreter','latex','FontSize',12);
    lg=legend('Interpreter','tex','Location','southeast'); set(lg,'Color','w','TextColor','k');
    subplot(2,1,2); hold on; grid on; box on;
    plot(t,u_casc,'LineWidth',1.3,'Color',[0.0 0.35 0.75],'DisplayName','cascade');
    plot(t,u_lqr ,'LineWidth',1.3,'Color',[0.85 0.4 0.1],'DisplayName','LQR+Nbar');
    plot(t,u_lqi ,'LineWidth',1.5,'Color',[0.15 0.6 0.15],'DisplayName','LQI');
    yline(0.5,':','Color',[0.6 0.3 0.3],'HandleVisibility','off'); yline(-0.5,':','Color',[0.6 0.3 0.3],'HandleVisibility','off');
    ylabel('$u$ (duty)','Interpreter','latex'); xlabel('time (s)','Interpreter','latex'); xlim([0 tend]); ylim([-0.6 0.6]);
    title('Control effort (Bryson $Q/R$ keeps $u$ within $\pm0.5$)','Interpreter','latex','FontSize',11);
    sgtitle('Asama 4 (K6) — Single-axis LQR/LQI (analytic Bryson + Riccati, motor-2 model)','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'lqr_lqi_step.png'),'Resolution',150); close(f);

    % ── JSON ──
    rec = struct('plant',struct('Kg',Kg,'tau_s',tau,'gear',gear), ...
        'bryson',struct('th_max_rad',th_max,'wm_max_radps',wm_max,'u_max',u_max), ...
        'K_lqr',Klqr,'Nbar',Nbar,'riccati_residual',ric_res, ...
        'K_lqi',Klqi(1:2),'Ki_lqi',Klqi(3),'Kp_pos_si',Kp_pos_si, ...
        'cascade',m2s(m_casc,max(abs(u_casc))),'lqr',m2s(m_lqr,max(abs(u_lqr))),'lqi',m2s(m_lqi,max(abs(u_lqi))), ...
        'kaynak',{{'Anderson2007 §2-3','Franklin2010 §7.9','Bryson rule'}});
    fid=fopen(fullfile(outdir,'lqr_lqi_params.json'),'w'); fwrite(fid,jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('\nÇıktı: %s/ (lqr_lqi_step.png + .json)\n', outdir);
end

% ====================================================================
function X = statetraj(sys, t)
    [~,~,X] = step(sys, t);   % T×n durum trajektorisi (birim step)
end
function m = metr(t, y, target)
    yf=y(end); os=max(0,(max(y)-target)/target*100);
    tol=0.02*target; idx=find(abs(y-target)>tol,1,'last');
    if isempty(idx), ts=0; else, ts=t(min(idx+1,numel(t))); end
    m=struct('ts',ts,'os',os,'sserr',abs(target-yf));
end
function prn(n,m,mu), fprintf('%-10s %-12.2f %-11.1f %-11.3f %-8.3f\n',n,m.ts,m.os,m.sserr,mu); end
function s=m2s(m,mu), s=struct('settling_s',round(m.ts,3),'overshoot_pct',round(m.os,1),'sserr_deg',round(m.sserr,3),'max_duty',round(mu,3)); end
