function design_speed_margin_empirical()
% DESIGN_SPEED_MARGIN_EMPIRICAL  Test 2.T1 — ampirik (çalışan) hız PI
% kazancının kararlılık marjı. ANALİTİK PM + margin() doğrulama.
%
% KRİTİK BAĞLAM: Aşama 2.1 conservative kazancı (Kp=0.1163) plant'ı V_eff→ω
% (K=53.89) varsayarak tasarlandı. Ama firmware PI çıkışı *duty*; gerçek plant
% duty→ω = K·Vs/(τs+1), K·Vs=654.8 — yani 12.15× daha yüksek kazanç. Conservative
% kazanç firmware plant'ında devasa kazanç → bang-bang (sim-to-real gap, §11.11).
% Bu betik İKİSİNİ DE gerçek firmware plant'ında (duty→ω) değerlendirir:
%   - ampirik Kp=0.002, Ki=0.1  → çalışan sistemin marjı (2.T1 asıl hedefi)
%   - conservative Kp=0.1163     → neden bang-bang verdiğinin marj-düzeyi kanıtı
%
% ── ANALİTİK PM (ampirik) ────────────────────────────────────────────
% L_e(s) = (Kp+Ki/s)·K·Vs/(τs+1) = 1.3096(s+50)/[s(0.0605s+1)]
% İç kapalı-çevrim ζ_i=0.58 (bkz. design_position_rootlocus.m) →
%   yaklaşık kural PM ≈ 100·ζ_i ≈ 58° ([Franklin2010] §6, ζ<0.7 için)
% margin() ile kesin değer doğrulanır.
%
% Kaynak: [Franklin2010] §6 (margin, PM-ζ ilişkisi), [AstromMurray2008] §10
% Çalıştırma: matlab -batch "cd('matlab/asama_2_kontrol'); design_speed_margin_empirical"

    K = 53.89; tau = 0.0605; Vs = 12.15;
    s = tf('s');
    Gd = (K*Vs)/(tau*s + 1);              % FIRMWARE plant: duty → ω

    Ce = 0.002 + 0.1/s;                   % ampirik (çalışan)
    Cc = 0.1163 + 4.0447/s;              % conservative (2.1, kullanılmıyor)
    Le = Ce*Gd;  Lc = Cc*Gd;

    [Gm_e, Pm_e, ~, Wcp_e] = margin(Le);
    [Gm_c, Pm_c, ~, Wcp_c] = margin(Lc);

    zeta_i = 0.58; PM_analytic = 100*zeta_i;   % yaklaşık kural

    fprintf('=== Test 2.T1 — FIRMWARE plant (duty->omega) marjlari ===\n');
    fprintf('AMPIRIK (Kp=0.002, Ki=0.1):    PM=%.1f deg, GM=%.1f dB, wc=%.1f rad/s\n', ...
        Pm_e, 20*log10(Gm_e), Wcp_e);
    fprintf('  analitik yaklasim PM~100*zeta_i=%.0f deg (margin dogrular)\n', PM_analytic);
    fprintf('CONSERVATIVE (Kp=0.1163) firmware plantinda: PM=%.1f deg, wc=%.1f rad/s\n', ...
        Pm_c, Wcp_c);
    fprintf('  -> dusuk PM / yuksek wc = bang-bang egilimi (sim-to-real gap kaniti)\n');

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '2_1_speed_pi');
    if ~exist(outdir, 'dir'); mkdir(outdir); end
    set(groot, 'defaultAxesColor','w', 'defaultAxesXColor','k', 'defaultAxesYColor','k', ...
        'defaultTextColor','k', 'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    f = figure('Position', [80 80 760 600], 'Color', 'w');
    [me, pe, w] = bode(Le); me = squeeze(me); pe = squeeze(pe);
    [mc, pc] = bode(Lc, w); mc = squeeze(mc); pc = squeeze(pc);

    subplot(2,1,1);
    semilogx(w, 20*log10(me), 'b', 'LineWidth',1.8); hold on; grid on;
    semilogx(w, 20*log10(mc), 'r--', 'LineWidth',1.5);
    yline(0,'k:');
    ylabel('Gain [dB]'); title('Test 2.T1 — Speed PI Margins on Firmware Plant (duty\rightarrow\omega)', 'FontWeight','bold');
    legend('calisan K_p=0.002 (analitik)','conservative K_p=0.1163 (bang-bang)', ...
        'Location','southwest','TextColor','k','Color','w','EdgeColor',[0.6 0.6 0.6]);

    subplot(2,1,2);
    semilogx(w, pe, 'b', 'LineWidth',1.8); hold on; grid on;
    semilogx(w, pc, 'r--', 'LineWidth',1.5);
    yline(-180,'k:');
    ylabel('Phase [deg]'); xlabel('frequency \omega [rad/s]');
    text(1.4, -150, sprintf('calisan: PM=%.0f^\\circ, \\omega_c=%.0f rad/s (guvenli)', Pm_e, Wcp_e), 'Color','b','FontSize',9);
    text(1.4, -165, sprintf('conservative: PM=%.0f^\\circ ama \\omega_c=%.0f >> Nyquist 628', Pm_c, Wcp_c), 'Color','r','FontSize',9);

    exportgraphics(f, fullfile(outdir, '05_margin_empirical_vs_conservative.png'), 'Resolution',150);
    close(f);
    fprintf('Gorsel: %s/05_margin_empirical_vs_conservative.png\n', outdir);
end
