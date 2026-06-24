function design_gyro_feedforward()
% DESIGN_GYRO_FEEDFORWARD  Aşama 3.8 (K2) — gyro feedforward ANALİTİK tasarım + bozucu-reddi sim.
%
% Soru: gyro ile besleme-ileri (feedforward), cascade'in yavaş dış-döngüsünü baypas edip
% base-hareketini ne kadar daha iyi reddeder? (deneme-yanılma DEĞİL — analitik + sim).
%
% ANALİTİK k_ff TÜRETİMİ (stabilizasyon görevi):
%   payload eylemsiz açısı  φ = θ_base + θ_out   (θ_out = motor çıkış mili, base'e göre)
%   Hedef φ=0  →  θ_out = −θ_base  (çıkış mili base'e TERS dönmeli)
%   motor mili = 9.7 × çıkış mili (Pololu 25D redüktör 9.7:1, encoder.h)
%   hız döngüsü MOTOR mili rad/s setpoint alır (Encoder_GetSpeed motor mili, ham)
%   ⇒ ω_ff = −9.7 · (gy_dps·π/180)  [rad/s, motor mili]   ⇒   k_ff = redüktör = 9.7
%
% 2-DOF YAPI (bozucu-reddi sensitiviteleri, φ/θ_base):
%   FB-yalnız:  S_fb  = 1/(1+L_out)         (bant ~ dış-döngü ωc, baskın çift ~6.2 rad/s)
%   FF-yalnız:  S_ff  = 1 − T_inner          (bant ~ iç-döngü ~33 rad/s)   [ideal FF, k_ff tam]
%   FB+FF:      S_both = S_fb · (1 − T_inner) (her iki çarpan küçük → en iyi reddi)
%   → gyro-FF, reddi-bant-genişliğini iç-döngüye (~33) çıkarır = dış-döngüye (~6.2) göre ~5×.
%
% Kaynak: [Franklin2010] §7.3 (feedforward / 2-DOF), [Hilkert2008] (gimbal inertial rate FF — ISP).
%         İç-döngü modeli [Aşama 2.1] K=53.89/τ=60.5ms, Kp_pos=6 [Aşama 2.7].
% NOT: İdeal FF (k_ff tam, gyro gürültü/bias/gecikme yok) → analitik ÜST-SINIR. Gerçek gyro
%      gürültüsü/biası bunu bir miktar bozar (Aşama 5 IMU-payload bench'inde doğrulanır).
% Çalıştırma: matlab -batch "cd('matlab/asama_3_mimo_model'); design_gyro_feedforward"

    here = fileparts(mfilename('fullpath'));
    root = fullfile(here, '..', '..');
    outdir = fullfile(here, 'results', '3_8_gyro_ff');
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k', ...
        'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    % ── cascade modeli (Aşama 2) ──
    % DİKKAT: iç-döngü plant'ı DUTY-domeni: u(duty)→ω. Plant DC kazancı Kg=K·Vs=654.8
    % (K=53.89 voltaj-domeni DEĞİL — Aşama 2.3 H1 düzeltmesi). Kp/Ki bu Kg için tasarlandı;
    % K kullanılırsa iç-döngü 12× yavaş (ωn 33→9.4) çıkar → bant-genişliği analizi bozulur.
    K=53.89; Vs=12.15; Kg=K*Vs; tau=0.0605; Kp_i=0.002; Ki_i=0.1; Kp_pos=6; gear=9.7;
    G = tf(Kg,[tau 1]); C = pid(Kp_i,Ki_i);
    T_inner = feedback(G*C,1);
    P_outer = T_inner * tf(1,[1 0]);
    L_outer = Kp_pos * P_outer;
    T_out   = feedback(L_outer,1);

    % ── bozucu-reddi sensitiviteleri (φ/θ_base) ──
    S_fb   = feedback(1, L_outer);     % FB-yalnız
    S_ff   = 1 - T_inner;              % FF-yalnız (ideal)
    S_both = S_fb * (1 - T_inner);     % FB+FF
    k_ff   = gear;

    % ── reddi bant-genişlikleri (-3dB: |S| ilk kez 1/sqrt(2)'yi aşar) ──
    fvec = logspace(-2, 2.3, 1000); w = 2*pi*fvec; thr = 1/sqrt(2);
    m_fb   = squeeze(abs(freqresp(S_fb,   w)));
    m_ff   = squeeze(abs(freqresp(S_ff,   w)));
    m_both = squeeze(abs(freqresp(S_both, w)));
    bw_fb   = first_cross(fvec, m_fb,   thr);
    bw_ff   = first_cross(fvec, m_ff,   thr);
    bw_both = first_cross(fvec, m_both, thr);

    fprintf('\n=== Gyro-FF (K2) analitik tasarım ===\n');
    fprintf('  k_ff = redüktör = %.1f (motor mili rad/s / çıkış mili rad/s)\n', k_ff);
    fprintf('  Reddi bant-genişliği (-3dB):\n');
    fprintf('    FB-yalnız  : %.2f Hz (%.1f rad/s)\n', bw_fb,   2*pi*bw_fb);
    fprintf('    FF-yalnız  : %.2f Hz (%.1f rad/s)\n', bw_ff,   2*pi*bw_ff);
    fprintf('    FB+FF      : %.2f Hz (%.1f rad/s)\n', bw_both, 2*pi*bw_both);
    fprintf('    kazanım (FB+FF / FB) = %.1f×\n', bw_both/bw_fb);

    % ── zaman-domeni bozucular ──
    % (1) sentetik 2 Hz sinüs (hızlı panning / titreşim rejimi — FF'in parladığı yer)
    A_syn = 10; f_syn = 2.0;
    t1 = (0:0.001:3).';
    base1 = A_syn*sin(2*pi*f_syn*t1);
    phi1_fb   = lsim(S_fb,   base1, t1);
    phi1_both = lsim(S_both, base1, t1);
    rms1_fb   = rms_(phi1_fb);   rms1_both = rms_(phi1_both);

    % (2) gerçek base-hareketi (stab bench fp(t) = el ile eğme)
    stab = fullfile(root,'artifacts','3','stab_m2','20260612_121945','raw','data.csv');
    have_real = isfile(stab);
    if have_real
        T = readtable(stab); tr_ = T.t; fp_ = T.fp - mean(T.fp);
        dt = median(diff(tr_)); t2 = (tr_(1):dt:tr_(end)).';
        base2 = interp1(tr_, fp_, t2, 'linear');
        phi2_fb   = lsim(S_fb,   base2, t2);
        phi2_both = lsim(S_both, base2, t2);
        rms2_fb = rms_(phi2_fb); rms2_both = rms_(phi2_both);
        f_dom2 = dominant_freq(base2, dt);
    end

    % ── RMS payload hatası vs bozucu frekansı (A_base=10°) ──
    A_b = 10; rms_fb_f = m_fb*A_b/sqrt(2); rms_both_f = m_both*A_b/sqrt(2);

    % ================= FİGÜR 1: tasarım & kazanım =================
    f = figure('Position',[40 40 1180 760],'Color','w','Visible','off');

    subplot(2,2,1); hold on; grid on; box on;
    plot(fvec, 20*log10(m_fb),   'LineWidth',1.6,'Color',[0.0 0.35 0.75],'DisplayName','FB only  $S=1/(1+L_{out})$');
    plot(fvec, 20*log10(m_ff),   'LineWidth',1.4,'Color',[0.85 0.5 0.1],'DisplayName','FF only  $1-T_{in}$');
    plot(fvec, 20*log10(m_both), 'LineWidth',1.8,'Color',[0.15 0.6 0.15],'DisplayName','FB + FF');
    yline(20*log10(thr),'k:','-3 dB','HandleVisibility','off');
    set(gca,'XScale','log'); xlabel('disturbance freq (Hz)','Interpreter','latex');
    ylabel('$|\phi / \theta_{base}|$ (dB)','Interpreter','latex'); ylim([-60 6]);
    title('Disturbance-rejection sensitivity (lower = better)','Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','southeast'); set(lg,'Color','w','TextColor','k');

    subplot(2,2,2); hold on; grid on; box on;
    plot(fvec, rms_fb_f,   'LineWidth',1.6,'Color',[0.0 0.35 0.75],'DisplayName','FB only');
    plot(fvec, rms_both_f, 'LineWidth',1.8,'Color',[0.15 0.6 0.15],'DisplayName','FB + FF');
    xline(bw_fb,':','HandleVisibility','off','Color',[0.0 0.35 0.75]);
    xline(bw_both,':','HandleVisibility','off','Color',[0.15 0.6 0.15]);
    set(gca,'XScale','log'); xlabel('disturbance freq (Hz)','Interpreter','latex');
    ylabel('payload error RMS (deg)','Interpreter','latex');
    title(sprintf('Residual payload error vs freq ($A_{base}=%d^\\circ$) -- rej. BW %.2f$\\to$%.2f Hz', A_b, bw_fb, bw_both),'Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','northwest'); set(lg,'Color','w','TextColor','k');

    subplot(2,2,3); hold on; grid on; box on;
    plot(t1, base1,     '--','LineWidth',1.0,'Color',[0.55 0.55 0.55],'DisplayName','base motion');
    plot(t1, phi1_fb,   '-', 'LineWidth',1.4,'Color',[0.0 0.35 0.75],'DisplayName',sprintf('FB only (RMS %.2f$^\\circ$)',rms1_fb));
    plot(t1, phi1_both, '-', 'LineWidth',1.6,'Color',[0.15 0.6 0.15],'DisplayName',sprintf('FB+FF (RMS %.2f$^\\circ$)',rms1_both));
    xlabel('time (s)','Interpreter','latex'); ylabel('payload $\phi$ (deg)','Interpreter','latex');
    title(sprintf('Fast disturbance %g Hz, $%d^\\circ$ -- FF cuts residual %.0f$\\times$',f_syn,A_syn, rms1_fb/max(rms1_both,1e-9)),'Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','northeast'); set(lg,'Color','w','TextColor','k'); xlim([0 2]);

    subplot(2,2,4); hold on; grid on; box on;
    if have_real
        plot(t2, base2,     '--','LineWidth',0.9,'Color',[0.55 0.55 0.55],'DisplayName','real base (IMU)');
        plot(t2, phi2_fb,   '-', 'LineWidth',1.3,'Color',[0.0 0.35 0.75],'DisplayName',sprintf('FB only (RMS %.2f$^\\circ$)',rms2_fb));
        plot(t2, phi2_both, '-', 'LineWidth',1.5,'Color',[0.15 0.6 0.15],'DisplayName',sprintf('FB+FF (RMS %.2f$^\\circ$)',rms2_both));
        xlabel('time (s)','Interpreter','latex'); ylabel('payload $\phi$ (deg)','Interpreter','latex');
        title(sprintf('Real bench base motion (dom. %.2f Hz, slow) -- FB already good',f_dom2),'Interpreter','latex','FontSize',11);
        lg=legend('Interpreter','latex','Location','best'); set(lg,'Color','w','TextColor','k'); xlim([t2(1) t2(end)]);
    end

    sgtitle(sprintf('Asama 3.8 (K2) -- Gyro Feedforward: rejection BW %.2f$\\to$%.2f Hz (%.1f$\\times$), $k_{ff}=%.1f$', bw_fb, bw_both, bw_both/bw_fb, k_ff),'Interpreter','latex','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'gyro_ff_design.png'),'Resolution',150);
    close(f);

    % ================= FİGÜR 2: 2-DOF blok diyagram =================
    fig_block(outdir, k_ff, Kp_pos);

    % ── JSON ──
    rec = struct('k_ff', k_ff, 'gear_ratio', gear, ...
        'bw_fb_hz', round(bw_fb,3), 'bw_ff_hz', round(bw_ff,3), 'bw_both_hz', round(bw_both,3), ...
        'bw_gain_factor', round(bw_both/bw_fb,2), ...
        'inner_wn_radps', 33, 'outer_dominant_radps', 6.2, ...
        'syn_2hz_rms_fb_deg', round(rms1_fb,3), 'syn_2hz_rms_both_deg', round(rms1_both,3), ...
        'kaynak', {{'Franklin2010 §7.3','Hilkert2008'}});
    if have_real
        rec.real_rms_fb_deg = round(rms2_fb,3);
        rec.real_rms_both_deg = round(rms2_both,3);
        rec.real_dominant_freq_hz = round(f_dom2,3);
    end
    fid=fopen(fullfile(outdir,'gyro_ff_params.json'),'w');
    fwrite(fid, jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('\nÇıktı: %s/ (gyro_ff_design.png + gyro_ff_block.png + .json)\n', outdir);
end

% ====================================================================
function fc = first_cross(f, mag, thr)
    idx = find(mag >= thr, 1, 'first');
    if isempty(idx) || idx==1, fc = f(max(idx,1)); return; end
    % lineer interp (log-f) köşe frekansı
    f1=f(idx-1); f2=f(idx); m1=mag(idx-1); m2=mag(idx);
    fc = f1 + (thr-m1)/(m2-m1)*(f2-f1);
end

function r = rms_(x), r = sqrt(mean(x.^2)); end

function fd = dominant_freq(x, dt)
    N=numel(x); Y=abs(fft(x-mean(x))); Y=Y(1:floor(N/2));
    fax=(0:floor(N/2)-1).'*(1/dt/N); [~,ip]=max(Y(2:end)); fd=fax(ip+1);
end

% ====================================================================
function fig_block(outdir, k_ff, Kp_pos)
% 2-DOF: gyro θ̇_base → −k_ff → hız-setpoint toplamı; cascade FB θ_ref → P_pos → toplam → PI → motor.
    f = figure('Position',[60 60 1180 440],'Color','w','Visible','off');
    ax = axes('Position',[0 0 1 1]); hold(ax,'on'); axis(ax,[0 13 0 4.6]); axis(ax,'off');
    cC=[0.92 0.95 1.0]; cM=[0.90 1.0 0.88]; cF=[1.0 0.93 0.80];
    ym=2.3;
    % FB zinciri
    text(0.10,ym+0.32,'$\theta_{ref}$','Interpreter','latex','FontSize',12);
    draw_arrow(0.10,ym,1.0,ym);
    draw_sum(1.3,ym); text(1.05,ym-0.46,'$-$','Interpreter','latex','FontSize',12);
    draw_arrow(1.55,ym,2.3,ym);
    draw_block(3.0,ym,1.4,0.95,'$P_{pos}$',cC); text(3.0,ym-0.74,sprintf('$K_{p,pos}=%g$',Kp_pos),'Interpreter','latex','FontSize',8.5,'HorizontalAlignment','center');
    draw_arrow(3.7,ym,4.6,ym);
    draw_sum(4.85,ym); text(5.15,ym+0.42,'$+$','Interpreter','latex','FontSize',12);
    text(4.30,ym+0.34,'$\omega_{ref}$','Interpreter','latex','FontSize',10);
    draw_arrow(5.1,ym,5.9,ym);
    draw_block(6.6,ym,1.4,0.95,'PI',cC); text(6.6,ym-0.74,'SpeedPI','FontSize',8.5,'HorizontalAlignment','center');
    draw_arrow(7.3,ym,8.2,ym); text(7.45,ym+0.32,'$u$','Interpreter','latex','FontSize',10);
    draw_block(8.95,ym,1.5,0.95,'motor',cM); text(8.95,ym-0.74,'TB6612 / plant','FontSize',8.5,'HorizontalAlignment','center');
    draw_arrow(9.7,ym,11.6,ym); text(10.5,ym+0.32,'$\theta_{out}$','Interpreter','latex','FontSize',11);
    % FB geri besleme
    plot([11.2 11.2],[ym ym-1.0],'k','LineWidth',1.2);
    plot([11.2 1.3],[ym-1.0 ym-1.0],'k','LineWidth',1.2);
    draw_arrow(1.3,ym-1.0,1.3,ym-0.25);
    text(6.0,ym-1.0+0.16,'encoder position feedback','FontSize',8.5,'HorizontalAlignment','center');
    % FF yolu (gyro → −k_ff → speed-setpoint sum), −k_ff sum'ın TAM ÜSTÜNDE
    yf=3.65;
    draw_block(2.5,yf,1.8,0.9,'IMU gyro',cF);
    draw_arrow(3.4,yf,4.15,yf); text(3.55,yf+0.30,'$\dot{\theta}_{base}$','Interpreter','latex','FontSize',11);
    draw_block(4.85,yf,1.3,0.9,'$-k_{ff}$',cF); text(4.85,yf-0.62,sprintf('$k_{ff}=%.1f$ (gear)',k_ff),'Interpreter','latex','FontSize',8.5,'HorizontalAlignment','center');
    draw_arrow(4.85,yf-0.45,4.85,ym+0.25);   % düz aşağı, sum'a
    text(7.6,yf+0.10,'gyro feedforward (2-DOF): bypasses slow outer loop','FontSize',9.5,'HorizontalAlignment','center','Color',[0.6 0.4 0.1]);

    str=['Stabilization: $\omega_{ref} = K_{p,pos}(\theta_{ref}-\theta_{out}) - k_{ff}\,\dot{\theta}_{base}$,' ...
         '\quad $k_{ff}=$ gear $=9.7$ (motor/output shaft).'];
    text(6.5,0.40,str,'Interpreter','latex','FontSize',11,'HorizontalAlignment','center', ...
        'BackgroundColor',[0.97 0.97 0.9],'EdgeColor',[0.7 0.7 0.7],'Margin',5);
    title(ax,'2-DOF Gyro Feedforward + Cascade Feedback','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'gyro_ff_block.png'),'Resolution',150);
    close(f);
end

% ── çizim helper'ları ──
function draw_block(cx,cy,w,h,label,fc)
    rectangle('Position',[cx-w/2,cy-h/2,w,h],'FaceColor',fc,'EdgeColor','k','LineWidth',1.4,'Curvature',0.1);
    text(cx,cy,label,'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Interpreter','latex');
end
function draw_sum(cx,cy)
    r=0.22; th=linspace(0,2*pi,40);
    plot(cx+r*cos(th),cy+r*sin(th),'k','LineWidth',1.3);
end
function draw_arrow(x1,y1,x2,y2)
    plot([x1 x2],[y1 y2],'k','LineWidth',1.2);
    a=atan2(y2-y1,x2-x1); L=0.18; d=0.38;
    plot([x2 x2-L*cos(a-d)],[y2 y2-L*sin(a-d)],'k','LineWidth',1.2);
    plot([x2 x2-L*cos(a+d)],[y2 y2-L*sin(a+d)],'k','LineWidth',1.2);
end
