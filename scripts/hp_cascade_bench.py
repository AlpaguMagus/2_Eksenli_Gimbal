#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP cascade bench validasyon (Faz 3) — eksen-0 POS step yanıtı (≤0.5 cap, mil serbest).

Faz 2 analitik kazançları (hp_cascade_design.m) firmware'e girdikten sonra HP cascade'i
doğrular: pozisyon P (Kp_pos=2.0) → hız PI (Kp=0.00167/Ki=0.0548), HP plant (Kg=1043, τ≈70ms).
ASIL SORU: HP serbest-milde temiz oturuyor mu, yoksa stiction (breakaway 0.21≫kinetik 0.14)
stick-slip/limit-cycle mi veriyor?

⚠ HP-SPESİFİK: θ_out = EC × 360/960 (HP 20:1 → cpr=960; LP'nin 466'sı DEĞİL). Firmware de cpr=960
kullanır → TR telemetrisi de doğru; çapraz-kontrol için ikisini de okur.
Güvenlik: duty firmware'de ±0.50 cap; EC-freeze canary (dropout/OCP); mil serbest, DOKUNMA.
Çıktı: artifacts/3/hp_cascade_bench/<ts>/
Kaynaklar: [Franklin2010] §6.4 (cascade), §4.3 (tip-1 ss), §3.5 (step metrikleri)
"""
import argparse, csv, datetime as dt, json, re, subprocess, sys, time, os
import serial

EC_RE   = re.compile(r",EC:(-?\d+)")
OMEGA_RE= re.compile(r",OMEGA:(-?[\d.]+)")
SP_RE   = re.compile(r",SP:(-?[\d.]+)")
U_RE    = re.compile(r",U:(-?[\d.]+)")
TR_RE   = re.compile(r",TR:(-?[\d.]+)")
HEARTBEAT_S = 0.25
CPR_OUT = 960.0                  # HP çıkış mili event/rev (48 × 20)
DEG_PER_COUNT = 360.0 / CPR_OUT
SETTLE_BAND_DEG = 2.0
LIMIT_CYCLE_DEG = 2.0

def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def mean(x): return sum(x)/len(x) if x else 0.0
def std(x):
    if len(x)<2: return 0.0
    m=mean(x); return (sum((v-m)**2 for v in x)/len(x))**0.5
def send(ser,c): ser.write((c+"\n").encode())

def run_segment(ser, target_deg, hold_s, writer, seg_idx, t0g):
    send(ser, f"POS_DEG:{target_deg}")
    print(f"[{ts()}] seg {seg_idx:2d}  POS_DEG:{target_deg:+.0f}°", flush=True)
    t0=time.time(); last_hb=t0; last_p=t0
    samples=[]   # (t_seg, theta, omega, u, sp, tr)
    while time.time()-t0 < hold_s:
        now=time.time()
        if now-last_hb>=HEARTBEAT_S: send(ser,"PING"); last_hb=now
        line=ser.readline().decode("utf-8","ignore").strip()
        mec=EC_RE.search(line)
        if not mec: continue
        ec=int(mec.group(1)); theta=ec*DEG_PER_COUNT
        mo=OMEGA_RE.search(line); ms=SP_RE.search(line); mu=U_RE.search(line); mt=TR_RE.search(line)
        om=float(mo.group(1)) if mo else 0.0
        sp=float(ms.group(1)) if ms else 0.0
        u =float(mu.group(1)) if mu else 0.0
        tr=float(mt.group(1)) if mt else 0.0
        t_seg=now-t0; samples.append((t_seg,theta,om,u,sp,tr))
        writer.writerow([seg_idx,target_deg,f"{now-t0g:.4f}",f"{t_seg:.4f}",ec,
                         f"{theta:.2f}",f"{om:.1f}",f"{u:.3f}",f"{sp:.1f}",f"{tr:.2f}"])
        if now-last_p>=0.5:
            print(f"    t={t_seg:4.1f}s  θ={theta:+7.2f}° (TR={tr:+6.1f})  ω={om:+6.1f}  u={u:+.3f}")
            last_p=now
    return compute_metrics(target_deg, samples)

def compute_metrics(target, s):
    if len(s)<10: return {"target":target,"n":len(s),"valid":False}
    t=[x[0] for x in s]; th=[x[1] for x in s]
    th0=th[0]; span=abs(target-th0)
    tail=th[int(len(th)*0.6):]; th_ss=mean(tail)
    ss=abs(th_ss-target); ss_pct=ss/abs(span)*100 if span>1 else 0.0
    if target>=th0: ov=max(0.0,max(th)-target)
    else:           ov=max(0.0,target-min(th))
    ov_pct=ov/abs(span)*100 if span>1 else 0.0
    settle=None
    for i in range(len(th)):
        if all(abs(v-target)<=SETTLE_BAND_DEG for v in th[i:]): settle=t[i]; break
    th_std=std(tail)
    # Kuyrukta ω≈0 ama hedefe ulaşılmadı → AYIR: düşük duty=stiction stick-slip / cap'te=gerçek dropout
    omt=[abs(x[2]) for x in s[int(len(s)*0.6):]]
    ut =[abs(x[3]) for x in s[int(len(s)*0.6):]]
    near0 = (ss>SETTLE_BAND_DEG*3) and (max(omt) < 50)
    stuck   = near0 and (max(ut) < 0.45)    # düşük duty'de yapışık = stiction stick-slip (OCP değil)
    dropout = near0 and (max(ut) >= 0.45)   # cap'te donma = gerçek OCP/dropout
    return {"target":target,"n":len(s),"valid":True,"theta_start":round(th0,1),
            "theta_ss":round(th_ss,2),"ss_err_deg":round(ss,2),"ss_err_pct":round(ss_pct,1),
            "overshoot_deg":round(ov,2),"overshoot_pct":round(ov_pct,1),
            "settling_s":round(settle,3) if settle else None,
            "theta_std_ss":round(th_std,2),"limit_cycle":th_std>LIMIT_CYCLE_DEG,
            "stuck":stuck,"dropout":dropout}

def make_plot(out, rows, targets):
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    except Exception: return None
    if not rows: return None
    tg=[float(r[2]) for r in rows]; th=[float(r[5]) for r in rows]
    om=[float(r[6]) for r in rows]; u=[float(r[7]) for r in rows]
    sp=[float(r[8]) for r in rows]; tgt=[float(r[1]) for r in rows]
    fig,ax=plt.subplots(3,1,figsize=(11,8),sharex=True)
    ax[0].plot(tg,th,'b',lw=1.3,label='θ_out (EC×360/960)'); ax[0].plot(tg,tgt,'r--',lw=1.0,label='hedef')
    ax[0].set_ylabel('θ çıkış mili (°)'); ax[0].legend(loc='best'); ax[0].grid(alpha=0.3)
    ax[0].set_title('Faz 3 — HP cascade POS step (eksen-0, ≤0.5 cap)')
    ax[1].plot(tg,sp,'m',lw=0.9,label='ω_ref (dış P)'); ax[1].plot(tg,om,'b',lw=1.1,label='ω ölçülen')
    ax[1].set_ylabel('ω motor (rad/s)'); ax[1].legend(loc='best'); ax[1].grid(alpha=0.3)
    ax[2].plot(tg,u,'k',lw=0.9); ax[2].axhline(0.5,ls=':',c='r',lw=0.8); ax[2].axhline(-0.5,ls=':',c='r',lw=0.8)
    ax[2].set_ylabel('duty u'); ax[2].set_xlabel('t (s)'); ax[2].set_ylim(-0.58,0.58); ax[2].grid(alpha=0.3)
    fig.tight_layout(); p=os.path.join(out,"hp_cascade_plot.png"); fig.savefig(p,dpi=130); plt.close(fig)
    return p

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--port",default="/dev/ttyACM0"); ap.add_argument("--baud",type=int,default=115200)
    ap.add_argument("--targets",type=float,nargs="+",default=[30,90,45,0,-45,0])
    ap.add_argument("--kpp",type=float,default=2.0); ap.add_argument("--hold",type=float,default=4.0)
    ap.add_argument("--ff",action="store_true",help="Coulomb FF aç (analitik §12.12.4: LFFG:0 LFFC LFFDB LFF:1)")
    ap.add_argument("--lffc",type=float,default=0.14,help="kff_coul = u_c (kinetik, Faz1)")
    ap.add_argument("--lffdb",type=float,default=0.35,help="coul_db (rad/s, anti-chatter)")
    args=ap.parse_args()
    print(f"[{ts()}] HP cascade bench — Kp_pos={args.kpp}, hedefler={args.targets}")
    print(f"[{ts()}] DOKUNMA — mil serbest. HP cpr=960. duty ±0.5 cap.\n")
    try: ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e: print(f"[ERR] Port: {e}"); return 2
    out=os.path.join("artifacts","3","hp_cascade_bench",dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
    os.makedirs(os.path.join(out,"raw"),exist_ok=True)
    rawp=os.path.join(out,"raw","data.csv"); results=[]; allrows=[]
    try:
        ser.reset_input_buffer(); send(ser,"PING"); time.sleep(0.3)
        send(ser,"MODE:POS"); time.sleep(0.1); send(ser,f"KPP:{args.kpp}"); time.sleep(0.05)
        if args.ff:
            send(ser,"LFFG:0"); time.sleep(0.05)            # serbest-mil dengeli → gravite FF YOK
            send(ser,f"LFFC:{args.lffc}"); time.sleep(0.05) # Coulomb FF = ölçülen kinetik sürtünme
            send(ser,f"LFFDB:{args.lffdb}"); time.sleep(0.05)
            send(ser,"LFF:1"); time.sleep(0.05)
            print(f"[{ts()}] Coulomb FF AÇIK (analitik): kff_grav=0, kff_coul={args.lffc}, coul_db={args.lffdb}")
        ser.reset_input_buffer(); t0g=time.time()
        with open(rawp,"w",newline="") as fh:
            w=csv.writer(fh)
            w.writerow(["seg","target_deg","t_global","t_seg","ec","theta_deg","omega","u","sp","tr"])
            class Tee:
                def writerow(self,row): w.writerow(row); allrows.append(row)
            tee=Tee()
            for i,tg in enumerate(args.targets,1):
                m=run_segment(ser,tg,args.hold,tee,i,t0g); results.append(m)
                if m.get("valid"):
                    lc="⚠LIMIT-CYCLE" if m["limit_cycle"] else ("⚠DROPOUT(OCP)" if m.get("dropout") else ("⚠STICK-SLIP" if m.get("stuck") else "OK"))
                    st=f'{m["settling_s"]}s' if m["settling_s"] else "—"
                    print(f'      θ_ss={m["theta_ss"]:+7.2f}° ss_err={m["ss_err_deg"]:.2f}° '
                          f'OS={m["overshoot_deg"]:.2f}° settle={st} θ_std={m["theta_std_ss"]:.2f}° {lc}')
        send(ser,"LFF:0"); send(ser,"STOP"); send(ser,"MODE:DUTY"); time.sleep(0.2)  # FF güvenlik kapatma
    finally:
        try: ser.write(b"LFF:0\nSTOP\nMODE:DUTY\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    plot=make_plot(out, allrows, args.targets)
    valid=[r for r in results if r.get("valid")]
    n_lc=sum(1 for r in valid if r["limit_cycle"])
    n_drop=sum(1 for r in valid if r.get("dropout")); n_stuck=sum(1 for r in valid if r.get("stuck"))
    reached=lambda r: r["ss_err_deg"]<=SETTLE_BAND_DEG and r["settling_s"] is not None
    n_noreach=sum(1 for r in valid if not reached(r))
    if valid and n_lc==0 and n_noreach==0 and n_drop==0 and n_stuck==0: status="PASS"
    elif n_drop: status="DROPOUT"
    elif n_stuck: status="STICK_SLIP"
    elif n_lc: status="LIMIT_CYCLE"
    elif n_noreach: status="NO_REACH"
    else: status="PARTIAL"

    with open(os.path.join(out,"summary.md"),"w") as f:
        f.write(f"# Faz 3 — HP cascade bench validasyon (eksen-0 POS step)\n\n")
        f.write(f"- **Test ID:** HP-cascade-bench · **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M} · **Commit:** `{commit()}` · **Durum:** {status}\n")
        f.write(f"- **Mimari:** cascade — poz P Kp_pos={args.kpp} → hız PI Kp=0.00167/Ki=0.0548 (HP, hp_cascade_design.m)\n")
        f.write(f"- **Coulomb FF:** {('AÇIK — kff_coul=%.2f, coul_db=%.2f (analitik §12.12.4)' % (args.lffc,args.lffdb)) if args.ff else 'KAPALI'}\n")
        f.write(f"- **Plant:** Kg=1043 rad/s/duty, τ≈70ms (Faz1); gear=20, cpr=960; duty ±0.5 cap\n")
        f.write(f"- **Hedefler:** {args.targets} (mutlak çıkış mili açısı °) · mil serbest\n\n")
        f.write("## Sonuçlar\n\n| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |\n|---|---|---|---|---|---|---|\n")
        for r in results:
            if not r.get("valid"): f.write(f"| {r['target']:+.0f}° | — | — | — | — | — | ✗ |\n"); continue
            st=f'{r["settling_s"]}s' if r["settling_s"] else "—"
            d="⚠ LIMIT-CYCLE" if r["limit_cycle"] else ("⚠ DROPOUT" if r.get("dropout") else ("⚠ STICK-SLIP" if r.get("stuck") else "🟢 OK"))
            f.write(f"| {r['target']:+.0f}° | {r['theta_ss']:+.2f}° | {r['ss_err_deg']} | {r['overshoot_deg']} | {st} | {r['theta_std_ss']} | {d} |\n")
        f.write(f"\n## Durum: **{status}**\n\n")
        f.write("## Hedef (Faz 3 PASS)\n- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°, dropout YOK\n")
        f.write("- θ_out = EC × 360/960 (HP 20:1, kuant. 0.375°/count — LP'nin 466'sından ince)\n")
        f.write(f"\n## Artifacts\n- raw/data.csv")
        if plot: f.write(f"\n- {os.path.basename(plot)} (θ takip + ω_ref/ω + u)")
    meta={"test_id":"3.HP-cascade-bench","timestamp":dt.datetime.now().isoformat(timespec="seconds"),
          "commit":commit(),"status":status,"kp_pos":args.kpp,
          "inner":{"Kp":0.00167,"Ki":0.0548},"plant":{"Kg":1043,"tau_ms":70,"gear":20,"cpr":960},
          "coulomb_ff":{"enabled":bool(args.ff),"kff_coul":args.lffc,"coul_db":args.lffdb},
          "targets":args.targets,"results":results}
    json.dump(meta,open(os.path.join(out,"meta.json"),"w"),indent=2,ensure_ascii=False)
    print(f"\n[{ts()}] ── ÖZET ── Durum: {status}  ({len(valid)-n_lc-n_drop-n_stuck}/{len(valid)} temiz)")
    print(f"[{ts()}] Artifact: {out}/")
    if plot: print(f"[{ts()}] Plot: {plot}")
    return 0

if __name__=="__main__": sys.exit(main())
