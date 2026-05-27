function create_filter_diagram()
% CREATE_FILTER_DIAGRAM  Aşama 0 complementary filter blok diyagramı.
%
% docs/asama_0_altyapi.md §5 için ders-tarzı blok diyagramı: gyro
% entegrasyonu (yüksek-geçiren) + ivmeölçer açısı (alçak-geçiren) füzyonu.
% Ayrık form, firmware'e birebir uyar:
%   fused[k] = α·(fused[k-1] + ω·Δt) + (1-α)·θ_accel
%
% Kaynak: [Mahony2008] (complementary filter teorisi)
% Çalıştırma: matlab -batch "cd('matlab/asama_0_altyapi'); create_filter_diagram"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results');
    if ~exist(outdir, 'dir'); mkdir(outdir); end
    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultTextColor','k');

    f = figure('Position', [80 80 1080 460], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax, 'on'); axis(ax, [0 12 0 6]); axis(ax, 'off');

    yg = 4.4;   % gyro kolu
    ya = 1.4;   % accel kolu
    ym = 3.0;   % birleşme (Σ2) yüksekliği

    % --- gyro kolu (yüksek-geçiren): ω → ×Δt → Σ1 → ×α ---
    draw_arrow(0.3, yg, 1.3, yg); text(0.25, yg+0.38, '$\omega_{gyro}$', 'Interpreter','latex','FontSize',13);
    draw_block(2.1, yg, 1.1, 0.85, '$\times\,\Delta t$', [1.0 0.95 0.85]);
    draw_arrow(2.65, yg, 3.5, yg);
    draw_sum(3.85, yg, 0.32); text(3.45, yg+0.42, '$+$','Interpreter','latex','FontSize',13); text(3.5, yg-0.55, '$+$','Interpreter','latex','FontSize',12);
    draw_arrow(4.17, yg, 5.0, yg);
    draw_block(5.6, yg, 1.0, 0.85, '$\times\,\alpha$', [0.85 0.92 1.0]);
    text(5.6, yg-0.85, 'high-pass (gyro)', 'FontSize',8,'HorizontalAlignment','center','Color',[0.3 0.3 0.3]);
    % ×α çıkışı → Σ2 üst giriş
    plot([6.1 7.3], [yg yg], 'k', 'LineWidth',1.2);
    plot([7.3 7.3], [yg ym+0.3], 'k', 'LineWidth',1.2); draw_arrowhead(7.3, ym+0.3, -pi/2);

    % --- accel kolu (alçak-geçiren): θ_accel → ×(1-α) → Σ2 alt giriş ---
    draw_arrow(0.3, ya, 1.6, ya); text(0.25, ya+0.38, '$\theta_{accel}$', 'Interpreter','latex','FontSize',13);
    draw_block(2.7, ya, 1.4, 0.85, '$\times\,(1-\alpha)$', [0.90 1.0 0.88]);
    text(2.7, ya-0.85, 'low-pass (accel)', 'FontSize',8,'HorizontalAlignment','center','Color',[0.3 0.3 0.3]);
    plot([3.4 7.3], [ya ya], 'k', 'LineWidth',1.2);
    plot([7.3 7.3], [ya ym-0.3], 'k', 'LineWidth',1.2); draw_arrowhead(7.3, ym-0.3, pi/2);

    % --- Σ2 birleşme → fused ---
    draw_sum(7.3, ym, 0.33);
    draw_arrow(7.63, ym, 9.3, ym); text(9.4, ym+0.05, '$\theta_{fused}$', 'Interpreter','latex','FontSize',14);

    % --- geri besleme: fused → z^-1 → Σ1 ikinci girişi ---
    xf = 8.5;
    plot([xf xf], [ym 0.5], 'k', 'LineWidth',1.2); plot(xf, ym, 'k.', 'MarkerSize',15);
    plot([xf 3.85], [0.5 0.5], 'k', 'LineWidth',1.2);
    draw_block(5.3, 0.5, 1.0, 0.7, '$z^{-1}$', [0.95 0.95 0.95]);
    plot([3.85 3.85], [0.5 yg-0.32], 'k', 'LineWidth',1.2); draw_arrowhead(3.85, yg-0.32, pi/2);

    title(ax, 'Complementary Filter (discrete form)', 'FontSize',13, 'FontWeight','bold');
    text(6.0, 5.5, '$\theta_{fused}[k] = \alpha\,(\theta_{fused}[k-1] + \omega\,\Delta t) + (1-\alpha)\,\theta_{accel}$', ...
         'Interpreter','latex', 'FontSize',13, 'HorizontalAlignment','center');

    exportgraphics(f, fullfile(outdir, 'complementary_filter_blockdiagram.png'), 'Resolution', 150);
    close(f);
    fprintf('Asama 0 complementary filter diyagrami uretildi: %s\n', outdir);
end

% ====================================================================
function draw_block(cx, cy, w, h, label, fc)
    rectangle('Position',[cx-w/2, cy-h/2, w, h],'FaceColor',fc,'EdgeColor','k','LineWidth',1.4,'Curvature',0.08);
    text(cx,cy,label,'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Interpreter','latex');
end
function draw_sum(cx, cy, r)
    rectangle('Position',[cx-r, cy-r, 2*r, 2*r],'Curvature',[1 1],'FaceColor','w','EdgeColor','k','LineWidth',1.4);
    text(cx,cy,'$\Sigma$','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',14,'Interpreter','latex');
end
function draw_arrow(x1, y1, x2, y2)
    plot([x1 x2],[y1 y2],'k','LineWidth',1.3); draw_arrowhead(x2,y2,atan2(y2-y1,x2-x1));
end
function draw_arrowhead(x, y, ang)
    L=0.22; a=0.38;
    plot([x, x-L*cos(ang-a)],[y, y-L*sin(ang-a)],'k','LineWidth',1.3);
    plot([x, x-L*cos(ang+a)],[y, y-L*sin(ang+a)],'k','LineWidth',1.3);
end
