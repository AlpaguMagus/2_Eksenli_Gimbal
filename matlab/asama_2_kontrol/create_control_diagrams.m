function create_control_diagrams()
% CREATE_CONTROL_DIAGRAMS  Aşama 2 kontrolcü blok diyagramları (ders-tarzı).
%
% docs/asama_2_kontrol.md için ders-kitabı kalitesinde kapalı-çevrim
% blok diyagramları (genel_bakis/Aşama 1 ile tutarlı stil). Mevcut
% Simulink screenshot'larını (cascade_block_diagram.png) tamamlar —
% bunlar transfer-fonksiyon seviyesi temiz anlatım içindir.
%
% Üretilen:
%   results/2_1_speed_pi/04_speed_pi_blockdiagram.png  — hız PI kapalı çevrim
%   results/2_5_cascade/cascade_textbook_diagram.png   — cascade (çift döngü)
%   results/2_7_mirror/mirror_blockdiagram.png         — IMU mirror takip
%
% Kaynak: [Franklin2010] §6.4 (cascade), [AstromMurray2008] §10 (PID+anti-windup)
% Çalıştırma: matlab -batch "cd('matlab/asama_2_kontrol'); create_control_diagrams"

    here = fileparts(mfilename('fullpath'));
    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultTextColor','k');

    fig_speed_pi(fullfile(here, 'results', '2_1_speed_pi'));
    fig_disturbance(fullfile(here, 'results', '2_4_disturbance'));
    fig_cascade(fullfile(here, 'results', '2_5_cascade'));
    fig_mirror(fullfile(here, 'results', '2_7_mirror'));

    fprintf('Asama 2 kontrol diyagramlari uretildi.\n');
end

% ====================================================================
function fig_disturbance(outdir)
% Hız PI + bozucu (disturbance d) giriş noktası: yük torku plant girişinde.
% ω_ref → Σ → PI → Σ_d(+d) → plant → ω ; geri besleme. Y(s)/D(s)=G/(1+CG)=G·S
    if ~exist(outdir,'dir'); mkdir(outdir); end
    f = figure('Position', [80 80 1080 360], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax,'on'); axis(ax,[0 15 0 4.5]); axis(ax,'off');
    y = 2.6;
    draw_arrow(0.3,y, 1.5,y); text(0.3,y+0.35,'$\omega_{ref}$','Interpreter','latex','FontSize',13);
    draw_sum(1.85,y,0.33); text(1.4,y+0.45,'$+$','Interpreter','latex','FontSize',13); text(1.95,y-0.55,'$-$','Interpreter','latex','FontSize',13);
    draw_arrow(2.18,y, 3.1,y); text(2.35,y+0.32,'$e$','Interpreter','latex','FontSize',12);
    draw_block(4.0,y,1.6,1.0,'$K_p+\frac{K_i}{s}$',[0.85 0.92 1.0]); text(4.0,y-0.92,'PI','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(4.8,y, 6.0,y);
    % disturbance toplama noktası
    draw_sum(6.4,y,0.33); text(6.0,y+0.45,'$+$','Interpreter','latex','FontSize',13);
    % d yukarıdan girer
    draw_arrow(6.4,4.0, 6.4,y+0.33); text(6.15,4.15,'$d$ (yuk)','Interpreter','latex','FontSize',12,'Color',[0.7 0.2 0.2]);
    draw_arrow(6.73,y, 7.9,y);
    draw_block(9.0,y,2.0,1.0,'$\frac{K\,V_s}{\tau s+1}$',[0.90 1.0 0.88]); text(9.0,y-0.92,'plant','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(10.0,y, 13.6,y); text(12.3,y+0.35,'$\omega$','Interpreter','latex','FontSize',13);
    % geri besleme
    xf=12.0; plot([xf xf],[y 0.9],'k','LineWidth',1.2); plot(xf,y,'k.','MarkerSize',15);
    plot([xf 1.85],[0.9 0.9],'k','LineWidth',1.2); plot([1.85 1.85],[0.9 y-0.33],'k','LineWidth',1.2); draw_arrowhead(1.85,y-0.33,pi/2);
    text(7.0,0.55,'encoder feedback ($\omega$)','Interpreter','latex','FontSize',10,'HorizontalAlignment','center');
    title(ax,'Disturbance Rejection: load d at plant input','FontSize',13,'FontWeight','bold');
    text(7.5,3.9,'$Y/D = G/(1+CG) = G\,S$','Interpreter','latex','FontSize',11,'HorizontalAlignment','center','Color',[0.3 0.3 0.3]);
    exportgraphics(f, fullfile(outdir,'disturbance_block.png'), 'Resolution',150); close(f);
end

% ====================================================================
function fig_speed_pi(outdir)
% Hız PI kapalı çevrim (iç döngü):
% ω_ref → Σ → [Kp+Ki/s] → [sat ±0.5] → [Vs·u−Vsat] → [K/(τs+1)] → ω
    if ~exist(outdir,'dir'); mkdir(outdir); end
    f = figure('Position', [80 80 1180 340], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax,'on'); axis(ax,[0 16 0 4]); axis(ax,'off');
    y = 2.6;
    draw_arrow(0.3,y, 1.5,y); text(0.3,y+0.35,'$\omega_{ref}$','Interpreter','latex','FontSize',13);
    draw_sum(1.85,y,0.35); text(1.4,y+0.45,'$+$','Interpreter','latex','FontSize',14); text(1.95,y-0.6,'$-$','Interpreter','latex','FontSize',14);
    draw_arrow(2.2,y, 3.2,y); text(2.4,y+0.32,'$e$','Interpreter','latex','FontSize',12);
    draw_block(4.0,y,1.7,1.0,'$K_p+\frac{K_i}{s}$',[0.85 0.92 1.0]); text(4.0,y-0.95,'PI','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(4.85,y, 5.8,y);
    draw_block(6.55,y,1.5,1.0,'sat $\pm0.5$',[1.0 0.92 0.88]); text(6.55,y-0.95,'doygunluk','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(7.3,y, 8.2,y); text(7.45,y+0.32,'$u$','Interpreter','latex','FontSize',12);
    draw_block(9.0,y,1.7,1.0,'$V_s u - V_{sat}$',[0.92 0.95 1.0]); text(9.0,y-0.95,'surucu','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(9.85,y, 10.9,y); text(10.0,y+0.32,'$V_{eff}$','Interpreter','latex','FontSize',11);
    draw_block(11.75,y,1.7,1.0,'$\frac{K}{\tau s+1}$',[0.90 1.0 0.88]); text(11.75,y-0.95,'plant','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(12.6,y, 15.3,y); text(14.6,y+0.35,'$\omega$','Interpreter','latex','FontSize',13);
    % geri besleme (encoder ölçümü)
    xf = 13.7; plot([xf xf],[y 0.9],'k','LineWidth',1.2); plot(xf,y,'k.','MarkerSize',15);
    plot([xf 1.85],[0.9 0.9],'k','LineWidth',1.2);
    plot([1.85 1.85],[0.9 y-0.35],'k','LineWidth',1.2); draw_arrowhead(1.85,y-0.35,pi/2);
    text(7.5,0.55,'encoder measurement ($\omega$)','Interpreter','latex','FontSize',10,'HorizontalAlignment','center');
    title(ax,'Speed PI Inner Loop (closed-loop)','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'04_speed_pi_blockdiagram.png'), 'Resolution',150); close(f);
end

% ====================================================================
function fig_cascade(outdir)
% Cascade: dış pozisyon P + iç hız PI (iç içe iki döngü)
% θ_ref→Σ1→[Kp_pos]→ω_ref→Σ2→[PI]→[sat·sürücü·plant=hız]→ω→[1/s]→θ
    if ~exist(outdir,'dir'); mkdir(outdir); end
    f = figure('Position', [60 60 1280 420], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax,'on'); axis(ax,[0 17 0 5]); axis(ax,'off');
    y = 3.4;
    draw_arrow(0.3,y, 1.4,y); text(0.25,y+0.35,'$\theta_{ref}$','Interpreter','latex','FontSize',13);
    draw_sum(1.75,y,0.33); text(1.3,y+0.45,'$+$','Interpreter','latex','FontSize',13); text(1.85,y-0.55,'$-$','Interpreter','latex','FontSize',13);
    draw_arrow(2.08,y, 2.9,y);
    draw_block(3.7,y,1.5,0.95,'$K_{p,pos}$',[0.82 0.88 1.0]); text(3.7,y-0.85,'poz P (dis)','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(4.45,y, 5.3,y); text(4.55,y+0.32,'$\omega_{ref}$','Interpreter','latex','FontSize',11);
    draw_sum(5.65,y,0.33); text(5.2,y+0.45,'$+$','Interpreter','latex','FontSize',13); text(5.75,y-0.55,'$-$','Interpreter','latex','FontSize',13);
    draw_arrow(5.98,y, 6.8,y);
    draw_block(7.7,y,1.6,0.95,'$K_p+\frac{K_i}{s}$',[0.85 0.92 1.0]); text(7.7,y-0.85,'hiz PI (ic)','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(8.5,y, 9.4,y);
    draw_block(10.5,y,1.9,0.95,'sat $\to$ plant',[0.90 1.0 0.88]); text(10.5,y-0.85,'$\frac{K}{\tau s+1}$ (hiz)','Interpreter','latex','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(11.45,y, 12.3,y); text(11.6,y+0.32,'$\omega$','Interpreter','latex','FontSize',12);
    draw_block(13.1,y,1.3,0.95,'$\frac{1}{s}$',[1.0 0.97 0.85]); text(13.1,y-0.85,'integ.','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(13.75,y, 16.3,y); text(15.4,y+0.35,'$\theta$','Interpreter','latex','FontSize',13);
    % iç döngü geri besleme (ω → Σ2)
    xi = 12.0; plot([xi xi],[y 1.9],'k','LineWidth',1.1); plot(xi,y,'k.','MarkerSize',13);
    plot([xi 5.65],[1.9 1.9],'k','LineWidth',1.1); plot([5.65 5.65],[1.9 y-0.33],'k','LineWidth',1.1); draw_arrowhead(5.65,y-0.33,pi/2);
    text(8.8,1.55,'inner loop: speed $\omega$','Interpreter','latex','FontSize',9,'HorizontalAlignment','center','Color',[0.2 0.2 0.6]);
    % dış döngü geri besleme (θ → Σ1)
    xo = 14.8; plot([xo xo],[y 0.7],'k','LineWidth',1.2); plot(xo,y,'k.','MarkerSize',15);
    plot([xo 1.75],[0.7 0.7],'k','LineWidth',1.2); plot([1.75 1.75],[0.7 y-0.33],'k','LineWidth',1.2); draw_arrowhead(1.75,y-0.33,pi/2);
    text(8.0,0.35,'outer loop: position $\theta$ (output shaft)','Interpreter','latex','FontSize',9,'HorizontalAlignment','center','Color',[0.6 0.2 0.2]);
    title(ax,'Cascade Position Control: outer P + inner PI','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'cascade_textbook_diagram.png'), 'Resolution',150); close(f);
end

% ====================================================================
function fig_mirror(outdir)
% IMU mirror: complementary filter → fused_pitch → ref → cascade → θ
    if ~exist(outdir,'dir'); mkdir(outdir); end
    f = figure('Position', [80 80 1180 360], 'Color', 'w');
    ax = axes('Position', [0 0 1 1]); hold(ax,'on'); axis(ax,[0 16 0 4]); axis(ax,'off');
    y = 2.4;
    draw_block(1.7,y,2.4,1.1,'IMU + filtre',[1.0 0.95 0.85]); text(1.7,y-1.0,'complementary','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(2.9,y, 4.0,y); text(2.9,y+0.35,'fused pitch','FontSize',10);
    draw_block(5.1,y,2.0,1.1,'$-p_0$, clamp, slew',[0.95 0.92 1.0]); text(5.1,y-1.0,'ref gen.','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(6.1,y, 7.2,y); text(6.2,y+0.35,'$\theta_{ref}$','Interpreter','latex','FontSize',12);
    draw_block(8.6,y,2.4,1.1,'CASCADE',[0.88 0.96 0.90]); text(8.6,y-1.0,'pos P + speed PI (sec 11.13)','FontSize',9,'HorizontalAlignment','center');
    draw_arrow(9.8,y, 11.0,y);
    draw_block(12.0,y,1.8,1.1,'motor',[0.90 0.93 0.96]);
    draw_arrow(12.9,y, 15.3,y); text(13.9,y+0.35,'$\theta$ (shaft)','Interpreter','latex','FontSize',12);
    text(8.0,0.5,'Motor tracks IMU pitch in the same direction (mirror).','FontSize',10,'HorizontalAlignment','center');
    title(ax,'IMU Mirror Tracking (live reference = fused pitch)','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'mirror_blockdiagram.png'), 'Resolution',150); close(f);
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
