%% hp_cascade_redesign.m — HP cascade LİMİT-CYCLE kök-neden + fix taraması (sim)
% Rijit-mount re-karakterizasyon (docs §12.13.5): plant DOĞRULANDI Kg~974/τ72ms;
% sürtünme YÖN-ASİMETRİK u_c 0.14(fwd)/0.20(rev), u_s 0.22/0.25.
% Limit-cycle YAPISAL (§12.13.4). Bu script NONLİNEER sim (Karnopp stick-slip + ω-kuantizasyon,
% firmware-eşleşik Ts=6ms) ile limit-cycle'ı ÜRETİR ve fix adaylarını ANALİTİK tarar:
%   MEVCUT (dış-P + iç-PI, kaba ω)    → limit-cycle bekleniyor (model doğrulama)
%   B  (dış-PI + iç-P)                → iç P-only sürtünmeyi kıramaz → ELENDİ (önceki koşu, ss_err 88°)
%   D  (ince ω = iyi hız-kestirimi)   → kuantizasyon kök mü?  [period-timing/Kalman, Aşama-5]
%   FF (iç-PI + Coulomb FF kinetik)   → sürtünme telafisi integral windup'ı azaltır mı?
%   D+FF                              → ikisi birlikte
% [Franklin2010] §6.4, [Olsson1998] §6, [Karnopp1985].
clear; clc; close all;
set(groot,'defaultAxesColor','w','defaultAxesXColor','k','defaultAxesYColor','k','defaultTextColor','k');
outdir=fullfile('results','hp_cascade_redesign'); if ~exist(outdir,'dir'); mkdir(outdir); end

%% PLANT + SÜRTÜNME (rijit §12.13.5)
p.Kg_fwd=974; p.Kg_rev=897; p.tau=0.072; p.Ts=0.006; p.GEAR=20; EVENTS=48;
p.uc_fwd=0.14; p.uc_rev=0.20; p.us_fwd=0.22; p.us_rev=0.25;
p.wq_coarse=(2*pi/EVENTS)/p.Ts;              % 1 count/loop ≈ 21.8 rad/s
p.wq_fine=1.0;                               % "iyi hız-kestirimi" hedefi (period-timing/Kalman)
p.duty_max=0.50; p.wref_max=300;
p.Kp_in=0.00167; p.Ki_in=0.0548;
p.Kp_pos_eff=2.0*p.GEAR*pi/180;              % dış P: deg→motor rad/s
p.ec_res=360/(EVENTS*p.GEAR);                % encoder çıkış çözünürlüğü = 0.375°/count (pozisyon kuant)
fprintf('=== HP plant (rijit §12.13.5): Kg=%g/%g tau=%gms Ts=%gms | ω-kuant kaba=%.1f ince=%.1f ===\n',...
        p.Kg_fwd,p.Kg_rev,p.tau*1e3,p.Ts*1e3,p.wq_coarse,p.wq_fine);

steps=[30 90 45 0 -45 0]; hld=2.0; Tend=numel(steps)*hld;
trf=@(tt) steps(min(numel(steps),floor(tt/hld)+1));

%% Fix adayları (opts: wq, ff, Ki_pos, inner)
cfg(1)=struct('name','MEVCUT (dış-P+iç-PI, kaba ω)  ','wq',p.wq_coarse,'ff',0,'ffsym',0,'Ki_pos',0,'inner','PI');
cfg(2)=struct('name','FF-SYM (symmetric 0.14, bench)','wq',p.wq_coarse,'ff',1,'ffsym',1,'Ki_pos',0,'inner','PI');
cfg(3)=struct('name','FF-DIR (yön-bağımlı 0.14/0.20)','wq',p.wq_coarse,'ff',1,'ffsym',0,'Ki_pos',0,'inner','PI');
cfg(4)=struct('name','D (ince ω, iç-PI, FF yok)     ','wq',p.wq_fine,  'ff',0,'ffsym',0,'Ki_pos',0,'inner','PI');
cfg(5)=struct('name','FF-DIR + D (ince ω)           ','wq',p.wq_fine,  'ff',1,'ffsym',0,'Ki_pos',0,'inner','PI');

res=struct([]);
fprintf('\n%-30s | max θ_std | max ss_err | hüküm\n',' KONFİG'); fprintf('%s\n',repmat('-',1,72));
for i=1:numel(cfg)
  [t,th,~,u]=simc(trf,Tend,p,cfg(i));
  lc=seglc(th,t,steps,hld); ss=sserr(th,t,steps,hld);
  res(i).t=t; res(i).th=th; res(i).u=u; res(i).lc=lc; res(i).ss=ss; res(i).name=cfg(i).name;
  ok = max(lc)<2 && max(ss)<2;
  fprintf('%-30s | %6.1f°  | %7.1f°  | %s\n',cfg(i).name,max(lc),max(ss),...
          tern(ok,'✅ TEMİZ',tern(max(lc)<2,'ss_err yüksek',tern(max(ss)<2,'limit-cycle','her ikisi de kötü'))));
end

%% Görsel — tüm adaylar
f=figure('Position',[80 80 1050 720],'Color','w');
col={'r',[1 .5 0],'b',[0 .6 0],'m'};
subplot(2,1,1); plot(res(1).t,arrayfun(trf,res(1).t),'k--','LineWidth',1); hold on;
for i=1:numel(res); plot(res(i).t,res(i).th,'Color',col{i},'LineWidth',1.1); end
ylabel('\theta_{out} (deg)'); grid on;
legend(['ref',{res.name}],'Location','eastoutside','Interpreter','none');
title('HP cascade fix taraması — limit-cycle kök-neden (sim, rijit §12.13.5 modeli)');
subplot(2,1,2);
for i=1:numel(res); plot(res(i).t,res(i).u,'Color',col{i},'LineWidth',0.7); hold on; end
ylabel('u (duty)'); xlabel('t (s)'); grid on; ylim([-0.55 0.55]);
legend({res.name},'Location','eastoutside','Interpreter','none');
exportgraphics(f,fullfile(outdir,'hp_redesign_scan.png'),'Resolution',150);
fprintf('\n→ Görsel: %s\n',fullfile(outdir,'hp_redesign_scan.png'));

%% ================= LOCAL FUNCTIONS =================
function [t,th,om,ulog]=simc(trf,Tend,p,c)
  N=round(Tend/p.Ts); t=(0:N-1)'*p.Ts;
  th=zeros(N,1); om=zeros(N,1); ulog=zeros(N,1);
  th_out=0; w=0; ivel=0; ipos=0; werr_prev=0; moving=false; vbuf=zeros(1,5);
  Tt=p.Kp_in/max(p.Ki_in,1e-9); Tt_pos=p.Kp_pos_eff/max(c.Ki_pos,1e-9);
  for k=1:N
    th_meas=round(th_out/p.ec_res)*p.ec_res;                  % encoder POZİSYON kuantizasyonu (bench gerçeği)
    th_err=trf(t(k))-th_meas;
    if c.Ki_pos>0; ipos=ipos+c.Ki_pos*p.Ts*th_err; wref=p.Kp_pos_eff*th_err+ipos;
    else; wref=p.Kp_pos_eff*th_err; end
    wref=max(min(wref,p.wref_max),-p.wref_max);
    vbuf=[vbuf(2:end), round(w/c.wq)*c.wq];                    % MA(5) hız filtresi (firmware Encoder_FilterSpeed): kuantize + ~12ms gecikme
    wmeas=mean(vbuf);
    werr=wref-wmeas;
    if strcmp(c.inner,'P')
      u_uns=p.Kp_in*werr;
    else
      ivel=ivel+p.Ki_in*p.Ts/2*(werr+werr_prev); u_uns=p.Kp_in*werr+ivel;
    end
    if c.ff>0                                                  % Coulomb FF (kinetik, ω_ref yönü, tanh)
      if c.ffsym; uc_ff=p.uc_fwd;                              % SYMMETRIC (bench gibi, 0.14)
      else; uc_ff=(wref>=0)*p.uc_fwd + (wref<0)*p.uc_rev; end  % YÖN-BAĞIMLI (0.14/0.20)
      u_uns=u_uns + uc_ff*tanh(wref/0.34);
    end
    u=max(min(u_uns,p.duty_max),-p.duty_max);
    if ~strcmp(c.inner,'P'); ivel=ivel+(p.Ts/Tt)*(u-u_uns);
    elseif c.Ki_pos>0; ipos=ipos+(p.Ts/Tt_pos)*(u-u_uns); end
    werr_prev=werr; ulog(k)=u;
    if w>=0; uc=p.uc_fwd; us=p.us_fwd; Kg=p.Kg_fwd; else; uc=p.uc_rev; us=p.us_rev; Kg=p.Kg_rev; end
    if ~moving; if abs(u)>us; moving=true; else; w=0; end; end
    if moving
      sgn=sign(w); if sgn==0; sgn=sign(u); end
      w_new=w+p.Ts*(Kg*(u-uc*sgn)-w)/p.tau;
      if w~=0 && sign(w_new)~=sign(w) && abs(u)<us; w_new=0; moving=false; ivel=0; end
      w=w_new;
    end
    th_out=th_out+p.Ts*(w*180/pi)/p.GEAR; th(k)=th_out; om(k)=w;
  end
end
function v=seglc(th,t,steps,hld); v=arrayfun(@(s) std(th(t>=s*hld+hld-1 & t<(s+1)*hld)),0:numel(steps)-1); end
function v=sserr(th,t,steps,hld); v=arrayfun(@(s) abs(steps(s+1)-mean(th(t>=s*hld+hld-0.5 & t<(s+1)*hld))),0:numel(steps)-1); end
function r=tern(c,a,b); if c; r=a; else; r=b; end; end
