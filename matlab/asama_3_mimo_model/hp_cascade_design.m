%% hp_cascade_design.m — HP ekseni (eksen-0) cascade ANALİTİK tasarımı
% Faz 2 (onaylı plan). Faz 1 karakterizasyonundan (mil serbest, ≤0.5 duty) ölçülen
% HP plant ile iç hız-PI + dış pozisyon-P kazançlarını ANALİTİK türetir, toolbox ile DOĞRULAR.
%
% Yöntem (analitik-önce, [Franklin2010]/[AstromMurray2008]): LP'de doğrulanmış formül
%   (design_speed_pi_corrected.m, docs §11.11.3) HP plant'ına uygulanır:
%   - İç PI: doyum-kısıtı Kp=duty_max/ω_max + doğru-plant pole placement ω_n=2/τ → Ki
%   - Dış P: 5× cascade kuralı (ω_c ≤ ω_n,iç/5) + tip-1 Kv takip [Franklin2010 §6.4,§4.3]
% Toolbox (margin/pidtune/c2d) = DOĞRULAMA (birincil değil).
%
% Çıktı: results/hp_cascade/  (step + Bode plot, PNG git'e girer)
% Üretfilen kazançlar → src/main.c eksen-0 (Faz 3, manuel transfer + yorum atıf).
clear; clc; close all;
set(groot,'defaultAxesColor','w','defaultAxesXColor','k','defaultAxesYColor','k','defaultTextColor','k');
outdir = fullfile('results','hp_cascade'); if ~exist(outdir,'dir'); mkdir(outdir); end

%% ---------- 1) ÖLÇÜLEN PLANT (Faz 1) ----------
% Kg = Δω_motor/Δduty [rad/s(motor)/duty], K(duty) eğrisi regresyonundan:
%   fwd: ω=7965·duty−220 (cnt/s);  7965 cnt/s/duty × 2π/48 = 1042 rad/s/duty
EVENTS_PER_REV = 48;  GEAR = 20;  CPR = EVENTS_PER_REV*GEAR;   % HP 20:1 → 960
Kg_cnt   = 7965;                                  % cnt/s per duty (regresyon eğimi)
Kg       = Kg_cnt * 2*pi/EVENTS_PER_REV;          % rad/s(motor) per duty ≈ 1042
tau      = 0.070;                                 % s (Faz1: 63-64ms; clean 76ms; ~32ms loop → temsil 70ms)
tau_lo   = 0.063;  tau_hi = 0.076;                % robustluk aralığı
Ts       = 0.005;                                 % firmware Tustin SABIT adımı (main.c)
dt_real  = 0.032;                                 % gerçek loop periyodu (~31Hz, §12.11.6) — latent kuplaj
duty_max = 0.50;                                  % MOTOR_MAX_DUTY (akım cap)
wref_max = 300;                                   % omega_ref_max [rad/s motor]
Vdead_k  = 0.14;                                  % kinetik dead-band (Coulomb FF için)
Vdead_s  = 0.21;                                  % statik kopma (stiction)

% LP referans (doğrulanmış — yöntem self-check)
Kg_LP=654.8; tau_LP=0.0605; Kp_LP=0.002; Ki_LP=0.1;

fprintf('=== HP PLANT (Faz 1 ölçülen) ===\n');
fprintf('  Kg = %.0f cnt/s/duty = %.0f rad/s(motor)/duty   τ = %.0f ms (aralık %.0f-%.0f)\n',...
        Kg_cnt, Kg, tau*1e3, tau_lo*1e3, tau_hi*1e3);
fprintf('  gear=%g  cpr=%g  dead-band: statik %.2f / kinetik %.2f\n', GEAR, CPR, Vdead_s, Vdead_k);

Gp = tf(Kg, [tau 1]);   % iç plant: ω(s)/duty(s) = Kg/(τs+1)

%% ---------- 2) İÇ HIZ-PI — ANALİTİK ----------
% Kapalı-çevrim karakteristik: τs² + (1+Kg·Kp)s + Kg·Ki = 0
%   ⇒ ω_n² = Kg·Ki/τ ,  2ζω_n = (1+Kg·Kp)/τ
% Doyum-kısıtı: P-terimi max hatada (≈ω_ref_max) tam duty_max'a ulaşsın (bang-bang yok)
Kp_in = duty_max / wref_max;          % = 0.5/300 = 0.00167
wn    = 2/tau;                        % pole placement hedefi
Ki_in = wn^2 * tau / Kg;             % ⇒ Ki
zeta  = (1+Kg*Kp_in)/(2*wn*tau);      % ortaya çıkan sönüm
fprintf('\n=== İÇ HIZ-PI (analitik) ===\n');
fprintf('  Kp = %.5f (=duty_max/ω_max)   Ki = %.4f   → ω_n=%.1f rad/s, ζ=%.2f\n', Kp_in, Ki_in, wn, zeta);

% --- Toolbox DOĞRULAMA ---
C_in = pid(Kp_in, Ki_in);
L_in = C_in*Gp;  T_in = feedback(L_in,1);
[Gm,Pm,~,Wcp] = margin(L_in);
S_in = stepinfo(T_in);
fprintf('  [toolbox] PM=%.1f° GM=%.1f dB  ω_c=%.1f rad/s | step: ts=%.0fms os=%.0f%%\n',...
        Pm, 20*log10(Gm), Wcp, S_in.SettlingTime*1e3, S_in.Overshoot);
% pidtune karşılaştırma (aynı ω_c hedefiyle)
C_pt = pidtune(Gp,'pi',Wcp);
fprintf('  [pidtune ref @ω_c=%.1f] Kp=%.5f Ki=%.4f  (analitik ile kıyas)\n', Wcp, C_pt.Kp, C_pt.Ki);

% --- Ayrık doğrulama: gerçek loop dt etkisi (latent kuplaj) ---
Lz_nom  = c2d(L_in, Ts, 'tustin');      [~,Pm_n] = margin(Lz_nom);
Lz_real = c2d(L_in, dt_real, 'tustin'); [~,Pm_r] = margin(Lz_real);
fprintf('  [ayrık] PM @Ts=5ms: %.1f°   @dt_gerçek=32ms: %.1f°  (loop-hızı PM kaybı)\n', Pm_n, Pm_r);

%% ---------- 3) DIŞ POZİSYON-P — ANALİTİK ----------
% Dış açık-çevrim: L_out(s) = Kp_pos · T_in(s)/s   (gear ileri/geri sadeleşir → ω_c=Kp_pos)
% 5× kuralı: ω_c ≤ ω_n,iç/5 ; tip-1 Kv=Kp_pos takip: e_ss=ω_in/Kv
wc_max = wn/5;
fprintf('\n=== DIŞ POZİSYON-P (analitik) ===\n');
fprintf('  5× kuralı: ω_c ≤ ω_n,iç/5 = %.1f rad/s\n', wc_max);
cands = [2.0 3.0 4.0];
bestKpp = 2.0;
for kpp = cands
    L_out = kpp * T_in * tf(1,[1 0]);
    [~,Pm_o,~,Wco] = margin(L_out);
    ess_mirror = 30/kpp;   % ω_in=30°/s ramp → e_ss [°]
    fprintf('  Kp_pos=%.1f → ω_c=%.2f, PM=%.0f°, mirror e_ss(30°/s)=%.1f°  %s\n',...
            kpp, Wco, Pm_o, ess_mirror, ternary(Wco<=wc_max,'✓ 5×-içi','⚠ 5× aşıldı'));
end
% Seçim: cascade step için proven LP değeri (ω_c düşük, kararlı); mirror takip ayrı yüksek Kv ister
Kp_pos = 2.0;
L_out  = Kp_pos*T_in*tf(1,[1 0]); T_out = feedback(L_out,1);
[~,Pm_o,~,Wco]=margin(L_out); S_out=stepinfo(T_out);
fprintf('  → SEÇİM Kp_pos=%.1f (cascade, proven): ω_c=%.2f PM=%.0f° | step ts=%.2fs os=%.0f%%\n',...
        Kp_pos, Wco, Pm_o, S_out.SettlingTime, S_out.Overshoot);
fprintf('    (mirror/takip için Kv≥6 ayrı — §12.9; runtime KPP komutu)\n');

%% ---------- 4) FİRMWARE KAZANÇ ÖZETİ ----------
fprintf('\n========== FİRMWARE eksen-0 (HP) — main.c transfer ==========\n');
fprintf('  SpeedPI:  Kp = %.5f   Ki = %.4f   (T_t=Kp/Ki=%.3f)\n', Kp_in, Ki_in, Kp_in/Ki_in);
fprintf('  PositionP: Kp_pos = %.1f   gear_ratio = %g   counts_per_rev = %g   omega_ref_max=%g\n',...
        Kp_pos, GEAR, CPR, wref_max);
fprintf('  Coulomb FF (stick-slip): coul_db≈%.2f  kff_coul≈%.2f (kinetik dead-band, default kapalı)\n', Vdead_k, Vdead_k);
fprintf('  LP karşılaştırma: HP Ki %.3f vs LP %.2f (Kg %.0f vs %.0f → daha yüksek plant, az integral)\n',...
        Ki_in, Ki_LP, Kg, Kg_LP);

%% ---------- 5) PLOTLAR ----------
f1=figure('Position',[100 100 980 380],'Color','w');
subplot(1,2,1); step(T_in,0.4); grid on; title('Inner speed loop — closed-loop step');
xlabel('Time (s)'); ylabel('\omega / \omega_{ref}');
subplot(1,2,2); margin(L_in); grid on; title('Inner speed loop — open-loop Bode');
exportgraphics(f1, fullfile(outdir,'hp_inner_speed_pi.png'),'Resolution',150);

f2=figure('Position',[100 100 980 380],'Color','w');
subplot(1,2,1); step(T_out,3); grid on; title('Outer position loop — closed-loop step (K_{pp}=2)');
xlabel('Time (s)'); ylabel('\theta / \theta_{ref}');
subplot(1,2,2); margin(L_out); grid on; title('Outer position loop — open-loop Bode');
exportgraphics(f2, fullfile(outdir,'hp_outer_position_p.png'),'Resolution',150);

% τ robustluk: gainleri sabit tut, τ aralığında PM
f3=figure('Position',[100 100 560 380],'Color','w'); hold on; grid on;
taus = linspace(tau_lo,tau_hi,7); pmv=zeros(size(taus));
for k=1:numel(taus)
    Lk = C_in*tf(Kg,[taus(k) 1]); [~,pmv(k)]=margin(Lk);
end
plot(taus*1e3, pmv,'-o','LineWidth',1.5,'Color',[0 0.45 0.74]);
xlabel('\tau (ms)'); ylabel('Phase margin (deg)'); title('Inner loop PM vs \tau (robustness)');
exportgraphics(f3, fullfile(outdir,'hp_inner_tau_robustness.png'),'Resolution',150);

fprintf('\nPlotlar: %s/ (hp_inner_speed_pi, hp_outer_position_p, hp_inner_tau_robustness).png\n', outdir);

% --- Kazançları .mat'e kaydetme YOK (workspace git-dışı); değerler stdout'tan firmware'e manuel ---
function s=ternary(c,a,b); if c; s=a; else; s=b; end; end
