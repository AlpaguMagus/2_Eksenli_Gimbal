function plot_antiwindup_real()
% PLOT_ANTIWINDUP_REAL  Test 2.T3 gerçek motor recovery görseli.
%
% scripts/antiwindup_test.py çıktısından (artifacts/2/antiwindup/<id>/raw/data.csv)
% ω profilini çizer: wind-up platosu (450 setpoint, saturation) → recovery (50).
% Sim ON (235ms)/OFF (715ms) referans çizgileriyle karşılaştırma.
%
% Çalıştırma: matlab -batch "cd('matlab/asama_2_kontrol'); plot_antiwindup_real"

    here = fileparts(mfilename('fullpath'));
    proj = fileparts(fileparts(here));
    csv = fullfile(proj, 'artifacts','2','antiwindup','20260528_203803','raw','data.csv');
    T = readtable(csv);   % phase,setpoint,t_s,omega,u,sp_actual

    t = T.t_s; om = T.omega; sp = T.sp_actual; u = T.u;
    REC_MS = 637; SIM_ON = 235; SIM_OFF = 715;
    t_down = t(find(strcmp(T.phase,'down(recov)'),1));  % recovery başlangıcı

    set(groot, 'defaultAxesColor','w','defaultAxesXColor','k','defaultAxesYColor','k', ...
        'defaultTextColor','k','defaultAxesGridColor',[0.15 0.15 0.15],'defaultAxesGridAlpha',0.3);

    f = figure('Position',[80 80 900 520],'Color','w');

    subplot(2,1,1); hold on; grid on;
    plot(t, sp, 'k:', 'LineWidth',1.2);
    plot(t, om, 'b', 'LineWidth',1.6);
    xline(t_down, 'Color',[0.5 0.5 0.5], 'LineStyle','--');
    % recovery penceresi işareti
    xregion = [t_down, t_down + REC_MS/1000];
    yl = ylim;
    patch([xregion(1) xregion(2) xregion(2) xregion(1)], [yl(1) yl(1) yl(2) yl(2)], ...
        [1 0.9 0.6], 'EdgeColor','none', 'FaceAlpha',0.3);
    plot(t, om, 'b', 'LineWidth',1.6);   % patch üstüne tekrar
    yline(50, 'Color',[0.2 0.6 0.2], 'LineWidth',1);
    ylabel('\omega [rad/s]');
    title('Test 2.T3 — Anti-Windup Recovery (GERCEK motor, 450\rightarrow50)', 'FontWeight','bold');
    legend('setpoint','\omega (olculen)','recovery basi','recovery=637ms', ...
        'Location','northeast','TextColor','k','Color','w','EdgeColor',[0.6 0.6 0.6]);
    text(t_down+0.05, 0.55*yl(2), sprintf('recovery=%d ms\n(sim ON %d / OFF %d)', REC_MS, SIM_ON, SIM_OFF), ...
        'FontSize',9, 'Color',[0.2 0.2 0.2], 'BackgroundColor',[0.97 0.97 0.9], 'EdgeColor',[0.7 0.7 0.7]);

    subplot(2,1,2); hold on; grid on;
    plot(t, u, 'r', 'LineWidth',1.3);
    xline(t_down, 'Color',[0.5 0.5 0.5], 'LineStyle','--');
    yline(0.5,'k:'); yline(-0.5,'k:');
    ylabel('u (duty)'); xlabel('time [s]');
    text(0.3, 0.3, 'wind-up: u saturation (\pm0.5) plato boyunca', 'FontSize',9, 'Color','r');

    outdir = fullfile(here,'results','2_3_realistic_sim');
    if ~exist(outdir,'dir'); mkdir(outdir); end
    exportgraphics(f, fullfile(outdir,'antiwindup_real_recovery.png'), 'Resolution',150);
    close(f);
    fprintf('Gercek motor recovery gorseli: %s/antiwindup_real_recovery.png\n', outdir);
end
