function loaded_pendulum_damping_design()
% LOADED_PENDULUM_DAMPING_DESIGN  Asama 5.x — yuklu sarkac rezonansini gyro-rate ile sonumle (analitik).
%
% PROBLEM (olculen): yuklu LP = gravite sarkaci, ID free-decay:
%   omega_n ~ 4 rad/s (0.65 Hz), zeta ~ 0.1 (hafif sonumlu)  [artifacts/5/loaded_pendulum_id]
% Cascade dis-dongu crossover omega_c = Kp_pos = 2 rad/s (POS_P_CFG_LP) < rezonans 4 rad/s
%   -> cascade rezonansin ALTINDA: bastiramaz, faz-gecikmesiyle CINLATIR (deney: controller 0.8Hz ringledi).
% COZUM: gyro-rate feedback (K2) sarkac moduna DAMPING ekler -> kutuplari zeta 0.1 -> 0.7'ye tasi.
%
% ANALITIK: sarkac modu  P(s) = wn^2/(s^2 + 2*zeta*wn*s + wn^2).
%   Rate feedback k_d (FP-rate -> efektif sonum): kapali karakteristik
%     s^2 + (2*zeta*wn + k_d)*s + wn^2 = 0  ->  zeta_cl = (2*zeta*wn + k_d)/(2*wn)
%   Hedef zeta_cl=0.7 ->  k_d = 2*wn*(0.7 - zeta) = 2*4*(0.7-0.1) = 4.8  [rad/s, FP-rate katsayisi]
% Firmware k_ff'e harita (zincir, YAKLASIK): omega_ff[mot] = k_ff*gy; cikis k_ff*gy/gear;
%   FP-rate katkisi |k_kin|*k_ff/gear * gy = 0.107*k_ff * gy  => efektif k_d ~ 0.107*k_ff.
%   k_ff ~ k_d/0.107 = 4.8/0.107 ~ 45  (BUYUK -> stabilite siniri riski; bkz onceki margin analizi)
%   => Tek gyro damping %70 zeta'ya yetmeyebilir; NOTCH veya cascade-yeniden-tasarim gerekebilir.
% ISARET: model damping ongoruyor ama firmware isaret-konvansiyonu (gy/cascade/stab_dir) belirsiz
%   -> TEMIZ ring-down sign-test ile dogrulanir (k_ff +/- karsilastir). Bu script MAGNITUDE + STRATEJI verir.
% Kaynak: [Franklin2010] §6 (rate feedback damping), [Hilkert2008] (gimbal gyro damping). Plant: pendulum ID.
% Calistirma: matlab -batch "cd('matlab/asama_5_gimbal'); loaded_pendulum_damping_design"

    here=fileparts(mfilename('fullpath')); outdir=fullfile(here,'results','loaded_pendulum_damping');
    if ~exist(outdir,'dir'), mkdir(outdir); end
    set(groot,'defaultFigureColor','w','defaultAxesColor','w','defaultAxesXColor','k', ...
        'defaultAxesYColor','k','defaultTextColor','k','defaultAxesGridAlpha',0.3);

    wn=4.0; zeta=0.10;            % yuklu sarkac ID (free-decay)
    wc_cas=2.0;                   % cascade crossover = Kp_pos (POS_P_CFG_LP)
    gear=9.7; k_kin=-1.04; coef=abs(k_kin)/gear;   % =0.107 (gyro->FP-rate zincir)
    s=tf('s');
    P=wn^2/(s^2+2*zeta*wn*s+wn^2);

    % --- rate-feedback damping: k_d for zeta_cl target ---
    zt=0.7; k_d=2*wn*(zt-zeta);  kff_est=k_d/coef;
    Pcl=wn^2/(s^2+(2*zeta*wn+k_d)*s+wn^2);

    fprintf('\n=== Yuklu sarkac damping tasarimi ===\n');
    fprintf('  Sarkac ID: wn=%.1f rad/s (%.2f Hz), zeta_ol=%.2f (hafif)\n',wn,wn/2/pi,zeta);
    fprintf('  Cascade wc=%.1f rad/s < rezonans %.1f -> cascade cinlatir (rezonans altinda)\n',wc_cas,wn);
    fprintf('  Hedef zeta_cl=%.1f -> rate katsayisi k_d=%.2f rad/s\n',zt,k_d);
    fprintf('  Firmware harita (yaklasik): k_ff ~ k_d/%.3f = %.0f  (BUYUK: stabilite siniri riski)\n',coef,kff_est);
    [~,zol]=damp(P); [~,zcl]=damp(Pcl);
    fprintf('  Kapali kutup zeta: %.2f -> %.2f (hedef %.1f)\n',min(zol),min(zcl),zt);
    fprintf('  ISARET: model damping ongoruyor; firmware k_ff isareti TEMIZ ring-down testiyle dogrulanir.\n');

    % ================= FIGUR =================
    f=figure('Position',[40 40 1240 440],'Color','w','Visible','off');

    % (1) step: sarkac cinliyor vs damped
    subplot(1,3,1); hold on; grid on; box on;
    [y1,t1]=step(P,8); [y2,t2]=step(Pcl,8);
    plot(t1,y1,'LineWidth',1.5,'Color',[0.85 0.3 0.2],'DisplayName',sprintf('sonumsuz (zeta=%.2f) CINLAR',zeta));
    plot(t2,y2,'LineWidth',1.8,'Color',[0.15 0.6 0.15],'DisplayName',sprintf('gyro-damped (zeta=%.1f)',zt));
    xlabel('t (s)'); ylabel('FP yaniti'); title('Sarkac step: cinlar -> gyro-damped'); legend('Location','southeast');

    % (2) pole-zero / root migration
    subplot(1,3,2); hold on; grid on; box on;
    pol=roots([1 2*zeta*wn wn^2]); pcl=roots([1 2*zeta*wn+k_d wn^2]);
    plot(real(pol),imag(pol),'rx','MarkerSize',12,'LineWidth',2,'DisplayName','sonumsuz kutuplar');
    plot(real(pcl),imag(pcl),'gs','MarkerSize',10,'LineWidth',2,'MarkerFaceColor',[.6 1 .6],'DisplayName','gyro-damped');
    th=linspace(pi/2,3*pi/2,50); plot(wn*cos(th),wn*sin(th),'k:','HandleVisibility','off');
    xline(0,'k-','HandleVisibility','off'); yline(0,'k-','HandleVisibility','off');
    xlabel('Re'); ylabel('Im'); title('Kutuplar: sola (damping) tasinir'); legend('Location','southwest'); axis equal;

    % (3) Bode: rezonans vs cascade crossover
    subplot(1,3,3); hold on; grid on; box on;
    w=logspace(-1,1.6,500); [mP,~]=bode(P,w); mP=squeeze(mP);
    plot(w/2/pi,20*log10(mP),'LineWidth',1.5,'Color',[0.85 0.3 0.2],'DisplayName','sarkac |P|');
    xline(wn/2/pi,'r:','LineWidth',1.4,'DisplayName',sprintf('rezonans %.2f Hz',wn/2/pi));
    xline(wc_cas/2/pi,'b--','LineWidth',1.4,'DisplayName',sprintf('cascade wc %.2f Hz',wc_cas/2/pi));
    set(gca,'XScale','log'); xlabel('Hz'); ylabel('|P| dB');
    title('Cascade wc < rezonans -> bastiramaz'); legend('Location','southwest');

    sgtitle(sprintf('Yuklu sarkac damping: wn=%.1f rad/s, zeta %.2f->%.1f, k\\_d=%.1f (k\\_ff~%.0f, isaret test ile)',wn,zeta,zt,k_d,kff_est),'FontWeight','bold');
    exportgraphics(f,fullfile(outdir,'loaded_pendulum_damping_design.png'),'Resolution',150); close(f);

    rec=struct('wn_radps',wn,'zeta_ol',zeta,'cascade_wc_radps',wc_cas,'zeta_target',zt, ...
        'k_d_rate',round(k_d,2),'kff_estimate',round(kff_est),'coef_gyro_chain',coef, ...
        'note','k_ff MAGNITUDE estimate; SIGN via clean ring-down test; tek-gyro yetmezse NOTCH/cascade-redesign', ...
        'kaynak',{{'pendulum ID free-decay','Franklin2010 §6','Hilkert2008'}});
    fid=fopen(fullfile(outdir,'loaded_pendulum_damping_params.json'),'w');
    fwrite(fid,jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('  Cikti: %s/\n',outdir);
end
