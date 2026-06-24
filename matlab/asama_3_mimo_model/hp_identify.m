function hp_identify()
% HP_IDENTIFY  HP plant kimliği (eksen-0, HW-039/BTS7960 20 kHz, 20:1) — step verisinden tfest.
% Soru: τ_HP gerçekten ~420 ms mi (Python pozisyon-fit), yoksa gecikme/nonlineerite artefaktı mı?
% Yöntem: T_US-zamanlı clean step (0.30→0.50) → ω=dEC/dt → tfest (1.mertebe, 1.mertebe+gecikme,
%         2.mertebe) karşılaştır; fit% + kutup→τ + DC kazanç. Aşama-1 LP disipliniyle (matlab/asama_1_model).
% Kaynak: [Ljung1999] System Identification; tfest = prediction-error min.

  here = fileparts(mfilename('fullpath'));
  csv  = fullfile(here,'..','..','artifacts','3','hp_stepid','20260615_024718_clean','raw','data.csv');
  outdir = fullfile(here,'results','3_hp_id'); if ~exist(outdir,'dir'), mkdir(outdir); end
  set(groot,'defaultFigureColor','w','defaultAxesColor','w','defaultAxesXColor','k', ...
      'defaultAxesYColor','k','defaultTextColor','k');

  T = readtable(csv,'TextType','char');
  fprintf('Yüklendi: %d satır\n', height(T));

  % --- ilk clean forward step segmentini bul (pre_F → STEP_F) ---
  ph = string(T.phase);
  iStep = find(ph=="STEP_F",1,'first');
  iPre0 = find(ph=="pre_F" & (1:height(T))'<iStep,1,'first');
  iEnd  = find(ph=="STEP_F",1,'last');
  seg = iPre0:iEnd;
  t = T.t_s(seg); t = t - T.t_s(iStep);   % step anı t=0
  duty = T.cmd_duty(seg);
  ec = T.ec(seg);

  % --- ω = dEC/dt (T_US zamanlı), hafif düzgünleştir ---
  CPR = 48;
  w = gradient(ec, t) / CPR * 2*pi;        % rad/s motor şaftı
  w = smoothdata(w,'movmean',3);

  % --- uniform grid'e resample (tfest uniform Ts ister) ---
  Ts = 0.032;                              % ~31 Hz loop
  tu = (t(1):Ts:t(end))';
  wu = interp1(t,w,tu,'linear');
  du = interp1(t,duty,tu,'previous');

  % --- step'e detrend (pre-step seviyesi) → incremental yanıt ---
  pre = tu<0 & tu>-0.25;
  w0 = mean(wu(pre)); d0 = mean(du(pre));
  yi = wu - w0; ui = du - d0;

  data = iddata(yi, ui, Ts);

  % --- tfest: 3 model ---
  opt = tfestOptions('Display','off');
  m1  = tfest(data, 1, 0, opt);            % 1 kutup, gecikme yok
  m1d = tfest(data, 1, 0, 'Feedthrough',false, opt);
  try, m1del = tfest(data, 1, 0, opt, 'IODelay', NaN); catch, m1del = m1; end
  m2  = tfest(data, 2, 0, opt);

  function [tau,Kg,fitp,iod] = rep(m)
    p = pole(m); [~,ix] = min(abs(real(p))); tau = -1/real(p(ix));
    Kg = dcgain(m); fitp = m.Report.Fit.FitPercent;
    try iod = m.IODelay; catch, iod = 0; end
  end
  [t1,K1,f1,~]   = rep(m1);
  [t1d,K1d,f1d,d1d] = rep(m1del);
  [t2,K2,f2,~]   = rep(m2);

  fprintf('\n=== HP tfest sonuçları (incremental step yanıtı) ===\n');
  fprintf('1.mertebe        : τ=%6.1f ms  Kg=%7.1f  fit=%5.1f%%\n', t1*1000, K1, f1);
  fprintf('1.mertebe+gecikme: τ=%6.1f ms  Kg=%7.1f  fit=%5.1f%%  IODelay=%.0f ms\n', t1d*1000, K1d, f1d, d1d*1000);
  fprintf('2.mertebe        : τ_dom=%6.1f ms  Kg=%7.1f  fit=%5.1f%%\n', t2*1000, K2, f2);
  fprintf('(Kg duty-domeni; K_V=Kg/12.15. LP: Kg=654.8, τ=60.5ms)\n');

  % --- plot: ölçülen vs modeller ---
  f = figure('Position',[60 60 1000 520],'Visible','off');
  subplot(2,1,1); hold on; grid on; box on;
  plot(tu, wu, 'k.', 'MarkerSize',8, 'DisplayName','ölçülen \omega (EC)');
  ysim1 = lsim(m1, ui, tu) + w0;
  ysim2 = lsim(m2, ui, tu) + w0;
  plot(tu, ysim1, 'r-','LineWidth',1.4,'DisplayName',sprintf('1.mertebe (\\tau=%.0fms, fit %.0f%%)',t1*1000,f1));
  plot(tu, ysim2, 'b--','LineWidth',1.2,'DisplayName',sprintf('2.mertebe (fit %.0f%%)',f2));
  xline(0,'k:','HandleVisibility','off'); ylabel('\omega (rad/s, motor)');
  title('HP step yaniti (0.30\rightarrow0.50 duty) — olculen vs tfest model'); legend('Location','southeast');
  subplot(2,1,2); hold on; grid on; box on;
  plot(tu, du, 'm-','LineWidth',1.2); ylabel('duty (komut)'); xlabel('t (s, step@0)'); ylim([0.25 0.55]);
  exportgraphics(f, fullfile(outdir,'hp_step_id.png'),'Resolution',150); close(f);

  % --- JSON özet ---
  rec = struct('K_first_tau_ms',round(t1*1000,1),'K_first_Kg',round(K1,1),'K_first_fit',round(f1,1), ...
               'K_delay_tau_ms',round(t1d*1000,1),'K_delay_ms',round(d1d*1000,1),'K_delay_fit',round(f1d,1), ...
               'K_second_taudom_ms',round(t2*1000,1),'K_second_fit',round(f2,1), ...
               'K_V_first', round(K1/12.15,2));
  fid=fopen(fullfile(outdir,'hp_id.json'),'w'); fwrite(fid,jsonencode(rec,'PrettyPrint',true)); fclose(fid);
  fprintf('\nPlot+JSON: %s\n', outdir);
end
