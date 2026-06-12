function plot_bench_results()
% PLOT_BENCH_RESULTS  Aşama 3.3 K0-kapanışı bench grafikleri (ham CSV → tez-stili PNG).
%
% docs/asama_3_mimo_model.md §12.6 için gerçek-donanım kanıtı:
%   cascade_step.png  — MODE2:POS cascade pozisyon step (theta/omega/u), 6/6 PASS
%   mirror_track.png  — MODE2:MIRROR IMU pitch taklit (fp/ref/theta + err), RMS 5.53 deg
%   stab_track.png    — MODE2:STAB stabilizasyon (motor base egimine ters), RMS 6.72 deg
%
% Ham veri artifacts/3/.../raw/data.csv'den okunur (test artifact disiplini, global CLAUDE.md).
% Grafikler kalici results/3_3_bench/'e yazilir (git'te; raw/ gitignored — embed kalici kaynaktan).
%
% Kaynak: [Franklin2010] §7.3 (cascade step yaniti), §6.1 (referans takip).
% Calistirma: matlab -batch "cd('matlab/asama_3_mimo_model'); plot_bench_results"

    here = fileparts(mfilename('fullpath'));
    root = fullfile(here, '..', '..');
    outdir = fullfile(here, 'results', '3_3_bench');
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k', ...
        'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    casc = fullfile(root,'artifacts','3','cascade_m2','20260612_115042','raw','data.csv');
    mirr = fullfile(root,'artifacts','3','mirror_m2','20260612_120636','raw','data.csv');
    stab = fullfile(root,'artifacts','3','stab_m2','20260612_121945','raw','data.csv');

    plot_cascade(casc, outdir);
    plot_track(mirr, outdir, 'mirror', 'MODE2:MIRROR — IMU pitch mirror (motor follows tilt)', ...
               5.53, 'mirror_track.png');
    plot_track(stab, outdir, 'stab', 'MODE2:STAB — stabilization (motor counter-rotates tilt)', ...
               6.72, 'stab_track.png');

    fprintf('Asama 3.3 bench grafikleri uretildi: %s\n', outdir);
end

% ====================================================================
function plot_cascade(csv, outdir)
    T = readtable(csv);
    t = T.t_global; th = T.theta_deg; om = T.omega; u = T.u; sp = T.sp; tg = T.target_deg;

    f = figure('Position',[60 60 1000 720],'Color','w','Visible','off');

    % --- (1) pozisyon takip ---
    subplot(3,1,1); hold on; grid on; box on;
    stairs(t, tg, '--', 'Color',[0.85 0.2 0.2], 'LineWidth',1.3, 'DisplayName','target $\theta_{ref}$');
    plot(t, th, '-', 'Color',[0.0 0.35 0.75], 'LineWidth',1.5, 'DisplayName','output $\theta$');
    ylabel('$\theta$ (deg)','Interpreter','latex');
    title('Axis-1 (motor-2) cascade position step: 6/6 PASS (ss\_err $<1^\circ$, OS $<1^\circ$)', ...
        'Interpreter','latex','FontSize',12);
    lg=legend('Interpreter','latex','Location','best'); set(lg,'Color','w','TextColor','k');
    xlim([t(1) t(end)]);

    % --- (2) iç döngü hız ---
    subplot(3,1,2); hold on; grid on; box on;
    plot(t, sp, '--', 'Color',[0.85 0.2 0.2], 'LineWidth',1.0, 'DisplayName','speed setpoint $\omega_{ref}$');
    plot(t, om, '-', 'Color',[0.0 0.35 0.75], 'LineWidth',1.2, 'DisplayName','speed $\omega$');
    ylabel('$\omega$ (rad/s)','Interpreter','latex');
    title('Inner speed loop (cascade outer $\rightarrow$ speed reference)','Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','best'); set(lg,'Color','w','TextColor','k');
    xlim([t(1) t(end)]);

    % --- (3) kontrol sinyali ---
    subplot(3,1,3); hold on; grid on; box on;
    plot(t, u, '-', 'Color',[0.2 0.5 0.2], 'LineWidth',1.2);
    yline( 0.50, ':', 'duty cap $+0.50$','Interpreter','latex','Color',[0.6 0.3 0.3]);
    yline(-0.50, ':', 'duty cap $-0.50$','Interpreter','latex','Color',[0.6 0.3 0.3]);
    ylabel('$u$ (duty)','Interpreter','latex'); xlabel('time (s)','Interpreter','latex');
    title('Applied duty (saturation-aware inner PI)','Interpreter','latex','FontSize',11);
    ylim([-0.6 0.6]); xlim([t(1) t(end)]);

    sgtitle('Asama 3.3 — Axis-1 Cascade Position Step (real hardware, free shaft)', ...
        'FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'cascade_step.png'),'Resolution',150);
    close(f);
end

% ====================================================================
function plot_track(csv, outdir, mode, ttl, rms_meas, fname)
    T = readtable(csv);
    t = T.t; fp = T.fp; tr = T.tr; th = T.theta_deg; err = T.err;

    f = figure('Position',[60 60 1000 560],'Color','w','Visible','off');

    % --- (1) takip ---
    subplot(2,1,1); hold on; grid on; box on;
    plot(t, fp, '-', 'Color',[0.55 0.55 0.55], 'LineWidth',1.0, 'DisplayName','IMU pitch (base tilt)');
    plot(t, tr, '--', 'Color',[0.85 0.2 0.2], 'LineWidth',1.2, 'DisplayName','reference $\theta_{ref}$');
    plot(t, th, '-', 'Color',[0.0 0.35 0.75], 'LineWidth',1.5, 'DisplayName','motor $\theta$');
    ylabel('angle (deg)','Interpreter','latex');
    title(ttl,'Interpreter','none','FontSize',12);
    lg=legend('Interpreter','latex','Location','southeast'); set(lg,'Color','w','TextColor','k');
    xlim([t(1) t(end)]);

    if strcmp(mode,'stab')
        % karşı-korelasyon vurgusu: corr(fp, theta) < 0
        cc = corrcoef(fp, th); c = cc(1,2);   % corrcoef base MATLAB'da (corr Statistics Toolbox ister)
        text(0.015, 0.93, sprintf('corr(pitch, $\\theta$) = %.2f  (anti-correlated $\\Rightarrow$ counter-rotation)', c), ...
            'Units','normalized','Interpreter','latex','FontSize',10, ...
            'VerticalAlignment','top','HorizontalAlignment','left', ...
            'BackgroundColor',[0.95 0.95 1.0],'EdgeColor',[0.6 0.6 0.7]);
    end

    % --- (2) takip hatası ---
    subplot(2,1,2); hold on; grid on; box on;
    plot(t, err, '-', 'Color',[0.5 0.25 0.55], 'LineWidth',1.1);
    yline(0,'k:');
    rms_calc = sqrt(mean(err.^2));
    ylabel('error $\theta-\theta_{ref}$ (deg)','Interpreter','latex'); xlabel('time (s)','Interpreter','latex');
    title(sprintf('Tracking error: RMS %.2f$^\\circ$ (summary %.2f$^\\circ$), max $|e|$ %.1f$^\\circ$', ...
        rms_calc, rms_meas, max(abs(err))),'Interpreter','latex','FontSize',11);
    xlim([t(1) t(end)]);

    sgtitle(sprintf('Asama 3.3 — Axis-1 %s tracking (real hardware, IMU on base)', upper(mode)), ...
        'FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,fname),'Resolution',150);
    close(f);
end
