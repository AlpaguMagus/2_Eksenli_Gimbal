function dead_band = compute_dead_band(fit_results)
%% Aşama 1.3 — Dead-band (V_dead) tespit
%
% ω_ss = K · (V_eff − V_dead)  →  V_dead = x-intercept (ω_ss=0 olduğu V_eff)
% Lineer regresyon ω_ss vs V_eff yapılır, CW/CCW ayrı.
%
% Model: ω_ss = m · V_eff + b   →   V_dead = −b / m
%
% Referans: [Franklin2010] §3.2 (Coulomb friction → effective dead-band)
%
% Çıktı:
%   dead_band.V_dead_pos    — CW yönde V_dead (V)
%   dead_band.V_dead_neg    — CCW yönde V_dead (V), negatif değer
%   dead_band.K_pos, K_neg  — fit eğimleri (rad/s/V)
%   dead_band.R2_pos, R2_neg — fit kalite metriği
%   dead_band.note          — yorum stringi

V_SUPPLY = 12.15;
V_SAT    = 0.5;

valid = ~strcmp({fit_results.method}, 'skipped_below_dead_band');
fr = fit_results(valid);
duties = [fr.duty_cmd]';
omegas = [fr.omega_ss]';

V_eff_signed = sign(duties) .* (V_SUPPLY * abs(duties) - V_SAT);

% Pozitif yön
m_pos = duties > 0;
[K_pos, b_pos, R2_pos] = lin_fit_(V_eff_signed(m_pos), omegas(m_pos));
V_dead_pos = -b_pos / K_pos;

% Negatif yön (CCW). Burada V_eff < 0, ω < 0 — regresyon yine geçerli.
m_neg = duties < 0;
[K_neg, b_neg, R2_neg] = lin_fit_(V_eff_signed(m_neg), omegas(m_neg));
V_dead_neg = -b_neg / K_neg;

dead_band.V_dead_pos = V_dead_pos;
dead_band.V_dead_neg = V_dead_neg;
dead_band.K_pos      = K_pos;
dead_band.K_neg      = K_neg;
dead_band.R2_pos     = R2_pos;
dead_band.R2_neg     = R2_neg;
dead_band.V_supply   = V_SUPPLY;
dead_band.V_sat      = V_SAT;

% Yorum stringi — akademik özet
% NOT (2026-05-18 revize): Stiction hipotezi deneysel olarak reddedildi
% (artifacts/1/stiction_test/20260518_111200/). Cold-start dahil tüm test
% edilen duty seviyelerinde motor başlıyor. R6 anomalisi (T7 +0.00) parsing
% artefaktıydı — eski firmware OMEGA alanını göndermiyordu. Bu nedenle ilk
% yorum metnindeki "stiction" referansı kaldırıldı.
if V_dead_pos < 0.05 && abs(V_dead_neg) < 0.05
    note = sprintf(['Dinamik dead-band ihmal edilebilir (CW %.3f V, CCW %.3f V). ' ...
        'Bağımsız stiction doğrulama testi (2026-05-18) sonucu: stiction da yok — ' ...
        'motor cold-start dahil %%10 duty''den itibaren dönüyor. R6 anomalisi ' ...
        'analiz/parsing artefaktıydı.'], ...
        V_dead_pos, V_dead_neg);
elseif V_dead_pos > 0.5 || abs(V_dead_neg) > 0.5
    note = sprintf(['Belirgin dead-band tespit edildi (CW %.3f V, CCW %.3f V). ' ...
        'V_eff < V_dead bölgesinde motor durur.'], V_dead_pos, V_dead_neg);
else
    note = sprintf(['Küçük dead-band (CW %.3f V, CCW %.3f V) — kontrolcü için ' ...
        'gerekirse compensation eklenebilir, ihmal de edilebilir.'], V_dead_pos, V_dead_neg);
end
dead_band.note = note;
fprintf('Dead-band: V_dead^+ = %+.3f V, V_dead^- = %+.3f V, R²_+ = %.4f, R²_- = %.4f\n', ...
    V_dead_pos, V_dead_neg, R2_pos, R2_neg);
end

function [m, b, R2] = lin_fit_(x, y)
    if numel(x) < 2
        m = NaN; b = NaN; R2 = NaN; return
    end
    p = polyfit(x, y, 1);
    m = p(1); b = p(2);
    y_fit = polyval(p, x);
    ss_res = sum((y - y_fit).^2);
    ss_tot = sum((y - mean(y)).^2);
    if ss_tot > 0
        R2 = 1 - ss_res / ss_tot;
    else
        R2 = NaN;
    end
end
