function design_kalman_attitude()
% DESIGN_KALMAN_ATTITUDE  Aşama 5 (K7) — bias-augmented attitude Kalman + complementary kıyası.
%
% Kestirim izi (ROADMAP): complementary (Aşama 0) → Mahony/Madgwick → EKF/Kalman.
% Bu script K7'nin temelini kurar: gyro-bias'ı AÇIK durum olarak kestiren 2-durumlu Kalman.
% LQG (K7 = LQR ⊕ Kalman) bu kestiriciyi kullanır. Donanımsız (tasarım/sim).
%
% NEDEN Kalman > complementary: complementary filtre SABİT kazançlıdır (α=0.98) ve gyro
% bias'ını AYRI kestirmez — bias, kestirilen açıya sızar (özellikle accel gürültülü/titreşimliyse,
% motor sürerken). Bias-augmented Kalman bias'ı online kestirip çıkarır → drift'siz.
%
% DURUM-UZAYI (ayrık, Ts):  x = [θ; b_gyro]  (derece, derece/s)
%   θ_k  = θ_{k-1} + (gyro_meas − b_{k-1})·Ts      (bias-düzeltilmiş gyro entegrali)
%   b_k  = b_{k-1}                                  (random-walk: ḃ=0 + process noise)
%   F = [1, −Ts; 0, 1],  Bu = [Ts; 0],  H = [1, 0]  (ölçüm = accel tilt)
%
% Q/R ANALİTİK (Allan variance, Aşama 0): gyro ARW=1.09°/√hr → q_θ; bias-instab.≈3°/hr → q_b;
% accel tilt gürültüsü → R. (Bryson'da olduğu gibi: gürültü fiziksel ölçümden, elle-ayar değil.)
%
% Kaynak: [Simon2006] Ch.5,7 (Kalman + bias-augmented durum), [Higgins1975] (complementary↔Kalman
%         denkliği), [IEEE952] Allan variance (Aşama 0 ARW/bias-instab.). Plant-bağımsız (sensör).
% Çalıştırma: matlab -batch "cd('matlab/asama_5_gimbal'); design_kalman_attitude"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '5_1_kalman');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k', ...
        'defaultAxesGridColor',[0.15 0.15 0.15], 'defaultAxesGridAlpha',0.3);

    Ts = 0.005;                  % 200 Hz nominal
    % ── Allan variance → Q/R (Aşama 0 ölçümleri) ──
    ARW   = 1.09;                % °/√hr  (angle random walk, gyro beyaz gürültü)
    biasI = 3.0;                 % °/hr   (bias instability)
    % ARW [°/√hr] → açı belirsizliği büyümesi/adım: σθ_step = ARW·√(Ts saat)
    sig_th_step = ARW * sqrt(Ts/3600);          % derece (gyro→θ, adım başı)
    q_th = sig_th_step^2;                        % gyro ARW (pür gyro gürültüsü, düşük → smooth)
    % bias process noise: Allan bias-instab. (3°/hr) ALT-SINIR; gerçek gyro'da termal drift
    % çok daha hızlı → bias kestiriminin drift'i ~birkaç sn'de takip etmesi için büyütülür
    % (tasarım seçimi; q_b çok küçükse bias sızar → complementary'den kötü, q_b ölçtük).
    q_b  = 1e-4;
    Q = diag([q_th, q_b]);
    sig_accel = 2.0;             % ° accel tilt gürültüsü (motor titreşimi dahil — Aşama 0)
    Rk = sig_accel^2;

    F = [1, -Ts; 0, 1];  Bu = [Ts; 0];  H = [1, 0];

    % ── steady-state Kalman kazancı (dare) ──
    P = dare_predict(F, H, Q, Rk);               % öngörü kovaryans (steady-state, predict-form DARE)
    Kss = (P*H') / (H*P*H' + Rk);                % Kalman kazancı [Kθ; Kb]
    alpha_equiv = 1 - Kss(1);                    % complementary α denkliği (Higgins)
    fprintf('\n=== K7 attitude Kalman ===\n');
    fprintf('Q=diag(%.2e, %.2e), R=%.2f deg^2\n', q_th, q_b, Rk);
    fprintf('Steady-state Kalman gain: Kθ=%.4f, Kb=%.4f\n', Kss(1), Kss(2));
    fprintf('Complementary denkliği: α = 1−Kθ = %.4f  (firmware α=0.98)\n', alpha_equiv);

    % ── senaryo: gerçek açı + drifting gyro bias + titreşimli accel ──
    T = 30; t = (0:Ts:T).';  N = numel(t);
    th_true = 20*sin(2*pi*0.1*t) + 10*sin(2*pi*0.03*t);     % yavaş base eğme
    rate_true = [0; diff(th_true)/Ts];
    bias_true = 1.5 + 1.0*tanh((t-12)/4);                   % drifting bias 1.5→2.5 °/s
    rng_g = noise_seq(N, 11);  rng_a = noise_seq(N, 7);
    gyro_meas  = rate_true + bias_true + (ARW*sqrt(1/Ts/3600))*rng_g;  % gyro + bias + beyaz
    accel_meas = th_true + sig_accel*rng_a;                            % accel + gürültü
    % titreşim: 8-16 s arası accel gürültüsü 3× (motor sürüş bandı)
    vib = (t>8 & t<16); accel_meas(vib) = th_true(vib) + 3*sig_accel*rng_a(vib);

    % ── complementary filter (firmware, α=0.98) ──
    a_cf = 0.98; cf = zeros(N,1);
    for k=2:N, cf(k) = a_cf*(cf(k-1) + gyro_meas(k)*Ts) + (1-a_cf)*accel_meas(k); end

    % ── Kalman (bias-augmented) ──
    xh = zeros(2,N); Pk = diag([4, 1]);
    for k=2:N
        % predict
        xm = F*xh(:,k-1) + Bu*gyro_meas(k);
        Pm = F*Pk*F' + Q;
        % update (accel)
        Kk = (Pm*H')/(H*Pm*H' + Rk);
        xh(:,k) = xm + Kk*(accel_meas(k) - H*xm);
        Pk = (eye(2) - Kk*H)*Pm;
    end
    th_kf = xh(1,:).'; b_kf = xh(2,:).';

    e_cf = cf - th_true; e_kf = th_kf - th_true;
    rms_cf = sqrt(mean(e_cf.^2)); rms_kf = sqrt(mean(e_kf.^2));
    fprintf('\nRMS açı hatası: complementary %.3f° | Kalman %.3f°  (%.1f× iyileşme)\n', ...
        rms_cf, rms_kf, rms_cf/rms_kf);
    fprintf('Bias kestirimi (son): true %.2f °/s, Kalman %.2f °/s\n', bias_true(end), b_kf(end));

    % ── figür ──
    f=figure('Position',[40 40 1100 720],'Color','w','Visible','off');
    subplot(3,1,1); hold on; grid on; box on;
    plot(t,accel_meas,'.','Color',[0.8 0.8 0.85],'MarkerSize',2,'DisplayName','accel meas (noisy)');
    plot(t,th_true,'k--','LineWidth',1.2,'DisplayName','true $\theta$');
    plot(t,cf,'LineWidth',1.2,'Color',[0.85 0.4 0.1],'DisplayName',sprintf('complementary $\\alpha$=0.98 (RMS %.2f$^\\circ$)',rms_cf));
    plot(t,th_kf,'LineWidth',1.4,'Color',[0.15 0.6 0.15],'DisplayName',sprintf('Kalman (RMS %.2f$^\\circ$)',rms_kf));
    ylabel('$\theta$ (deg)','Interpreter','latex'); xlim([0 T]); ylim([-40 40]);
    title('Attitude estimation: bias-augmented Kalman vs complementary (vibration 8--16 s)','Interpreter','latex','FontSize',12);
    lg=legend('Interpreter','latex','Location','northwest','NumColumns',2); set(lg,'Color','w','TextColor','k');

    subplot(3,1,2); hold on; grid on; box on;
    plot(t,e_cf,'LineWidth',1.0,'Color',[0.85 0.4 0.1],'DisplayName','complementary error');
    plot(t,e_kf,'LineWidth',1.1,'Color',[0.15 0.6 0.15],'DisplayName','Kalman error');
    yline(0,'k:','HandleVisibility','off'); xline(8,'b:','HandleVisibility','off'); xline(16,'b:','HandleVisibility','off');
    ylabel('error (deg)','Interpreter','latex'); xlim([0 T]);
    title('Estimation error: Kalman tighter under vibration + bias drift','Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','northwest'); set(lg,'Color','w','TextColor','k');

    subplot(3,1,3); hold on; grid on; box on;
    plot(t,bias_true,'k--','LineWidth',1.3,'DisplayName','true gyro bias');
    plot(t,b_kf,'LineWidth',1.4,'Color',[0.15 0.6 0.15],'DisplayName','Kalman bias estimate');
    ylabel('gyro bias (deg/s)','Interpreter','latex'); xlabel('time (s)','Interpreter','latex'); xlim([0 T]);
    title('Kalman estimates \& removes gyro bias (complementary cannot)','Interpreter','latex','FontSize',11);
    lg=legend('Interpreter','latex','Location','southeast'); set(lg,'Color','w','TextColor','k');
    sgtitle('Asama 5 (K7) — Bias-augmented attitude Kalman (Q/R from Allan variance)','FontSize',13,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,'kalman_attitude.png'),'Resolution',150); close(f);

    % ── JSON ──
    rec=struct('Ts',Ts,'ARW_deg_sqrt_hr',ARW,'bias_instab_deg_hr',biasI, ...
        'Q',[q_th q_b],'R_deg2',Rk,'Kss',Kss.','alpha_equiv',alpha_equiv, ...
        'rms_complementary_deg',round(rms_cf,3),'rms_kalman_deg',round(rms_kf,3), ...
        'improvement_x',round(rms_cf/rms_kf,2), ...
        'kaynak',{{'Simon2006 Ch5,7','Higgins1975','IEEE952 Allan'}});
    fid=fopen(fullfile(outdir,'kalman_attitude_params.json'),'w'); fwrite(fid,jsonencode(rec,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('\nÇıktı: %s/ (kalman_attitude.png + .json)\n', outdir);
end

% ====================================================================
function P = dare_predict(F, H, Q, R)
% Steady-state predict kovaryans DARE: P = F P F' − F P H'(H P H'+R)^-1 H P F' + Q (iterasyon).
    P = Q + eye(size(Q));
    for i=1:5000
        S = H*P*H' + R;
        Pn = F*P*F' - (F*P*H')/S*(H*P*F') + Q;
        if norm(Pn-P,'fro') < 1e-12, P=Pn; break; end
        P = Pn;
    end
end
function s = noise_seq(N, seed)
% Math.random yasak — deterministik pseudo-gürültü (seed'li, tekrarlanabilir).
    s = zeros(N,1); x = seed;
    for i=1:N, x = mod(1103515245*x + 12345, 2^31); s(i) = x/2^31 - 0.5; end
    s = (s - mean(s)) / std(s);   % sıfır-ort, birim-var
end
