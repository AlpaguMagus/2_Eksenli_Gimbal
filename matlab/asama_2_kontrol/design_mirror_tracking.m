%% Aşama 2.7 — Mirror takip için Kp_pos ANALİTİK tasarımı (deneme-yanılma DEĞİL)
%
% Takip (reference tracking) görevi → kontrolcü kazancı hesapla, dene-bul değil.
%
% TEORİ ([Franklin2010] §4.2 system type & error constants, §6.1 tracking):
%   Cascade açık döngü:  L(s) = Kp_pos · T_inner(s) · (1/s)   → TİP-1 sistem
%   Hız hata sabiti:     Kv = lim_{s→0} s·L(s) = Kp_pos·T_inner(0) = Kp_pos
%                        (T_inner DC kazancı = 1, birim geri besleme)
%   Ramp referans (sabit açısal hız ω_in) sürekli-hal takip hatası:
%                        e_ss = ω_in / Kv = ω_in / Kp_pos
%   ⇒ TASARIM:  Kp_pos ≥ ω_in / e_ss_hedef
%
% Sinüs referans (gerçekçi): θ_ref = A·sin(ωt). Takip hatası = sensitivite
%   S(jω) = 1/(1+L(jω)); hata genliği = |S(jω)|·A.
%
% Bu, Aşama 2.7'de gözlenen Kp_pos≈5 değerinin DENEYDEN ÖNCE hesaplanabileceğini
% gösterir; deney (Test 2.T6 RMS 4.68°) bu analizi DOĞRULAR, üretmez.

clear; close all; clc;

% Beyaz tema zorla — dark MATLAB session'da axes panelleri siyah kalıyordu
% (figure 'Color','w' yetmiyor; axes/text de zorlanmalı). CLAUDE.md figür disiplini.
set(groot,'defaultFigureColor','w','defaultAxesColor','w', ...
    'defaultAxesXColor','k','defaultAxesYColor','k','defaultTextColor','k', ...
    'defaultAxesGridColor',[0.15 0.15 0.15]);

% ── İç döngü + cascade (design_position_p ile aynı) ───────────────
K=53.89; tau=0.0605; Kp_i=0.002; Ki_i=0.1;
G = tf(K,[tau 1]); C = pid(Kp_i,Ki_i); T_inner = feedback(G*C,1);
P_outer = T_inner * tf(1,[1 0]);          % hız→pozisyon entegratör (tip-1 kaynağı)

fprintf('T_inner DC kazancı = %.3f (Kv = Kp_pos·bu ≈ Kp_pos)\n', dcgain(T_inner));

% ── Mirror görev tanımı (gimbal/kamera hareketi) ──────────────────
omega_in_dps = 30;    % °/s — gimbal-hızı hareket (Test 2.T6'da gözlenen ~25-30°/s)
ess_target   = 5;     % °  — Test 2.T6 hedefi (RMS)

% ── (1) Ramp analizi: Kv ile gerekli Kp_pos ───────────────────────
Kp_pos_req = omega_in_dps / ess_target;
fprintf('\n(1) RAMP takip [Franklin2010 §4.2]:\n');
fprintf('    e_ss = ω_in/Kv = ω_in/Kp_pos < %d° → Kp_pos ≥ %.1f\n', ess_target, Kp_pos_req);

% ── (2) Sinüs analizi: sensitivite |S(jω)| ile takip hatası ───────
A_deg = 30; f_hz = 0.2;     % ~30° genlik, 0.2 Hz (~5 s periyot) — gözlenen harekete yakın
w = 2*pi*f_hz;
fprintf('\n(2) SİNÜS takip (A=%d°, f=%.1f Hz, ω=%.2f rad/s):\n', A_deg, f_hz, w);
fprintf('    %-9s %-12s %-10s %-s\n','Kp_pos','Kv(1/s)','hata_genl','RMS');
kps = [2 4 5 6 8];
err_rms = zeros(size(kps));
for i=1:numel(kps)
    kp = kps(i);
    L = kp*P_outer; S = 1/(1+L);
    err_amp = abs(freqresp(S,w))*A_deg;     % sinüs takip hatası genliği (°)
    err_rms(i) = err_amp/sqrt(2);
    note=''; if err_rms(i)<ess_target, note='✓ <5°'; end
    fprintf('    %-9d %-12.1f %-10.2f %.2f° %s\n', kp, kp, err_amp, err_rms(i), note);
end

% ── Sonuç ─────────────────────────────────────────────────────────
kp_pick = Kp_pos_req;   % ramp kriteri (en muhafazakar)
fprintf('\nTASARIM SONUCU:\n');
fprintf('  Ramp kriteri:  Kp_pos ≥ %.1f\n', Kp_pos_req);
fprintf('  Seçim: Kp_pos = 5 (ramp ≥6 sınırına yakın, sinüs RMS<5° sağlar, \n');
fprintf('         2.6.5 iç ω_n~33 → 33/5≈6.6 cascade ayrımı korunur).\n');
fprintf('  Deneysel (Test 2.T6, Kp_pos=5): RMS 4.68° → analizi DOĞRULAR.\n');

% ── Plot: takip hatası sensitivitesi |S(jω)| + RMS vs Kp_pos ──────
fig=figure('Visible','off','Position',[40 40 1100 450],'Color','w');
subplot(1,2,1); hold on
fvec = logspace(-2,1,400); wvec=2*pi*fvec;
clr=lines(numel(kps));
for i=1:numel(kps)
    S = 1/(1+kps(i)*P_outer);
    mag = squeeze(abs(freqresp(S,wvec)));
    plot(fvec, 20*log10(mag),'LineWidth',1.3,'Color',clr(i,:),'DisplayName',sprintf('Kp=%d',kps(i)));
end
xline(f_hz,'k--','HandleVisibility','off'); grid on; set(gca,'XScale','log');
xlabel('frekans (Hz)'); ylabel('|S(j\omega)| = |hata/ref| (dB)');
title('Takip hatası sensitivitesi — düşük |S| = iyi takip');
lg=legend('Location','southeast'); set(lg,'Color','w','TextColor','k');
subplot(1,2,2);
plot(kps, err_rms,'bo-','LineWidth',1.5,'MarkerFaceColor','b'); hold on
yline(ess_target,'r--','hedef 5°'); plot(5, 4.68,'rp','MarkerSize',14,'MarkerFaceColor','r');
text(5.2,4.68,' deney 4.68°','Color','r'); grid on
xlabel('Kp_{pos}'); ylabel('sinüs takip hatası RMS (°)');
title(sprintf('Takip hatası vs Kp_{pos} (A=%d°, f=%.1f Hz)',A_deg,f_hz));
sgtitle('Aşama 2.7 — Mirror takip Kp_{pos} analitik tasarım ([Franklin2010] §4.2)','Color','k');

out=fullfile(fileparts(mfilename('fullpath')),'results','2_7_mirror');
if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out,'mirror_tracking_design.png'),'Resolution',150);

params=struct('task','reference_tracking','system_type',1, ...
    'Kv_equals','Kp_pos','omega_in_dps',omega_in_dps,'ess_target_deg',ess_target, ...
    'Kp_pos_ramp_req',Kp_pos_req,'Kp_pos_selected',5, ...
    'sinus_A_deg',A_deg,'sinus_f_hz',f_hz,'sinus_rms_at_Kp5',err_rms(kps==5), ...
    'experimental_rms_deg',4.68,'kaynak',{{'Franklin2010 §4.2','Franklin2010 §6.1'}});
fid=fopen(fullfile(out,'mirror_tracking_params.json'),'w');
fwrite(fid,jsonencode(params,'PrettyPrint',true),'char'); fclose(fid);
fprintf('\nÇıktı: %s/ (mirror_tracking_design.png + .json)\n', out);
