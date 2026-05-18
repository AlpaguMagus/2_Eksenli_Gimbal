function comparison = compare_speed_pi(mp, controllers, out_dir)
%% Aşama 2.1 — Tüm hız PI kontrolcülerini karşılaştır
%
% Pole placement + pidtune (Robust/Balanced/Fast) için:
%   - Bode plot (4 kontrolcü, açık döngü L = G·C)
%   - Step response (kapalı döngü T = L/(1+L))
%   - Gain/Phase margin, settling time, overshoot, ss_error
%
% Referans:
%   [Franklin2010] §6.7 (margin), §3.5 (step response metrics)
%
% Girdi:
%   mp           — load_motor_params çıktısı
%   controllers  — struct array (pole placement + pidtune sonuçları)
%   out_dir      — figure ve raporun kaydedileceği dizin
%
% Çıktı: comparison struct array
%   her kontrolcü için:
%     .name, .Kp, .Ki
%     .GM_dB, .PM_deg, .wcg, .wcp
%     .settling_time_s, .overshoot_pct, .rise_time_s
%     .ss_error_pct

if ~exist(out_dir, 'dir'), mkdir(out_dir); end

G = tf(mp.K_avg, [mp.tau_s 1]);
n = numel(controllers);
comparison = repmat(struct('name','','Kp',0,'Ki',0, ...
    'GM_dB',NaN,'PM_deg',NaN,'wcg',NaN,'wcp',NaN, ...
    'settling_time_s',NaN,'overshoot_pct',NaN,'rise_time_s',NaN, ...
    'ss_error_pct',NaN), n, 1);

% ── Bode plot (4 kontrolcü açık döngü) ─────────────────────────
f_bode = figure('Visible','off','Position',[50 50 900 700],'Color','w');
colors = lines(n);
hold on
legends = cell(n, 1);

for i = 1:n
    c = controllers(i);
    C = pid(c.Kp, c.Ki);
    L = G * C;   % open loop
    T = feedback(L, 1);   % closed loop

    % Margins
    [Gm, Pm, Wcg, Wcp] = margin(L);
    comparison(i).name   = c.name;
    comparison(i).Kp     = c.Kp;
    comparison(i).Ki     = c.Ki;
    comparison(i).GM_dB  = 20 * log10(Gm);
    comparison(i).PM_deg = Pm;
    comparison(i).wcg    = Wcg;
    comparison(i).wcp    = Wcp;

    % Step response metrics
    info = stepinfo(T);
    comparison(i).settling_time_s = info.SettlingTime;
    comparison(i).overshoot_pct   = info.Overshoot;
    comparison(i).rise_time_s     = info.RiseTime;
    % SS error: 1 − dcgain(T)
    dc = dcgain(T);
    comparison(i).ss_error_pct = 100 * abs(1 - dc);

    legends{i} = sprintf('%s (Kp=%.2f, Ki=%.2f, PM=%.1f°)', ...
        c.name, c.Kp, c.Ki, Pm);
end
close(f_bode);   % yeniden tek bodeplot ile çiziyoruz aşağıda

% Bode plot — tek figure üzerinde 4 sistem
f_bode = figure('Visible','off','Position',[50 50 900 700],'Color','w');
hold on
for i = 1:n
    c = controllers(i);
    L = G * pid(c.Kp, c.Ki);
    bode(L, {0.1, 1000});   % freq range
end
legend(legends, 'Location','southwest', 'Interpreter','none');
title('Açık döngü Bode — 4 kontrolcü karşılaştırma');
grid on
exportgraphics(f_bode, fullfile(out_dir, '01_bode_comparison.png'), 'Resolution', 150);
close(f_bode);

% ── Step response (kapalı döngü) ──────────────────────────────
f_step = figure('Visible','off','Position',[50 50 900 500],'Color','w');
hold on
t_sim = 0:0.001:0.5;
for i = 1:n
    c = controllers(i);
    T = feedback(G * pid(c.Kp, c.Ki), 1);
    [y, t] = step(T, t_sim);
    plot(t*1000, y, 'LineWidth', 1.5, 'Color', colors(i,:));
end
yline(1, 'k:', 'setpoint');
yline(0.95, 'k--', '5% band');
yline(1.05, 'k--');
xlabel('zaman (ms)'); ylabel('ω / ω_{ref}');
title('Kapalı döngü step response — birim referans');
legend(legends, 'Location','southeast', 'Interpreter','none');
grid on
exportgraphics(f_step, fullfile(out_dir, '02_step_response.png'), 'Resolution', 150);
close(f_step);

% ── Metric tablosu (bar chart) ────────────────────────────────
f_metrics = figure('Visible','off','Position',[50 50 1100 500],'Color','w');
subplot(1,3,1);
bar([[comparison.GM_dB]; [comparison.PM_deg]/10]');
title('Margins (PM/10 to fit)'); legend({'GM (dB)','PM/10 (°)'}); grid on
set(gca,'XTickLabel',{comparison.name}); xtickangle(30)
subplot(1,3,2);
bar([comparison.settling_time_s]*1000);
title('Settling time (ms)'); grid on
set(gca,'XTickLabel',{comparison.name}); xtickangle(30)
subplot(1,3,3);
bar([comparison.overshoot_pct]);
title('Overshoot (%)'); grid on
set(gca,'XTickLabel',{comparison.name}); xtickangle(30)
sgtitle('Kontrolcü performans karşılaştırma — Aşama 2.1');
exportgraphics(f_metrics, fullfile(out_dir, '03_metrics_bar.png'), 'Resolution', 150);
close(f_metrics);

% ── Konsol özet ───────────────────────────────────────────────
fprintf('\n— Kontrolcü karşılaştırma özeti —\n');
fprintf('%-22s | %8s | %8s | %8s | %10s | %10s | %8s\n', ...
    'name','Kp','Ki','GM (dB)','PM (°)','Tset (ms)','OS (%)');
fprintf(repmat('-',1,100)); fprintf('\n');
for i = 1:n
    c = comparison(i);
    fprintf('%-22s | %8.4f | %8.4f | %8.2f | %10.1f | %10.1f | %8.2f\n', ...
        c.name, c.Kp, c.Ki, c.GM_dB, c.PM_deg, c.settling_time_s*1000, c.overshoot_pct);
end
end
