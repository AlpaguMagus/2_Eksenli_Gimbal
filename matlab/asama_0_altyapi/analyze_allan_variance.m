function analyze_allan_variance(test_id)
% ANALYZE_ALLAN_VARIANCE  IMU statik gürültüden Allan deviation → optimal α.
%
% scripts/imu_noise_log.py çıktısından (artifacts/0/imu_noise/<id>/raw/data.csv)
% gyro'nun overlapping Allan deviation'ını hesaplar, angle random walk (ARW) ve
% bias instability çıkarır; accel açı gürültüsüyle birlikte complementary
% filter'ın VERİ-TEMELLİ optimal kesim frekansı + α'sını türetir.
%
% Teori (IEEE Std 952):
%   - Gyro entegre açı hatası: random walk, σ_θ,gyro(t) = ARW·√t  (ARW: °/√s)
%   - Accel açı ölçümü: drift'siz, sabit gürültü σ_θ,accel
%   - Complementary kesim, iki hatanın eşitlendiği yer:
%       ARW·√τ_co = σ_θ,accel  ⇒  τ_co = (σ_θ,accel / ARW)²
%       ω_co = 1/τ_co,   α = τ_co/(τ_co + Ts)   (Ts ~8 ms, IMU okunurken kanonik loop)
%   NOT: τ_co=171 s ≫ Ts olduğundan α_opt=0.9997 dt'e pratikte duyarsız
%        (Ts=0.05→0.999708, Ts=0.008→0.999953; %.4f'te ikisi de 0.9997).
%
% Çalıştırma: matlab -batch "cd('matlab/asama_0_altyapi'); analyze_allan_variance('allan_900')"

    if nargin < 1, test_id = 'allan_900'; end
    here = fileparts(mfilename('fullpath'));
    proj = fileparts(fileparts(here));
    base = fullfile(proj,'artifacts','0','imu_noise',test_id,'raw');
    csv = fullfile(base,'data.csv');
    if ~exist(csv,'file')
        gz = fullfile(base,'data.csv.gz');
        if exist(gz,'file'), gunzip(gz); end
    end
    T = readtable(csv);
    t_us = T.t_us; gx = T.gx_dps; gy = T.gy_dps; pa = T.pitch_acc; ra = T.roll_acc;

    % örnekleme periyodu (DWT µs); medyan dt gürbüz
    dt = median(diff(t_us))/1e6;  fs = 1/dt;
    Ts_fw = 0.008;  % kanonik döngü periyodu ~8 ms (IMU okunurken kanonik loop)
    fprintf('Örnek: %d, fs=%.1f Hz, dt=%.4f s\n', numel(gx), fs, dt);

    % --- Allan deviation (gyro pitch ekseni = gy, mirror ekseni) ---
    [tau, adev] = overlapping_allan(gy, dt);

    % ARW: slope -1/2 bölgesi, τ=1s'e ekstrapolasyon (σ = ARW/√τ → ARW = σ(1s))
    % τ=1s'e en yakın nokta
    [~, i1] = min(abs(tau - 1.0));
    ARW = adev(i1) * sqrt(tau(i1));          % °/√s  (σ(τ)=ARW/√τ)
    % Bias instability: minimum Allan deviation / 0.664
    [adev_min, imin] = min(adev);
    B = adev_min / 0.664;                     % °/s
    tau_B = tau(imin);

    % --- Accel açı gürültüsü (detrend, std) ---
    sigma_acc = std(detrend(pa));             % derece (pitch accel)

    % --- Optimal complementary kesim ---
    tau_co = (sigma_acc / ARW)^2;             % s
    w_co   = 1/tau_co;                        % rad/s
    alpha_opt = tau_co / (tau_co + Ts_fw);

    % mevcut firmware
    alpha_fw = 0.98;
    w_co_fw  = (1-alpha_fw)/(alpha_fw*Ts_fw);

    fprintf('\n=== Gyro (gy) Allan ===\n');
    fprintf('ARW (angle random walk) = %.4g deg/sqrt(s) = %.3g deg/sqrt(hr)\n', ARW, ARW*60);
    fprintf('Bias instability B = %.4g deg/s (tau_B=%.1f s)\n', B, tau_B);
    fprintf('Accel aci gurultusu sigma = %.3g deg\n', sigma_acc);
    fprintf('\n=== Optimal complementary ===\n');
    fprintf('tau_co = %.3g s, w_co = %.3g rad/s, alpha_opt = %.4f\n', tau_co, w_co, alpha_opt);
    fprintf('FIRMWARE alpha=0.98 -> w_co=%.3g rad/s\n', w_co_fw);
    fprintf('Karsilastirma: opt alpha=%.4f vs fw 0.98 (%s)\n', alpha_opt, ...
        ternary(abs(alpha_opt-0.98)<0.01,'TUTARLI','FARK var'));

    % --- görsel ---
    set(groot,'defaultAxesColor','w','defaultAxesXColor','k','defaultAxesYColor','k', ...
        'defaultTextColor','k','defaultAxesGridColor',[0.15 0.15 0.15],'defaultAxesGridAlpha',0.3);
    f = figure('Position',[80 80 760 520],'Color','w');
    loglog(tau, adev, 'b', 'LineWidth',1.8); hold on; grid on;
    plot(tau(i1), adev(i1), 'ro', 'MarkerFaceColor','r','MarkerSize',8);
    plot(tau_B, adev_min, 'ks', 'MarkerFaceColor','k','MarkerSize',8);
    % ARW -1/2 referans eğimi
    tref = tau(tau<=tau_B);
    if ~isempty(tref)
        loglog(tref, ARW./sqrt(tref), 'r--', 'LineWidth',1);
    end
    xlabel('averaging time \tau [s]','Interpreter','tex','FontSize',12);
    ylabel('Allan deviation \sigma(\tau) [deg/s]','Interpreter','tex','FontSize',12);
    title('IMU Gyro (pitch) Allan Deviation','FontWeight','bold','FontSize',13);
    legend('\sigma(\tau)', sprintf('ARW @\\tau=1s = %.3g',ARW), ...
        sprintf('bias instab. = %.3g',B), 'slope -1/2 (ARW)', ...
        'Location','southwest','TextColor','k','Color','w','EdgeColor',[0.6 0.6 0.6]);
    text(2, 0.05, sprintf('static-opt: \\alpha=%.4f, \\omega_{co}=%.2g rad/s\nfirmware: \\alpha=0.98, \\omega_{co}=%.2g rad/s', ...
        alpha_opt, w_co, w_co_fw), 'FontSize',9, 'BackgroundColor',[0.97 0.97 0.9],'EdgeColor',[0.7 0.7 0.7], ...
        'HorizontalAlignment','left','VerticalAlignment','top');

    outdir = fullfile(here,'results');
    exportgraphics(f, fullfile(outdir,'allan_deviation.png'), 'Resolution',150);
    close(f);
    fprintf('\nGorsel: %s/allan_deviation.png\n', outdir);

    % sonuç JSON (firmware'e referans)
    res = struct('fs_hz',fs,'ARW_deg_sqrt_s',ARW,'bias_instab_deg_s',B, ...
        'sigma_accel_deg',sigma_acc,'tau_co_s',tau_co,'w_co_rad_s',w_co, ...
        'alpha_opt',alpha_opt,'alpha_fw',alpha_fw,'w_co_fw',w_co_fw);
    fid = fopen(fullfile(outdir,'allan_result.json'),'w');
    fprintf(fid, '%s', jsonencode(res, 'PrettyPrint', true)); fclose(fid);
end

% ── overlapping Allan deviation (rate sinyali) ───────────────────────
function [tau, adev] = overlapping_allan(omega, dt)
    omega = omega(:);
    N = numel(omega);
    theta = cumsum(omega)*dt;        % entegre açı [deg]
    maxm = floor((N-1)/2);
    ms = unique(round(logspace(0, log10(maxm), 60)));
    ms = ms(ms>=1 & ms<=maxm);
    tau = ms*dt;
    adev = zeros(size(ms));
    for j = 1:numel(ms)
        m = ms(j); L = N - 2*m;
        d = theta(1+2*m:end) - 2*theta(1+m:end-m) + theta(1:end-2*m);
        adev(j) = sqrt( sum(d.^2) / (2*m^2*dt^2*L) );
    end
end

function out = ternary(c,a,b)
    if c, out=a; else, out=b; end
end
