function design_gain_schedule()
% DESIGN_GAIN_SCHEDULE  Aşama 3.9 (K3) — duty-indeksli gain scheduling ön-tasarımı.
%
% Aşama-1 sistem-tanımlama, τ'nun duty ile ~3× değiştiğini ölçtü (43 ms @ düşük duty →
% 133 ms @ yüksek duty; fit_report.md). SABİT kazançlı hız PI (τ_median=60.5 ms için
% tasarlandı) bu yüzden duty aralığında DEĞİŞKEN kapalı-çevrim dinamiği verir. Gain
% scheduling: Ki'yi ölçülen τ(duty) ile ayarlayıp bant-genişliğini (ωn) SABİT tutar.
% Donanımsız (mevcut Aşama-1 verisi + analitik pole-placement).
%
% ANALİTİK (CLAUDE.md): PI + 1.derece plant Kg/(τs+1) kapalı-çevrim karakteristik:
%   s² + (1+Kg·Kp)/τ · s + Kg·Ki/τ = 0   →   ωn = √(Kg·Ki/τ)
%   SABİT ωn için:  Ki(duty) = ωn²·τ(duty)/Kg   (Ki, τ ile ölçeklenir — schedule)
%   Kp = u_max/ω_max = 0.002 (doyum-kısıtı, SABİT — ζ τ ile bir miktar değişir; tam ζ
%   sabitliği Kp scheduling ister ama Kp>0.002 doyum-kısıtını ihlal eder → kabul edilen taviz).
%
% Kaynak: [Franklin2010] §6 pole-placement, §11.3 gain scheduling; [AstromMurray2008] §11
%         (gain scheduling); plant τ(duty) [Aşama 1 fit_report.md]. Hedef ωn=33 [Aşama 2.3].
% Çalıştırma: matlab -batch "cd('matlab/asama_3_mimo_model'); design_gain_schedule"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '3_9_gain_sched');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k', ...
        'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    Kg = 53.89*12.15;  wn = 33;  Kp = 0.002;  Ki_fixed = 0.1;   % Aşama 2.3

    % ── Aşama-1 ölçülen τ(duty) (CW, temiz; düşük-duty CCW stiction-outlier hariç) ──
    duty_m = [0.12 0.14 0.16 0.20 0.30 0.40 0.45];
    tau_m  = [42.9 57.2 53.5 92.2 72.4 118.6 133.7] / 1000;   % s
    % robust lineer trend τ(duty)=a+b·duty (gürültülü noktalardan)
    pp = polyfit(duty_m, tau_m, 1);  tau_fit = @(d) polyval(pp, d);
    fprintf('\n=== K3 gain scheduling ===\n');
    fprintf('τ(duty) lineer fit: τ = %.1f + %.1f·duty [ms]  (43→133 ms, 0.12→0.45)\n', pp(2)*1000, pp(1)*1000);

    % ── schedule: Ki(duty)=ωn²·τ(duty)/Kg ──
    Ki_sched = @(d) wn^2 * tau_fit(d) / Kg;
    duties = 0.10:0.05:0.50;
    fprintf('\n%-6s %-9s %-10s %-12s %-12s\n','duty','τ(ms)','Ki_sched','ωn_fixed','ωn_sched');
    for d = duties
        td = tau_fit(d);
        wn_fix = sqrt(Kg*Ki_fixed/td);  wn_sch = sqrt(Kg*Ki_sched(d)/td);
        fprintf('%-6.2f %-9.1f %-10.4f %-12.1f %-12.1f\n', d, td*1000, Ki_sched(d), wn_fix, wn_sch);
    end

    % ── kapalı-çevrim step kıyası: düşük/orta/yüksek duty ──
    dsel = [0.15 0.30 0.45]; t = (0:0.0005:0.6).';
    f=figure('Position',[40 40 1150 720],'Color','w','Visible','off');

    subplot(2,2,1); hold on; grid on; box on;   % τ(duty) veri + fit
    plot(duty_m, tau_m*1000,'o','MarkerFaceColor',[0.0 0.35 0.75],'MarkerEdgeColor','k','DisplayName','Asama-1 olcum (CW)');
    dd=0.10:0.01:0.50; plot(dd, tau_fit(dd)*1000,'-','LineWidth',1.5,'Color',[0.85 0.4 0.1],'DisplayName','lineer fit');
    xlabel('duty','Interpreter','latex'); ylabel('$\tau$ (ms)','Interpreter','latex');
    title('Measured $\tau$(duty): $\sim$3$\times$ variation drives scheduling','Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','northwest'); set(lg,'Color','w','TextColor','k');

    subplot(2,2,2); hold on; grid on; box on;   % Ki schedule + ωn
    yyaxis left;  plot(dd, wn^2*tau_fit(dd)/Kg,'LineWidth',1.6,'DisplayName','$K_i$ scheduled'); ylabel('$K_i$','Interpreter','latex');
    yline(Ki_fixed,'--','HandleVisibility','off');
    yyaxis right; plot(dd, sqrt(Kg*Ki_fixed./tau_fit(dd)),'LineWidth',1.4,'DisplayName','$\omega_n$ fixed-gain');
    plot(dd, sqrt(Kg*(wn^2*tau_fit(dd)/Kg)./tau_fit(dd)),':','LineWidth',1.6,'DisplayName','$\omega_n$ scheduled');
    ylabel('$\omega_n$ (rad/s)','Interpreter','latex'); xlabel('duty','Interpreter','latex');
    title('Schedule: $K_i\propto\tau$ keeps $\omega_n=33$ constant','Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','east'); set(lg,'Color','w','TextColor','k');

    clr = lines(3);
    subplot(2,2,3); hold on; grid on; box on;   % FIXED gain step
    for i=1:3
        td=tau_fit(dsel(i)); G=tf(Kg,[td 1]); C=pid(Kp,Ki_fixed); T=feedback(G*C,1);
        plot(t, step(T,t),'LineWidth',1.4,'Color',clr(i,:),'DisplayName',sprintf('duty %.2f ($\\tau$=%.0fms)',dsel(i),td*1000));
    end
    yline(1,'k:','HandleVisibility','off'); xlabel('time (s)','Interpreter','latex'); ylabel('$\omega/\omega_{ref}$','Interpreter','latex');
    title('FIXED gain ($K_i$=0.1): response VARIES with duty','Interpreter','latex','FontSize',11); ylim([0 1.4]);
    lg=legend('Interpreter','latex','Location','southeast'); set(lg,'Color','w','TextColor','k');

    subplot(2,2,4); hold on; grid on; box on;   % SCHEDULED gain step
    for i=1:3
        td=tau_fit(dsel(i)); G=tf(Kg,[td 1]); C=pid(Kp,Ki_sched(dsel(i))); T=feedback(G*C,1);
        plot(t, step(T,t),'LineWidth',1.4,'Color',clr(i,:),'DisplayName',sprintf('duty %.2f ($\\tau$=%.0fms)',dsel(i),td*1000));
    end
    yline(1,'k:','HandleVisibility','off'); xlabel('time (s)','Interpreter','latex'); ylabel('$\omega/\omega_{ref}$','Interpreter','latex');
    title('SCHEDULED ($K_i\propto\tau$): consistent $\omega_n$ across duty','Interpreter','latex','FontSize',11); ylim([0 1.4]);
    lg=legend('Interpreter','latex','Location','southeast'); set(lg,'Color','w','TextColor','k');

    sgtitle('Asama 3.9 (K3): Duty-indexed gain scheduling (from measured $\tau$(duty))','Interpreter','latex','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'gain_schedule.png'),'Resolution',150); close(f);

    % ── lookup tablosu (firmware'e aktarılabilir) + JSON ──
    dt_lut = 0.10:0.05:0.50; lut_tau = tau_fit(dt_lut); lut_ki = arrayfun(Ki_sched, dt_lut);
    rec = struct('Kg',Kg,'wn_target',wn,'Kp_fixed',Kp,'Ki_fixed_baseline',Ki_fixed, ...
        'tau_fit_a_ms',pp(2)*1000,'tau_fit_b_ms_per_duty',pp(1)*1000, ...
        'lut_duty',dt_lut,'lut_tau_ms',round(lut_tau*1000,1),'lut_Ki',round(lut_ki,4), ...
        'note','Kp sabit (doyum); Ki scheduled ωn=33 sabit. Tam ζ sabitliği Kp>0.002 ister (doyum tavizi).', ...
        'kaynak',{{'Franklin2010 §6,§11.3','AstromMurray2008 §11','Asama-1 fit_report.md'}});
    fid=fopen(fullfile(outdir,'gain_schedule_params.json'),'w'); fwrite(fid,jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('\nLUT (duty→Ki): '); fprintf('%.0f→%.3f  ', [dt_lut*100; lut_ki]); fprintf('\n');
    fprintf('Çıktı: %s/ (gain_schedule.png + .json)\n', outdir);
end
