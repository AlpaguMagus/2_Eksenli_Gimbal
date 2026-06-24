function create_axis_architecture_diagram()
% CREATE_AXIS_ARCHITECTURE_DIAGRAM  Aşama 3.3 instance-based eksen mimarisi görselleri.
%
% docs/asama_3_mimo_model.md §12.6 (K0 kapanışı) için ders-kitabı kalitesinde:
%   eksen_mimari.png    — decentralized g_axis[2]: ortak komut ayrıştırıcı → 2 bağımsız
%                         cascade ekseni (Axis 0 = motor-1 DEVRE DIŞI gri; Axis 1 = motor-2
%                         AKTİF). Köşegen K(s) — çapraz kontrolcü terimi YOK.
%   mirror_stab_law.png — IMU pitch → işaret bloğu (mirror +1, stab −1) → cascade referansı.
%                         Tek-eksen taklit/stabilizasyon yasasının farkı = referans işareti.
%
% Kontrol Merdiveni K0/K1: cascade = MIMO K(s)'in köşegen (decentralized) formu
%   ([Skogestad2005] §10.6.4). Tek eksen (K0) ve iki eksen (K1) AYNI yapı, eksen sayısı farkı.
%
% Kaynak: [Skogestad2005] §10.6.4 (decentralized control, diyagonal K), [Franklin2010] §7.3 (cascade)
% Çalıştırma: matlab -batch "cd('matlab/asama_3_mimo_model'); create_axis_architecture_diagram"

    here = fileparts(mfilename('fullpath'));
    out1 = fullfile(here, 'results', '3_3_eksen_mimari');
    out2 = fullfile(here, 'results', '3_3_bench');
    if ~exist(out1, 'dir'), mkdir(out1); end
    if ~exist(out2, 'dir'), mkdir(out2); end

    % Beyaz tema zorla (dark session'da axes siyah kalır — CLAUDE.md figür disiplini)
    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultAxesZColor','k', ...
        'defaultTextColor','k', 'defaultAxesGridColor',[0.15 0.15 0.15], ...
        'defaultAxesGridAlpha',0.3);

    fig_architecture(out1);
    fig_mirror_stab_law(out2);

    fprintf('Asama 3.3 mimari diyagramlari uretildi:\n  %s\n  %s\n', out1, out2);
end

% ====================================================================
function fig_architecture(outdir)
% Decentralized 2-eksen: ortak parser → iki bağımsız cascade satırı.
    f = figure('Position', [60 60 1180 560], 'Color', 'w', 'Visible','off');
    ax = axes('Position', [0 0 1 1]); hold(ax, 'on');
    axis(ax, [0 13.0 0 6.4]); axis(ax, 'off');

    % renkler
    cAct  = [0.90 1.00 0.88];   % aktif eksen blok dolgusu (yeşilimsi)
    cCtrl = [0.92 0.95 1.00];   % kontrolcü blok (mavimsi)
    cDis  = [0.90 0.90 0.90];   % devre-dışı eksen (gri)
    gray  = [0.55 0.55 0.55];

    % ---- ortak komut ayrıştırıcı ----
    draw_block(1.25, 3.2, 1.9, 1.2, '\texttt{cmd\_parser}', [1.0 0.96 0.85]);
    text(1.25, 3.2-0.78, 'kök / `2` soneki', 'FontSize',9,'HorizontalAlignment','center');
    text(0.15, 3.7, 'UART komut', 'FontSize',10);
    draw_arrow(0.15, 3.45, 0.30, 3.45);

    % satır y konumları
    yA = 5.1;   % Axis 0 (motor-1) — devre dışı
    yB = 1.5;   % Axis 1 (motor-2) — aktif

    % parser → her iki eksen (route)
    draw_arrow(2.20, 3.4, 2.7, yA-0.0); draw_arrow(2.7, yA, 3.0, yA);
    draw_arrow(2.20, 3.0, 2.7, yB-0.0); draw_arrow(2.7, yB, 3.0, yB);

    % ====== Axis 0 satırı (motor-1, DEVRE DIŞI) ======
    draw_axis_row(yA, cDis, cDis, gray, true, ...
        'Axis 0  (g\_axis[0])', 'Motor1 (PB12/13)', 'Enc0 / TIM2');
    text(11.95, yA+0.95, 'DEVRE DISI', 'FontSize',11,'FontWeight','bold', ...
        'Color',[0.75 0.2 0.2],'HorizontalAlignment','right');
    text(11.95, yA+0.62, '(motor-1 CW mekanik kusur)', 'FontSize',8.5, ...
        'Color',gray,'HorizontalAlignment','right');

    % ====== Axis 1 satırı (motor-2, AKTİF) ======
    draw_axis_row(yB, cCtrl, cAct, [0 0 0], false, ...
        'Axis 1  (g\_axis[1])', 'Motor2 (PB4/5)', 'Enc1 / TIM1');
    text(11.95, yB-1.02, 'AKTIF (tek saglam motor)', 'FontSize',11,'FontWeight','bold', ...
        'Color',[0.1 0.55 0.1],'HorizontalAlignment','right');

    % köşegen K(s) notu (em-dash / \S MATLAB-LaTeX'te yasak — ref markdown caption'da)
    str = ['Decentralized:  $K(s) = \mathrm{diag}\left(K_0(s),\,K_1(s)\right)$' ...
           '   (diagonal $K$, no cross-controller term)   [K0 / K1]'];
    text(6.5, 0.30, str, 'Interpreter','latex','FontSize',11.5, ...
        'HorizontalAlignment','center', 'BackgroundColor',[0.97 0.97 0.9], ...
        'EdgeColor',[0.7 0.7 0.7], 'Margin',5);

    title(ax, 'Instance-based 2-Axis Architecture (g\_axis[2]) — decentralized cascade', ...
        'FontSize',13, 'FontWeight','bold');
    exportgraphics(f, fullfile(outdir, 'eksen_mimari.png'), 'Resolution', 150);
    close(f);
end

% --------------------------------------------------------------------
function draw_axis_row(y, cCtrl, cMot, txtColor, dimmed, axlabel, motlabel, enclabel)
% Tek cascade satırı: PositionP → SpeedPI → MotorCh → [Motor] → Encoder geri besleme.
    lw = 1.4; if dimmed, lw = 1.0; end
    % eksen etiketi (sol)
    text(3.0, y+1.05, axlabel, 'Interpreter','tex','FontSize',10.5, ...
        'FontWeight','bold','Color',txtColor);

    % bloklar
    bx = [3.95, 6.05, 8.15];  bw = 1.55; bh = 0.95;
    draw_block_c(bx(1), y, bw, bh, '$P_{pos}$', cCtrl, txtColor, lw);
    text(bx(1), y-0.72, 'PositionP', 'FontSize',8.5,'HorizontalAlignment','center','Color',txtColor);
    draw_block_c(bx(2), y, bw, bh, 'PI', cCtrl, txtColor, lw);
    text(bx(2), y-0.72, 'SpeedPI', 'FontSize',8.5,'HorizontalAlignment','center','Color',txtColor);
    draw_block_c(bx(3), y, bw, bh, 'PWM', cMot, txtColor, lw);
    text(bx(3), y-0.72, 'MotorCh', 'FontSize',8.5,'HorizontalAlignment','center','Color',txtColor);

    % motor + encoder
    draw_block_c(10.35, y, 1.5, bh, motlabel_short(motlabel), cMot, txtColor, lw);

    % bağlantı okları
    draw_arrow_c(3.0,  y, bx(1)-bw/2, y, txtColor, lw);
    text(3.05, y+0.30, '$\theta_{ref}$', 'Interpreter','latex','FontSize',10,'Color',txtColor);
    draw_arrow_c(bx(1)+bw/2, y, bx(2)-bw/2, y, txtColor, lw);
    text(bx(1)+bw/2+0.02, y+0.28, '$\omega_{ref}$', 'Interpreter','latex','FontSize',9,'Color',txtColor);
    draw_arrow_c(bx(2)+bw/2, y, bx(3)-bw/2, y, txtColor, lw);
    text(bx(2)+bw/2+0.02, y+0.28, '$u$', 'Interpreter','latex','FontSize',9,'Color',txtColor);
    draw_arrow_c(bx(3)+bw/2, y, 10.35-0.75, y, txtColor, lw);

    % motor çıkışı + encoder geri besleme (alttan dönen)
    draw_arrow_c(10.35+0.75, y, 12.4, y, txtColor, lw);
    text(11.4, y+0.30, '$\theta$', 'Interpreter','latex','FontSize',11,'Color',txtColor);
    % geri besleme yolu
    plot([12.1 12.1], [y y-0.55], '-', 'Color',txtColor,'LineWidth',lw);
    plot([12.1 3.55], [y-0.55 y-0.55], '-', 'Color',txtColor,'LineWidth',lw);
    draw_arrow_c(3.55, y-0.55, 3.55, y-bh/2, txtColor, lw);
    text(7.6, y-0.55+0.16, ['encoder geri besleme  (' enclabel ')'], ...
        'FontSize',8.5,'HorizontalAlignment','center','Color',txtColor);
end

function s = motlabel_short(~)
    s = 'TB6612';
end

% ====================================================================
function fig_mirror_stab_law(outdir)
% IMU pitch → relative → işaret (mirror +1 / stab −1) → clamp/slew → cascade.
    f = figure('Position', [60 60 1080 360], 'Color', 'w', 'Visible','off');
    ax = axes('Position', [0 0 1 1]); hold(ax, 'on');
    axis(ax, [0 12.0 0 4.0]); axis(ax, 'off');

    y0 = 2.35;
    cBlk = [0.92 0.95 1.0]; cSel = [1.0 0.95 0.82]; cCas = [0.90 1.0 0.88];

    % IMU
    draw_block(1.05, y0, 1.7, 1.1, 'IMU', [0.95 0.92 1.0]);
    text(1.05, y0-0.78, 'MPU6050 (fused pitch)', 'FontSize',8.5,'HorizontalAlignment','center');
    draw_arrow(1.90, y0, 3.05, y0);
    text(2.05, y0+0.28, '$\theta_{pitch}$', 'Interpreter','latex','FontSize',11);

    % relative (mode entry pitch0 çıkar)
    draw_block(3.95, y0, 1.75, 1.1, '$-\,\theta_{0}$', cBlk);
    text(3.95, y0-0.78, 'rel = pitch - pitch0', 'FontSize',8.5,'HorizontalAlignment','center');
    draw_arrow(4.82, y0, 6.0, y0);
    text(5.0, y0+0.30, 'rel', 'FontSize',10);

    % işaret seçici (mirror/stab)
    draw_block(6.95, y0, 1.85, 1.25, '$s_m \cdot \mathrm{rel}$', cSel);
    text(6.95, y0+1.02, 'MIRROR: $s_m=+1$', 'Interpreter','latex','FontSize',9.5, ...
        'HorizontalAlignment','center','Color',[0.1 0.45 0.1]);
    text(6.95, y0-0.80, 'STAB: $s_m=-1$ (karsi)', 'Interpreter','latex','FontSize',9.5, ...
        'HorizontalAlignment','center','Color',[0.2 0.2 0.7]);
    draw_arrow(7.88, y0, 9.0, y0);
    text(8.05, y0+0.30, '$\theta_{ref}$', 'Interpreter','latex','FontSize',11);

    % clamp/slew + cascade
    draw_block(9.95, y0, 1.85, 1.25, 'clamp/slew', cBlk);
    text(9.95, y0-0.82, '$\pm 60^\circ$, $90^\circ$/s', 'Interpreter','latex', ...
        'FontSize',9,'HorizontalAlignment','center');
    draw_arrow(10.88, y0, 11.85, y0);
    text(11.0, y0+0.30, '$\rightarrow$ cascade', 'Interpreter','latex','FontSize',10);

    str = ['Tek-eksen yasa: $\theta_{ref} = s_m\,(\theta_{pitch}-\theta_0)$, ' ...
           '$\;s_m=+1$ taklit (mirror), $s_m=-1$ stabilizasyon (motor base egimine ters doner).'];
    text(6.0, 0.42, str, 'Interpreter','latex','FontSize',11, ...
        'HorizontalAlignment','center', 'BackgroundColor',[0.97 0.97 0.9], ...
        'EdgeColor',[0.7 0.7 0.7], 'Margin',5);

    title(ax, 'Single-Axis Mirror / Stabilization Law (sign select) — feeds the cascade', ...
        'FontSize',13, 'FontWeight','bold');
    exportgraphics(f, fullfile(outdir, 'mirror_stab_law.png'), 'Resolution', 150);
    close(f);
end

% ====================================================================
% Ortak çizim helper'ları (asama_1 create_block_diagram stili)
% ====================================================================
function draw_block(cx, cy, w, h, label, fc)
    rectangle('Position', [cx-w/2, cy-h/2, w, h], 'FaceColor', fc, ...
              'EdgeColor', 'k', 'LineWidth', 1.4, 'Curvature', 0.10);
    text(cx, cy, label, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
         'FontSize', 14, 'Interpreter','latex');
end

function draw_block_c(cx, cy, w, h, label, fc, ec, lw)
    rectangle('Position', [cx-w/2, cy-h/2, w, h], 'FaceColor', fc, ...
              'EdgeColor', ec, 'LineWidth', lw, 'Curvature', 0.12);
    text(cx, cy, label, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
         'FontSize', 13, 'Interpreter','latex', 'Color', ec);
end

function draw_arrow(x1, y1, x2, y2)
    draw_arrow_c(x1, y1, x2, y2, [0 0 0], 1.3);
end

function draw_arrow_c(x1, y1, x2, y2, c, lw)
    plot([x1 x2], [y1 y2], '-', 'Color', c, 'LineWidth', lw);
    ang = atan2(y2-y1, x2-x1);
    L = 0.20; a = 0.38;
    plot([x2, x2-L*cos(ang-a)], [y2, y2-L*sin(ang-a)], '-', 'Color', c, 'LineWidth', lw);
    plot([x2, x2-L*cos(ang+a)], [y2, y2-L*sin(ang+a)], '-', 'Color', c, 'LineWidth', lw);
end
