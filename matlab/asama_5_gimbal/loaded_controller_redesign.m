function loaded_controller_redesign()
% LOADED_CONTROLLER_REDESIGN  Asama 5.x — YUKLU plant'a gore kontrolcu yeniden tasarimi (ROADMAP KRITIK NOT).
% Sorun: simdiye kadar YUKSUZ kazanclarla (Kp_pos=2, hiz PI Asama-2) yuklu gimbal kontrol edildi.
% Yuklu plant VERIDEN turetildi (free-decay + gravite-FF, yeni ID testi YOK):
%   omega_n=4 rad/s, zeta=0.1 (sarkac free-decay ID); kff_grav=0.21 (gravite duty); k_kin=-0.84 (kinematik)
%   => duty->aci plant:  G(s) = (K_m/J)/(s^2+2*zeta*wn*s+wn^2),  K_m/J = wn^2/kff_grav = 16/0.21 = 76
%      G(s) = 76/(s^2 + 0.8 s + 16)   [hafif sonumlu rezonans wn=4]
% TASARIM: PD (poz + hiz/gyro) ile kapali-dongu kutuplari zeta=0.7'ye, bant 2x'e (wn_cl=8).
%   Karakteristik: s^2 + (0.8+76*Kd) s + (16+76*Kp) = 0
%   wn_cl=8, zeta_cl=0.7:  16+76*Kp=64 -> Kp=0.63 (duty/rad);  0.8+76*Kd=11.2 -> Kd=0.137 (duty/(rad/s))
% Gyro = Kd terimi (hiz geri-besleme = sonum). Isaret POZITIF (sign-testi). gravite-FF zaten yuklu (0.21).
% Calistirma: matlab -batch "cd('matlab/asama_5_gimbal'); loaded_controller_redesign"
    here=fileparts(mfilename('fullpath')); outdir=fullfile(here,'results','loaded_controller_redesign');
    if ~exist(outdir,'dir'), mkdir(outdir); end
    set(groot,'defaultFigureColor','w','defaultAxesColor','w','defaultAxesXColor','k', ...
        'defaultAxesYColor','k','defaultTextColor','k','defaultAxesGridAlpha',0.3);

    wn=4; zeta=0.10; kffg=0.21; kkin=-0.84;
    KmJ = wn^2/kffg;                 % =76
    s=tf('s'); G = KmJ/(s^2+2*zeta*wn*s+wn^2);

    % --- PD tasarim (pole placement) ---
    wn_cl=8; zt_cl=0.7;
    Kp=(wn_cl^2-wn^2)/KmJ;           % duty/rad
    Kd=(2*zt_cl*wn_cl-2*zeta*wn)/KmJ;% duty/(rad/s)
    C = Kp + Kd*s;
    Tcl = feedback(G*C,1);
    [~,z_ach]=damp(Tcl);

    % --- gyro k_ff esdegeri (firmware: omega_ff=k_ff*gy[rad/s] hiz-setpoint'e; iç hız servosu sonra) ---
    % Yaklasik: gyro hiz-setpoint'i k_ff*gy uretir; cikis mili hizi ~ omega_ff/gear; bu Kd-benzeri sonum.
    % Firmware'de DOGRUDAN PD-STAB en temiz: duty = stab_dir*(Kp*(FP0-FP)*DEG2RAD + Kd*(-gy)*DEG2RAD) + grav_FF
    fprintf('\n=== YUKLU kontrolcu yeniden tasarim ===\n');
    fprintf('  Yuklu plant: G=76/(s^2+0.8s+16)  (wn=%.0f, zeta=%.2f -- hafif sonumlu)\n',wn,zeta);
    fprintf('  Hedef kapali-dongu: wn_cl=%.0f rad/s, zeta_cl=%.1f\n',wn_cl,zt_cl);
    fprintf('  ---> PD KAZANC (duty domeni):  Kp=%.3f duty/rad   Kd=%.3f duty/(rad/s)\n',Kp,Kd);
    fprintf('       (derece cinsinden: Kp=%.4f duty/deg, Kd=%.4f duty/(deg/s))\n',Kp*pi/180,Kd*pi/180);
    fprintf('  Ulasilan kapali-dongu zeta=%.2f (hedef %.1f)\n',min(z_ach),zt_cl);
    fprintf('  ISARET: gyro/Kd POZITIF (sign-test); stab_dir=+1 (k_kin<0). gravite-FF=0.21 (yuklu, degismez).\n');

    % --- step yanit: yuksuz-gain (kotu) vs yuklu-PD ---
    f=figure('Position',[60 60 900 380],'Color','w','Visible','off');
    subplot(1,2,1); hold on; grid on; box on;
    step(G/dcgain(G),6);   % plant kendi (acik) - cinlar
    step(Tcl,6);
    legend('plant (kontrolsuz, cinlar)','yuklu-PD (zeta=0.7)','Location','southeast');
    title('Adim yaniti: rezonans -> sonumlu'); xlabel('t'); ylabel('aci (norm)');
    subplot(1,2,2); hold on; grid on; box on;
    rlocus(G); title('Plant kutuplari (wn=4, hafif sonum) -> PD sola tasir');
    sgtitle(sprintf('Yuklu kontrolcu: Kp=%.2f Kd=%.3f (duty), zeta 0.1->%.1f',Kp,Kd,zt_cl),'FontWeight','bold');
    exportgraphics(f,fullfile(outdir,'loaded_controller_redesign.png'),'Resolution',150); close(f);

    rec=struct('plant',struct('wn',wn,'zeta',zeta,'KmJ',KmJ,'kff_grav',kffg,'k_kin',kkin), ...
        'design',struct('wn_cl',wn_cl,'zeta_cl',zt_cl,'Kp_duty_per_rad',round(Kp,4),'Kd_duty_per_radps',round(Kd,4), ...
        'Kp_duty_per_deg',round(Kp*pi/180,5),'Kd_duty_per_degps',round(Kd*pi/180,5)), ...
        'note','DOGRUDAN PD-STAB onerilir (cascade-mapping belirsizligini atlar); gravite-FF yuklu 0.21; isaret +.');
    fid=fopen(fullfile(outdir,'loaded_controller_redesign.json'),'w');
    fwrite(fid,jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('  Cikti: %s/\n',outdir);
end
