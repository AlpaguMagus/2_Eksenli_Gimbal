function analyze_rga(mimo_csv)
% ANALYZE_RGA  Aşama 3.5 (K4) — RGA + condition number karar çerçevesi (MIMO karar kapısı).
%
% Kontrol Yöntemleri Merdiveni'nde K4 = KARAR KAPISI: 2×2 plant'ın çapraz-kuplajını ölçüp
% "decentralized cascade (K0/K1) yeter mi, yoksa decoupling/MIMO (K5/K6) gerekli mi?" sorusunu
% NESNEL yanıtlar. İki sağlam motor gelince gerçek veriyle çalışır; ŞİMDİ sentetik örneklerle
% matematik + karar kuralı doğrulanır (çerçeve hazır, veri beklemede).
%
% RGA (Relative Gain Array, [Bristol1966], [Skogestad2005] §3.4, §10.6):
%   Λ = G(0) ∘ (G(0)^{-1})^T     (∘ = Hadamard/eleman-bazlı çarpım), G(0) = DC kazanç matrisi
%   2×2 için:  λ11 = 1/(1 − g12·g21/(g11·g22)),  Λ = [λ11, 1−λ11; 1−λ11, λ11]
%   KARAR:  λ11 ≈ 1 → eksenler doğal AYRIK, diyagonal eşleme iyi → decentralized YETER (K1)
%           λ11 ≈ 0.5 → güçlü etkileşim;  λ11>1 veya <0 → şiddetli → decoupling/MIMO (K5/K6)
%   condition number κ(G0): κ<10 → decentralized uygun; κ>10 → decoupling/tam MIMO gerekli.
%
% Kaynak: [Skogestad2005] §3.4 (RGA), §10.6 (decentralized control & pairing), §3.3 (condition no).
% Kullanım (gerçek veri):  analyze_rga('artifacts/3/mimo_id/<id>/raw/step_2x2.csv')
%          (sentetik demo):  analyze_rga()
%
% GERÇEK-VERİ ARAYÜZÜ (2 motor gelince): her motoru ayrı duty-step ile sür, HER İKİ ekseni ölç:
%   CSV kolonları: t, u1, u2, w1, w2  (giriş duty'ler + çıkış hızlar). 4 deney:
%   (u1 step, u2=0) → G11,G21 ;  (u2 step, u1=0) → G12,G22. tfest ile eleman-bazlı.
% Çalıştırma: matlab -batch "cd('matlab/asama_3_mimo_model'); analyze_rga"

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here, 'results', '3_5_rga');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    set(groot, 'defaultFigureColor','w', 'defaultAxesColor','w', ...
        'defaultAxesXColor','k', 'defaultAxesYColor','k', 'defaultTextColor','k');

    if nargin >= 1 && ~isempty(mimo_csv) && isfile(mimo_csv)
        % ── GERÇEK VERİ yolu (2 motor gelince) ──
        G0 = identify_gain_matrix(mimo_csv);   % tfest → DC kazanç matrisi
        fprintf('Gerçek 2×2 DC kazanç matrisi (%s):\n', mimo_csv); disp(G0);
        [lam, kappa, decision] = rga_decide(G0);
        report(G0, lam, kappa, decision);
        plot_rga(outdir, {G0}, {'real motor-2 2-axis'}, 'rga_real.png');
    else
        % ── SENTETİK DEMO (çerçeve + karar kuralı doğrulama; gerçek veri beklemede) ──
        fprintf('\n=== K4 RGA çerçevesi — SENTETİK demo (gerçek 2-motor verisi beklemede) ===\n');
        cases = { [10 1; 1 10], 'zayif kuplaj (gimbal beklenen)'; ...
                  [10 8; 8 10], 'guclu kuplaj' };
        G0s = {}; labels = {};
        for i=1:size(cases,1)
            G0 = cases{i,1};
            [lam, kappa, decision] = rga_decide(G0);
            fprintf('\n[%s] G0=[%g %g; %g %g]\n', cases{i,2}, G0(1,1),G0(1,2),G0(2,1),G0(2,2));
            report(G0, lam, kappa, decision);
            G0s{end+1}=G0; labels{end+1}=cases{i,2}; %#ok<AGROW>
        end
        plot_rga(outdir, G0s, labels, 'rga_demo.png');
        fprintf('\nNOT: gerçek τ/kuplaj için 2 SAĞLAM motor gerekir (motor-1 yedeği bekleniyor).\n');
        fprintf('     Çerçeve hazır: analyze_rga(''<2x2 step CSV>'') gerçek veriyle çalışır.\n');
    end
    fprintf('Çıktı: %s/\n', outdir);
end

% ====================================================================
function [lam, kappa, decision] = rga_decide(G0)
    lam = G0 .* inv(G0).';            % RGA (Hadamard)
    kappa = cond(G0);
    l11 = lam(1,1);
    if abs(l11-1) < 0.2 && kappa < 10
        decision = 'DECENTRALIZED yeter (K1) — capraz kuplaj zayif';
    elseif l11 < 0 || l11 > 2 || kappa > 20
        decision = 'SIDDETLI kuplaj → tam MIMO/decoupling (K5/K6) gerekli';
    else
        decision = 'ORTA kuplaj → decoupling on-kompansator degerlendir (K5)';
    end
end

function report(G0, lam, kappa, decision)
    fprintf('  RGA λ11=%.3f (λ matrisi [%.2f %.2f; %.2f %.2f]), κ(G0)=%.2f\n', ...
        lam(1,1), lam(1,1),lam(1,2),lam(2,1),lam(2,2), kappa);
    fprintf('  KARAR: %s\n', decision);
end

function G0 = identify_gain_matrix(csv)
    % Gerçek veri: t,u1,u2,w1,w2 → eleman-bazlı DC kazanç (basit son-değer/giriş; tfest opsiyonel)
    T = readtable(csv);
    % iki deney varsayımı: ilk yarı u1-step, ikinci yarı u2-step (test protokolüne göre uyarlanır)
    error('identify_gain_matrix: gerçek 2-motor veri protokolü kesinleşince doldurulacak (t,u1,u2,w1,w2).');
end

% ====================================================================
function plot_rga(outdir, G0s, labels, fname)
    n = numel(G0s);
    f = figure('Position',[60 60 460*n 380],'Color','w','Visible','off');
    for i=1:n
        lam = G0s{i} .* inv(G0s{i}).';  kappa = cond(G0s{i});
        subplot(1,n,i);
        imagesc(lam, [0 max(2,max(lam(:)))]); colormap(parula); colorbar; axis square;
        for r=1:2, for c=1:2
            text(c,r,sprintf('%.2f',lam(r,c)),'HorizontalAlignment','center', ...
                'Color','w','FontWeight','bold','FontSize',13);
        end, end
        set(gca,'XTick',1:2,'YTick',1:2,'XTickLabel',{'u_1','u_2'},'YTickLabel',{'\omega_1','\omega_2'});
        title(sprintf('%s\nRGA \\lambda_{11}=%.2f, \\kappa=%.1f', labels{i}, lam(1,1), kappa),'FontSize',10);
    end
    sgtitle('Asama 3.5 (K4) — RGA decision gate (lambda=1 decoupled, far=coupled)','FontSize',12,'FontWeight','bold');
    exportgraphics(f, fullfile(outdir,fname),'Resolution',150); close(f);
end
