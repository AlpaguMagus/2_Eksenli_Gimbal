function design_position_rootlocus()
% DESIGN_POSITION_ROOTLOCUS  Cascade dış döngü root locus + kapalı-çevrim
% kutup analizi — ANALİTİK türetme, rlocus DOĞRULAMA olarak.
%
% Analitik-Önce Tasarım prensibi (CLAUDE.md): kapalı-çevrim karakteristik
% denklemi elle çıkarılır, kutuplar analitik tayin edilir; `rlocus`/`pole`
% sadece doğrular. Bu, design_position_p.m'in 5× bandwidth kuralıyla seçtiği
% Kp_pos=2'yi KÖK DÜZEYİNDE gerekçelendirir.
%
% ── ANALİTİK TÜRETME ────────────────────────────────────────────────
% İç döngü (hız PI, çalışan Kp_i=0.002, Ki_i=0.1 — analitik §11.12.3):
%   Plant duty→ω:  G_d(s) = K·Vs/(τs+1),  K·Vs = 53.89·12.15 = 654.8
%   PI:            C_i(s) = Kp_i + Ki_i/s
%   İç kapalı-çevrim karakteristik denklem 1+C_i·G_d=0:
%     s(τs+1) + K·Vs(Kp_i·s + Ki_i)/s · ... → 0.0605 s² + 2.3096 s + 65.48 = 0
%     ⇒ ωn_i = √(65.48/0.0605) = 32.9 rad/s,  ζ_i = 2.3096/(2·0.0605·32.9) = 0.58
%   (§11.13.7'deki "iç ωn~33" bulgusu ANALİTİK doğrulandı; Vsupply dahil)
%
% Dış döngü:  L_o(s) = Kp_pos · T_i(s) · (1/s)   (1/s = hız→pozisyon integ.)
%   Baskın yaklaşım (iç döngü hızlı → T_i ≈ 1/(τ_eff s+1), τ_eff=2ζ_i/ωn_i=0.0353 s):
%     1 + Kp_pos/[s(τ_eff s+1)] = 0  ⇒  s² + (1/τ_eff)s + Kp_pos/τ_eff = 0
%   Breakaway (çift kök, ayrım disc=0):  Kp_pos,bp = 1/(4τ_eff) ≈ 7.1
%     Kp_pos < 7.1 → iki REEL kök (overdamped, SALINIMSIZ)
%     Kp_pos > 7.1 → KOMPLEKS kökler (salınım başlar)
%   Kp_pos = 2 (step):    ζ_o = 1/(2√(Kp_pos·τ_eff)) = 1.88 > 1 → overdamped,
%                          baskın kutup ≈ -2.1 rad/s (design ωc≈1.93 ile tutarlı) ✓
%   Kp_pos = 6 (mirror):  hâlâ < 7.1 → overdamped sınırına yakın, baskın kutup daha hızlı
%
% ── rlocus DOĞRULAMA (tam 3. derece model) ──────────────────────────
% Çalıştırma: matlab -batch "cd('matlab/asama_2_kontrol'); design_position_rootlocus"

    K = 53.89; tau = 0.0605; Vs = 12.15;
    Kp_i = 0.002; Ki_i = 0.1;

    s = tf('s');
    Gd = (K*Vs) / (tau*s + 1);        % duty → ω (lineer plant)
    Ci = Kp_i + Ki_i/s;               % hız PI
    Ti = feedback(Ci*Gd, 1);          % iç kapalı-çevrim (tam)
    L0 = Ti * (1/s);                  % dış açık-çevrim (Kp_pos hariç birim)

    % analitik baskın yaklaşım parametreleri (yorumdaki türetme)
    wn_i = sqrt(65.48/0.0605); zeta_i = 2.3096/(2*0.0605*wn_i);
    tau_eff = 2*zeta_i/wn_i;
    Kp_bp = 1/(4*tau_eff);

    % kapalı-çevrim kutupları (tam model, rlocus doğrulaması)
    p2 = pole(feedback(2*L0, 1));
    p6 = pole(feedback(6*L0, 1));

    fprintf('--- ANALİTİK ---\n');
    fprintf('İç döngü: ωn_i=%.1f rad/s, ζ_i=%.2f, τ_eff=%.4f s\n', wn_i, zeta_i, tau_eff);
    fprintf('Breakaway Kp_pos,bp = %.2f (üstünde salınım)\n', Kp_bp);
    fprintf('--- rlocus DOĞRULAMA (tam 3. derece) ---\n');
    fprintf('Kp_pos=2 kapalı-çevrim kutupları:\n'); disp(p2);
    fprintf('Kp_pos=6 kapalı-çevrim kutupları:\n'); disp(p6);

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '2_5_cascade');
    if ~exist(outdir, 'dir'); mkdir(outdir); end
    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultTextColor','k', 'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    % manuel root locus (rlocus chart legend'i beyaz tema override ediyor → elle çiz)
    kvals = linspace(0.01, 20, 800);   % k=0'da kazanç sıfır → kutup yok; küçük pozitiften başla
    locus = zeros(3, numel(kvals));
    for i = 1:numel(kvals)
        locus(:,i) = pole(feedback(kvals(i)*L0, 1));
    end
    op = pole(L0); oz = zero(L0);   % açık-çevrim kutup (x) ve sıfır (o)

    f = figure('Position', [80 80 1120 480], 'Color', 'w');

    for sp = 1:2
        subplot(1,2,sp); hold on; grid on; box on;
        hl = plot(real(locus(:)), imag(locus(:)), '.', 'Color',[0.30 0.60 0.90], 'MarkerSize',4);
        hx = plot(real(op), imag(op), 'kx', 'MarkerSize',11, 'LineWidth',1.6);
        plot(real(oz), imag(oz), 'ko', 'MarkerSize',9, 'LineWidth',1.4);
        h2 = plot(real(p2), imag(p2), 'bs', 'MarkerSize',11, 'LineWidth',2, 'MarkerFaceColor','b');
        h6 = plot(real(p6), imag(p6), 'rd', 'MarkerSize',11, 'LineWidth',2, 'MarkerFaceColor','r');
        xline(0, 'k:'); yline(0, 'k:');
        xlabel('Real axis \sigma [1/s]'); ylabel('Imag axis j\omega [1/s]');
        if sp == 1
            title('Cascade Outer Loop — Root Locus (K_{p,pos})', 'FontWeight','bold');
            legend([hl hx h2 h6], {'locus (K_{p,pos}:0\rightarrow20)','open-loop poles','K_{p,pos}=2 (step)','K_{p,pos}=6 (mirror)'}, ...
                'Location','northwest', 'TextColor','k', 'Color','w', 'EdgeColor',[0.6 0.6 0.6]);
        else
            title('Dominant region (zoom)', 'FontWeight','bold');
            xlim([-12 1]); ylim([-6 6]);
            text(-11.5, 5.2, sprintf('Analytic: overdamped for K_{p,pos} < %.1f', Kp_bp), 'FontSize',9, 'Color',[0.2 0.2 0.2]);
            text(-11.5, 4.4, 'K_{p,pos}=2 \rightarrow dominant pole \approx -2.1 (no oscillation)', 'FontSize',9, 'Color','b');
        end
    end

    exportgraphics(f, fullfile(outdir, 'cascade_rootlocus.png'), 'Resolution', 150);
    close(f);
    fprintf('Root locus görseli: %s/cascade_rootlocus.png\n', outdir);
end
