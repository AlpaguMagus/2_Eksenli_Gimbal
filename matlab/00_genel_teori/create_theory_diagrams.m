function create_theory_diagrams()
% CREATE_THEORY_DIAGRAMS  Aşamalar-arası ortak kontrol teorisi görselleri.
%
% docs/00_genel_bakis.md "Ortak Kontrol Teorisi Primer'i" bölümü için
% ders-kitabı kalitesinde figürler üretir. Aşama-bağımsız (generic) —
% bütün aşamalar bu kavramlara atıf verir.
%
% NOT: Figür içi metin İngilizce teknik terim + LaTeX matematik (MATLAB
% LaTeX yorumlayıcısı Türkçe aksanı güvenilir render etmez). Asıl Türkçe
% ders anlatımı docs markdown caption'larındadır.
%
% Üretilen görseller (results/):
%   01_closed_loop_general.png  — genel kapalı-çevrim blok diyagramı
%   02_first_order_step.png     — 1. derece sistem step (τ, %63, settling)
%   03_second_order_zeta.png    — 2. derece step, ζ etkisi (overshoot/settling)
%   04_bode_concept.png         — Bode + kazanç/faz payı (GM/PM) kavramı
%
% Kaynak: [Franklin2010] §3 (dinamik model), §6 (frekans tasarımı, margins)
% Çalıştırma: matlab -batch "cd('matlab/00_genel_teori'); create_theory_diagrams"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results');
    if ~exist(outdir, 'dir'); mkdir(outdir); end

    % Beyaz tema zorla (session dark tema olabilir → ders-kitabı için beyaz zemin)
    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultAxesZColor','k', 'defaultTextColor','k', 'defaultAxesGridColor',[0.15 0.15 0.15], ...
        'defaultAxesGridAlpha',0.3, 'defaultLegendTextColor','k', 'defaultLegendColor','w');

    fig1_closed_loop(outdir);
    fig2_first_order(outdir);
    fig3_second_order(outdir);
    fig4_bode(outdir);

    fprintf('Genel teori diyagramlari uretildi: %s\n', outdir);
end

% ====================================================================
function fig1_closed_loop(outdir)
% Genel kapalı-çevrim geri besleme blok diyagramı: R → Σ → C(s) → G(s) → Y
    f = figure('Position', [100 100 880 340], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax, 'on');
    axis(ax, [0 10 0 4]); axis(ax, 'off');

    y0 = 2.5;                       % ana hat yüksekliği
    draw_arrow(0.3, y0, 1.5, y0);   text(0.35, y0+0.30, '$R(s)$', 'Interpreter','latex','FontSize',13);
    draw_sum(1.85, y0, 0.35);
    text(1.45, y0+0.40, '$+$', 'Interpreter','latex','FontSize',15);
    text(1.95, y0-0.60, '$-$', 'Interpreter','latex','FontSize',15);
    draw_arrow(2.2, y0, 3.1, y0);   text(2.45, y0+0.30, '$E(s)$', 'Interpreter','latex','FontSize',12);
    draw_block(3.95, y0, 1.7, 1.0, '$C(s)$', [0.85 0.92 1.0]);
    text(3.95, y0-0.92, 'controller', 'FontSize',10,'HorizontalAlignment','center');
    draw_arrow(4.8, y0, 5.7, y0);   text(5.0, y0+0.30, '$U(s)$', 'Interpreter','latex','FontSize',12);
    draw_block(6.55, y0, 1.7, 1.0, '$G(s)$', [0.90 1.0 0.88]);
    text(6.55, y0-0.92, 'plant (sistem)', 'FontSize',10,'HorizontalAlignment','center');
    draw_arrow(7.4, y0, 9.5, y0);   text(9.1, y0+0.30, '$Y(s)$', 'Interpreter','latex','FontSize',13);

    % Geri besleme yolu
    xfb = 8.4;                      % çıkış dalı
    plot([xfb xfb], [y0 0.9], 'k', 'LineWidth', 1.2);
    plot(xfb, y0, 'k.', 'MarkerSize', 16);
    draw_block(6.55, 0.9, 1.7, 0.85, '$H(s)$', [1.0 0.95 0.85]);
    plot([xfb 7.4], [0.9 0.9], 'k', 'LineWidth', 1.2);
    plot([5.7 1.85], [0.9 0.9], 'k', 'LineWidth', 1.2);
    plot([1.85 1.85], [0.9 y0-0.35], 'k', 'LineWidth', 1.2);
    draw_arrowhead(1.85, y0-0.35, pi/2);
    text(6.55, 0.9-0.70, 'feedback (olcum)', 'FontSize',10,'HorizontalAlignment','center');

    title(ax, 'Closed-Loop Feedback System', 'FontSize',13, 'FontWeight','bold');
    exportgraphics(f, fullfile(outdir, '01_closed_loop_general.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
function fig2_first_order(outdir)
% 1. derece sistem step yanıtı: τ, %63.2, 5τ settling kavramları
    tau = 1.0; K = 1.0;
    t = linspace(0, 6*tau, 600);
    y = K * (1 - exp(-t/tau));

    f = figure('Position', [100 100 720 460], 'Color', 'w');
    ax = axes; hold(ax, 'on'); grid(ax, 'on');
    plot(t, y, 'b', 'LineWidth', 2);
    yline(K, 'k--', 'LineWidth', 1); text(5.4*tau, K+0.03, '$y_{\infty}=K$', 'Interpreter','latex','FontSize',12);

    % τ noktası: %63.2
    plot([tau tau], [0 0.632*K], 'r--', 'LineWidth', 1.2);
    plot([0 tau], [0.632*K 0.632*K], 'r--', 'LineWidth', 1.2);
    plot(tau, 0.632*K, 'ro', 'MarkerFaceColor','r', 'MarkerSize',7);
    text(tau+0.1, 0.632*K-0.07, '$\tau$:  $y=0.632\,K$', 'Interpreter','latex','FontSize',12,'Color','r');

    % 5τ: pratik settling (~%99)
    plot([5*tau 5*tau], [0 0.993*K], 'm--', 'LineWidth', 1.0);
    text(5*tau-1.9, 0.45, '$5\tau \approx 99\%$ (settling)', 'Interpreter','latex','FontSize',11,'Color','m');

    xlabel('time $t$ [s]', 'Interpreter','latex','FontSize',12);
    ylabel('output $y(t)$', 'Interpreter','latex','FontSize',12);
    title('First-Order Step Response:  $G(s)=\frac{K}{\tau s+1}$', 'Interpreter','latex','FontSize',13);
    ylim([0 1.12]);
    exportgraphics(f, fullfile(outdir, '02_first_order_step.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
function fig3_second_order(outdir)
% 2. derece sistem step: farklı ζ → overshoot / settling kavramı
    wn = 1.0;
    zetas = [0.3, 0.707, 1.0];
    cols  = {[0.85 0.2 0.2], [0.1 0.5 0.1], [0.1 0.2 0.8]};
    labs  = {'$\zeta=0.3$ (underdamped)', '$\zeta=0.707$ (ideal)', '$\zeta=1.0$ (critical)'};
    t = linspace(0, 14, 700);

    f = figure('Position', [100 100 720 460], 'Color', 'w');
    ax = axes; hold(ax, 'on'); grid(ax, 'on');
    yline(1, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    for i = 1:numel(zetas)
        z = zetas(i);
        sys = tf(wn^2, [1, 2*z*wn, wn^2]);
        y = step(sys, t);
        plot(t, y, 'Color', cols{i}, 'LineWidth', 2, 'DisplayName', labs{i});
    end
    % overshoot işareti (ζ=0.3)
    z = 0.3; Mp = exp(-pi*z/sqrt(1-z^2));
    text(3.6, 1+Mp+0.03, sprintf('$M_p=%.0f\\%%$ overshoot', Mp*100), 'Interpreter','latex','FontSize',11,'Color',cols{1});

    legend('Interpreter','latex','FontSize',11,'Location','southeast');
    xlabel('normalized time $\omega_n t$', 'Interpreter','latex','FontSize',12);
    ylabel('output $y(t)$', 'Interpreter','latex','FontSize',12);
    title('Second-Order Step:  $G(s)=\frac{\omega_n^2}{s^2+2\zeta\omega_n s+\omega_n^2}$', 'Interpreter','latex','FontSize',13);
    ylim([0 1.65]);
    exportgraphics(f, fullfile(outdir, '03_second_order_zeta.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
function fig4_bode(outdir)
% Bode + kazanç payı (GM) / faz payı (PM) kavramı
    L = tf(20, conv([1 1], [1 4]));   % örnek açık-çevrim, makul margin
    f = figure('Position', [100 100 720 540], 'Color', 'w');
    [mag, phase, w] = bode(L); mag = squeeze(mag); phase = squeeze(phase);
    magdb = 20*log10(mag);
    [~, Pm, ~, Wcp] = margin(L);

    subplot(2,1,1); semilogx(w, magdb, 'b', 'LineWidth', 1.8); grid on; hold on;
    yline(0, 'k--');
    if isfinite(Wcp); xline(Wcp, 'r:', 'LineWidth', 1.2); end
    ylabel('Gain [dB]', 'FontSize',11);
    title('Bode Plot — Phase Margin (PM)', 'FontSize',13, 'FontWeight','bold');
    if isfinite(Wcp); text(Wcp*1.1, 5, '$\omega_{c}$ (gain crossover)', 'Interpreter','latex','FontSize',10,'Color','r'); end

    subplot(2,1,2); semilogx(w, phase, 'b', 'LineWidth', 1.8); grid on; hold on;
    yline(-180, 'k--');
    if isfinite(Wcp); xline(Wcp, 'r:', 'LineWidth', 1.2); end
    idx = find(w >= Wcp, 1);
    if ~isempty(idx)
        plot([Wcp Wcp], [-180 phase(idx)], 'm', 'LineWidth', 2);
        text(Wcp*1.1, (-180+phase(idx))/2, sprintf('$PM=%.0f^\\circ$', Pm), 'Interpreter','latex','FontSize',11,'Color','m');
    end
    ylabel('Phase [deg]', 'FontSize',11);
    xlabel('frequency $\omega$ [rad/s]', 'Interpreter','latex','FontSize',11);
    exportgraphics(f, fullfile(outdir, '04_bode_concept.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
% --- yeniden kullanılabilir blok-çizim helper'ları (data coords) ---
function draw_block(cx, cy, w, h, label, fc)
    rectangle('Position', [cx-w/2, cy-h/2, w, h], 'FaceColor', fc, ...
              'EdgeColor', 'k', 'LineWidth', 1.4, 'Curvature', 0.08);
    text(cx, cy, label, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
         'FontSize', 14, 'Interpreter','latex');
end

function draw_sum(cx, cy, r)
    rectangle('Position', [cx-r, cy-r, 2*r, 2*r], 'Curvature', [1 1], ...
              'FaceColor', 'w', 'EdgeColor', 'k', 'LineWidth', 1.4);
    text(cx, cy, '$\Sigma$', 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
         'FontSize', 15, 'Interpreter','latex');
end

function draw_arrow(x1, y1, x2, y2)
    plot([x1 x2], [y1 y2], 'k', 'LineWidth', 1.3);
    ang = atan2(y2-y1, x2-x1);
    draw_arrowhead(x2, y2, ang);
end

function draw_arrowhead(x, y, ang)
    L = 0.22; a = 0.38;
    plot([x, x-L*cos(ang-a)], [y, y-L*sin(ang-a)], 'k', 'LineWidth', 1.3);
    plot([x, x-L*cos(ang+a)], [y, y-L*sin(ang+a)], 'k', 'LineWidth', 1.3);
end
