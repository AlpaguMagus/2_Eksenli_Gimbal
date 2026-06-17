function analyze_mirror_stab()
% ANALYZE_MIRROR_STAB  Aşama 3.3 — mirror/stab takip RMS'inin ANALİTİK doğrulaması.
%
% Soru: gerçek-donanım takip RMS'i (mirror 5.53°, stab 6.72°) cascade modelinden
% ÖNCEDEN tahmin edilebilir mi? (deneme-yanılma değil — model sim-to-real doğrulaması).
%
% YÖNTEM ([Franklin2010] §6.1 tracking, §4.2 sensitivity):
%   1. Cascade kapalı-döngü:  T_out(s) = L/(1+L),  L = Kp_pos·T_inner(s)·(1/s),  Kp_pos=6
%      (mirror/STAB runtime kazancı — cmd_parser.c:66 MODE:MIRROR/STAB otomatik atar; POS step=2.0 AYRI mod)
%   2. Ölçülen referans tr(t)'yi uniform grid'e yeniden örnekle → lsim(T_out, tr) = θ_pred
%   3. Model takip hatası RMS(θ_pred − tr) vs ölçülen RMS(θ_meas − tr) karşılaştır
%   4. Ölçülen fp(t) FFT → baskın el-hareketi frekansı → |S(jω)|·A frekans-domeni tahmini
%
% Bu, §12.6'da ölçülen RMS'in cascade bant-genişliği ile açıklanabildiğini gösterir:
% düşük frekans (yavaş el) iyi takip; hızlı el |S(jω)|↑ → hata↑ (beklenen fizik).
%
% Kaynak: [Franklin2010] §6.1, §4.2; iç döngü [Aşama 2.1] K=53.89/τ=60.5ms.
% Calistirma: matlab -batch "cd('matlab/asama_3_mimo_model'); analyze_mirror_stab"

    here = fileparts(mfilename('fullpath'));
    root = fullfile(here, '..', '..');
    outdir = fullfile(here, 'results', '3_3_bench');
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k', ...
        'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    % ── cascade kapalı-döngü modeli (Aşama 2 parametreleri) ──
    % İç-döngü plant'ı DUTY-domeni: u(duty)→ω, DC kazancı Kg=K·Vs=654.8 (Aşama 2.3 H1
    % düzeltmesi — K=53.89 voltaj-domeni DEĞİL; K kullanılırsa iç-döngü 12× yavaş ωn 33→9.4).
    % Kp_pos = 6: mirror/STAB modunun GERÇEK runtime kazancı — cmd_parser.c:66 MODE:MIRROR/STAB
    % girişte PositionP_SetGain(6.0) çağırır (KPP komutu GEREKMEZ). POS step modu ayrı: main.c:162
    % default 2.0. 2026-06-14'te (commit 121ffd6) yanlışlıkla 2.0'a çevrilmişti — o teşhis git log -S'i
    % yalnız main.c'de koşturup cmd_parser.c:66'yı kaçırdı; 2026-06-17 denetimi düzeltti (docs §12.9.3).
    K=53.89; Vs=12.15; Kg=K*Vs; tau=0.0605; Kp_i=0.002; Ki_i=0.1; Kp_pos=6;
    G = tf(Kg,[tau 1]); C = pid(Kp_i,Ki_i);
    T_inner = feedback(G*C,1);
    P_outer = T_inner * tf(1,[1 0]);
    L = Kp_pos * P_outer;
    T_out = feedback(L,1);
    fprintf('Cascade: T_inner DC=%.3f, Kp_pos=%.1f, kapalı-döngü kutupları:\n', dcgain(T_inner), Kp_pos);
    disp(pole(T_out).');

    mirr = fullfile(root,'artifacts','3','mirror_m2','20260612_120636','raw','data.csv');
    stab = fullfile(root,'artifacts','3','stab_m2','20260612_121945','raw','data.csv');

    rec = struct();
    rec.mirror = validate_one(mirr, T_out, P_outer, Kp_pos, outdir, 'mirror', 5.53);
    rec.stab   = validate_one(stab, T_out, P_outer, Kp_pos, outdir, 'stab',   6.72);

    % JSON özet (makine-okur)
    fid=fopen(fullfile(outdir,'mirror_stab_validation.json'),'w');
    fwrite(fid, jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('\nDogrulama ozeti: %s/mirror_stab_validation.json\n', outdir);
end

% ====================================================================
function r = validate_one(csv, T_out, P_outer, Kp_pos, outdir, mode, rms_summary)
    T = readtable(csv);
    t = T.t; tr = T.tr; th = T.theta_deg; err = T.err;

    % --- uniform grid'e yeniden örnekle (lsim monotonik+uniform ister) ---
    dt = median(diff(t));
    tu = (t(1):dt:t(end)).';
    tru = interp1(t, tr, tu, 'linear');
    thu = interp1(t, th, tu, 'linear');

    % --- model: ölçülen referansı cascade'e ver → θ_pred ---
    th_pred = lsim(T_out, tru, tu);

    err_meas  = thu - tru;             % ölçülen takip hatası
    err_model = th_pred - tru;         % model takip hatası
    rms_meas  = sqrt(mean(err_meas.^2));
    rms_model = sqrt(mean(err_model.^2));

    % --- referans baskın frekansı (FFT) + |S(jω)| frekans-domeni tahmini ---
    trd = tru - mean(tru);
    N = numel(trd); Fs = 1/dt;
    Y = abs(fft(trd)); Y = Y(1:floor(N/2));
    fax = (0:floor(N/2)-1).'*(Fs/N);
    [~,ip] = max(Y(2:end)); f_dom = fax(ip+1);   % DC hariç baskın frekans
    A_ref = (max(tru)-min(tru))/2;               % yaklaşık referans genliği
    w_dom = 2*pi*f_dom;
    S = 1/(1+Kp_pos*P_outer);
    err_amp_fd = abs(freqresp(S, w_dom))*A_ref;
    rms_fd = err_amp_fd/sqrt(2);

    fprintf('\n[%s] RMS takip hatası:\n', upper(mode));
    fprintf('   ölçülen (bench)      = %.2f°  (summary %.2f°)\n', rms_meas, rms_summary);
    fprintf('   model (lsim T_out)   = %.2f°\n', rms_model);
    fprintf('   baskın ref frekansı  = %.3f Hz (genlik ~%.1f°) → |S| frekans-domeni RMS ~%.2f°\n', ...
        f_dom, A_ref, rms_fd);

    % --- plot: ölçülen vs model trajektori + hata ---
    f = figure('Position',[60 60 1000 560],'Color','w','Visible','off');
    subplot(2,1,1); hold on; grid on; box on;
    plot(tu, tru, '--', 'Color',[0.85 0.2 0.2],'LineWidth',1.2,'DisplayName','reference $\theta_{ref}$');
    plot(tu, thu, '-',  'Color',[0.0 0.35 0.75],'LineWidth',1.4,'DisplayName','measured $\theta$');
    plot(tu, th_pred, '-','Color',[0.2 0.6 0.2],'LineWidth',1.2,'DisplayName','model $\theta_{pred}$ (lsim)');
    ylabel('angle (deg)','Interpreter','latex');
    title(sprintf('%s — measured vs cascade-model trajectory (Kp\\_pos=%.1f)', upper(mode), Kp_pos), ...
        'Interpreter','tex','FontSize',12);
    lg=legend('Interpreter','latex','Location','best'); set(lg,'Color','w','TextColor','k');
    xlim([tu(1) tu(end)]);

    subplot(2,1,2); hold on; grid on; box on;
    plot(tu, err_meas, '-','Color',[0.5 0.25 0.55],'LineWidth',1.0,'DisplayName','measured error');
    plot(tu, err_model,'-','Color',[0.2 0.6 0.2],'LineWidth',1.0,'DisplayName','model error');
    yline(0,'k:','HandleVisibility','off');
    ylabel('error (deg)','Interpreter','latex'); xlabel('time (s)','Interpreter','latex');
    title(sprintf('Tracking error RMS: measured %.2f$^\\circ$ vs model %.2f$^\\circ$ (freq-domain $|S|$ est. %.2f$^\\circ$)', ...
        rms_meas, rms_model, rms_fd),'Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','best'); set(lg,'Color','w','TextColor','k');
    xlim([tu(1) tu(end)]);

    sgtitle(sprintf('Asama 3.3 — %s tracking: model validation (sim-to-real)', upper(mode)), ...
        'FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,sprintf('%s_model_validation.png',mode)),'Resolution',150);
    close(f);

    r = struct('mode',mode,'rms_measured_deg',round(rms_meas,2), ...
        'rms_model_lsim_deg',round(rms_model,2),'rms_summary_deg',rms_summary, ...
        'dominant_ref_freq_hz',round(f_dom,3),'ref_amplitude_deg',round(A_ref,1), ...
        'rms_freqdomain_S_deg',round(rms_fd,2),'Kp_pos',Kp_pos);
end
