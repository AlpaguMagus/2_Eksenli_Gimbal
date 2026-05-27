function create_block_diagram()
% CREATE_BLOCK_DIAGRAM  Aşama 1 açık-çevrim motor modeli görselleri.
%
% docs/asama_1_model.md için ders-kitabı kalitesinde:
%   11_block_diagram_openloop.png — duty → sürücü → plant G(s) → ω blok diyagramı
%   12_pole_map.png               — 1. derece sistemin tek kutbu (s=-1/τ), kararlılık
%
% Açık-çevrim (KONTROLCÜSÜZ) sistem: kullanıcının istediği "sistemin
% kontrolcüler olmaksızın blok diyagramı ve denklemi". Parametreler
% Aşama 1 fit sonucundan (motor_params.json) okunur.
%
% Kaynak: [Franklin2010] §3 (1. derece sistem, kutup-zaman sabiti ilişkisi)
% Çalıştırma: matlab -batch "cd('matlab/asama_1_model'); create_block_diagram"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '20260518_011926');
    p = jsondecode(fileread(fullfile(outdir, 'motor_params.json')));
    K   = (p.K_cw + p.K_ccw) / 2;   % rad/s/V
    tau = p.tau_median_s;           % s
    Vs  = p.V_supply_V;             % V
    Vsat= p.V_sat_V;                % V

    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultAxesZColor','k', 'defaultTextColor','k', 'defaultAxesGridColor',[0.15 0.15 0.15], ...
        'defaultAxesGridAlpha',0.3);

    fig_block(outdir, K, tau, Vs, Vsat);
    fig_pole(outdir, tau);

    fprintf('Asama 1 blok diyagram + kutup haritasi uretildi: %s\n', outdir);
end

% ====================================================================
function fig_block(outdir, K, tau, Vs, Vsat)
% Açık-çevrim: duty u → [sürücü Vs·u−Vsat] → V_eff → [plant K/(τs+1)] → ω
    f = figure('Position', [100 100 920 300], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax, 'on');
    axis(ax, [0 10 0 3.2]); axis(ax, 'off');

    y0 = 1.9;
    draw_arrow(0.3, y0, 1.6, y0);
    text(0.35, y0+0.30, 'duty $u$', 'Interpreter','latex','FontSize',12);
    text(0.35, y0-0.32, '$[-1,1]$', 'Interpreter','latex','FontSize',9,'Color',[0.4 0.4 0.4]);

    draw_block(2.65, y0, 2.1, 1.05, '$V_s\,u - V_{sat}$', [0.92 0.95 1.0]);
    text(2.65, y0-0.92, 'surucu (TB6612)', 'FontSize',9,'HorizontalAlignment','center');

    draw_arrow(3.7, y0, 5.2, y0);
    text(3.95, y0+0.30, '$V_{eff}$ [V]', 'Interpreter','latex','FontSize',12);

    draw_block(6.35, y0, 2.1, 1.05, '$\frac{K}{\tau s + 1}$', [0.90 1.0 0.88]);
    text(6.35, y0-0.92, 'plant $G(s)$', 'Interpreter','latex','FontSize',10,'HorizontalAlignment','center');

    draw_arrow(7.4, y0, 9.4, y0);
    text(8.7, y0+0.30, '$\omega$ [rad/s]', 'Interpreter','latex','FontSize',12);

    % gerçek parametre kutusu
    str = sprintf('$K = %.2f$ rad/s/V,   $\\tau = %.1f$ ms,   $V_s = %.2f$ V,   $V_{sat} = %.2f$ V', ...
                  K, tau*1000, Vs, Vsat);
    text(5.0, 0.35, str, 'Interpreter','latex','FontSize',11, 'HorizontalAlignment','center', ...
         'BackgroundColor',[0.97 0.97 0.9], 'EdgeColor',[0.7 0.7 0.7], 'Margin',4);

    title(ax, 'Open-Loop Motor Model (no controller)', 'FontSize',13, 'FontWeight','bold');
    exportgraphics(f, fullfile(outdir, '11_block_diagram_openloop.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
function fig_pole(outdir, tau)
% 1. derece sistemin tek kutbu: s = -1/τ (sol yarı düzlem → kararlı)
    sigma = -1/tau;
    f = figure('Position', [100 100 560 460], 'Color', 'w');
    ax = axes; hold(ax, 'on'); grid(ax, 'on'); box on;

    % sol yarı düzlem (kararlı bölge) gölge
    xl = [1.3*sigma, -1.3*sigma]; yl = [-1.3*abs(sigma), 1.3*abs(sigma)];
    patch([xl(1) 0 0 xl(1)], [yl(1) yl(1) yl(2) yl(2)], [0.88 0.96 0.88], ...
          'EdgeColor','none', 'FaceAlpha',0.6);
    text(0.55*sigma, 0.85*yl(2), 'LHP', 'FontSize',13,'Color',[0.1 0.5 0.1],'HorizontalAlignment','center','FontWeight','bold');
    text(0.55*sigma, 0.72*yl(2), '(stable)', 'FontSize',10,'Color',[0.1 0.5 0.1],'HorizontalAlignment','center');

    % eksenler
    plot(xl, [0 0], 'k', 'LineWidth', 1);   % sigma
    plot([0 0], yl, 'k', 'LineWidth', 1);   % jw
    text(0.95*xl(2), -0.10*yl(2), '$\sigma$ (Re)', 'Interpreter','latex','FontSize',12);
    text(0.04*xl(2), 0.92*yl(2), '$j\omega$ (Im)', 'Interpreter','latex','FontSize',12);

    % kutup
    plot(sigma, 0, 'rx', 'MarkerSize', 16, 'LineWidth', 3);
    text(sigma, 0.13*yl(2), sprintf('$s = -1/\\tau = %.1f$', sigma), ...
         'Interpreter','latex','FontSize',12,'Color','r','HorizontalAlignment','center');

    xlim(xl); ylim(yl);
    xlabel('Real axis $\sigma$ [1/s]', 'Interpreter','latex','FontSize',12);
    ylabel('Imag axis $j\omega$ [1/s]', 'Interpreter','latex','FontSize',12);
    title('Pole Map: First-Order Motor (single real pole)', 'FontSize',12, 'FontWeight','bold');
    exportgraphics(f, fullfile(outdir, '12_pole_map.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
function draw_block(cx, cy, w, h, label, fc)
    rectangle('Position', [cx-w/2, cy-h/2, w, h], 'FaceColor', fc, ...
              'EdgeColor', 'k', 'LineWidth', 1.4, 'Curvature', 0.08);
    text(cx, cy, label, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
         'FontSize', 15, 'Interpreter','latex');
end

function draw_arrow(x1, y1, x2, y2)
    plot([x1 x2], [y1 y2], 'k', 'LineWidth', 1.3);
    ang = atan2(y2-y1, x2-x1);
    L = 0.22; a = 0.38;
    plot([x2, x2-L*cos(ang-a)], [y2, y2-L*sin(ang-a)], 'k', 'LineWidth', 1.3);
    plot([x2, x2-L*cos(ang+a)], [y2, y2-L*sin(ang+a)], 'k', 'LineWidth', 1.3);
end
