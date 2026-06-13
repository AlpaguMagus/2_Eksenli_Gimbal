#!/usr/bin/env python3
"""Aşama 3 — YÜKLÜ cascade feedforward bench re-test (motor-2 ekseni).

AMAÇ: Yüklü-ID'nin ölçtüğü stick-slip limit-cycle'ı (serbest-mil cascade kazançları
yük altında, probe artifacts/3/cascade_m2/20260613_loaded_empty_probe: 20°/50°
limit-cycle) sürtünme+gravite feedforward'unun bastırdığını GERÇEK motorda doğrula
ve FF yapısını (sign vs ölü-bant) gerçek veriyle seç.

YÖNTEM: MODE2:POS cascade. Her (FF yapısı × setpoint) için açıya basamak ver,
~6 s tut, son ~3 s θ'nın std'sini ölç (limit-cycle göstergesi — sim metriğiyle aynı).
4 FF yapısı (firmware komutlarıyla):
  off  : LFF2:0                                  (baseline — limit-cycle'ı doğrula)
  grav : LFFG2:.097 LFFC2:0 LFF2:1               (yalnız gravite — sim: yetersiz)
  db   : LFFG2:.097 LFFC2:.090 LFFDB2:.34 LFF2:1 (firmware default — chatter-safe)
  sign : LFFDB2:0 (db→0)                         (saf sign — sim ideal, chatter riski)

GÜVENLİK: POS kapalı-döngü (açıyı aşmaz) AMA θ-kesme yedek (|θ|>cutoff → STOP).
Aparat dibe asılı + ~75° önü AÇIK olsun. Telefon YOK (boş stand).

Kullanım:  python3 scripts/loaded_ff_test.py            (setpoints 20/50, dwell 6s)
           python3 scripts/loaded_ff_test.py --reanalyze artifacts/3/loaded_ff_m2/<id>
Çıktı: artifacts/3/loaded_ff_m2/<test_id>/ (summary.md + meta.json + raw/data.csv + plot.png)
Test artifact disiplini (global CLAUDE.md).
"""
import serial, time, csv, re, math, argparse, datetime as dt, json, subprocess
from pathlib import Path

DEG_PER_COUNT = 360.0 / 466.0
EC2 = re.compile(r"EC2:(-?\d+)")
TR2 = re.compile(r"TR2:(-?[\d.]+)")
U2  = re.compile(r"U2:(-?[\d.]+)")

# FF yapısı → firmware komut dizisi (eksen-2)
FF_SETUP = {
    "off":  ["LFF2:0"],
    "grav": ["LFFG2:0.097", "LFFC2:0", "LFF2:1"],
    "db":   ["LFFG2:0.097", "LFFC2:0.090", "LFFDB2:0.34", "LFF2:1"],
    "sign": ["LFFG2:0.097", "LFFC2:0.090", "LFFDB2:0", "LFF2:1"],
}
FF_ORDER = ["off", "grav", "db", "sign"]

def send(ser, c): ser.write((c + "\n").encode())
def ts(): return dt.datetime.now().strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "?"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--setpoints", default="20,50", help="virgüllü açı listesi (limit-cycle açıları)")
    ap.add_argument("--dwell", type=float, default=6.0, help="her segment tutma süresi (s)")
    ap.add_argument("--cutoff", type=float, default=75.0, help="θ güvenlik kesme (derece)")
    ap.add_argument("--test-id", default=None)
    ap.add_argument("--reanalyze", default=None, help="kayıtlı dizini donanımsız yeniden analiz et")
    args = ap.parse_args()

    if args.reanalyze:
        d = Path(args.reanalyze); rows=[]
        with open(d/"raw"/"data.csv") as fh:
            rd=csv.reader(fh); next(rd,None)
            for r in rd:
                if len(r)<6: continue
                rows.append((float(r[0]),r[1],float(r[2]),float(r[3]),float(r[4]),r[5]))
        print(f"[{ts()}] REANALYZE {d} ({len(rows)} satır) — donanım çalıştırılmadı")
        analyze(d, d.name, args, rows); return 0

    setpoints = [float(x) for x in args.setpoints.split(",")]
    tid = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/3/loaded_ff_m2") / tid
    (out/"raw").mkdir(parents=True, exist_ok=True)

    print(f"[{ts()}] YÜKLÜ FF re-test — motor-2, setpoints={setpoints}°, dwell {args.dwell:.0f}s, θ-kesme {args.cutoff:.0f}°")
    print(f"[{ts()}] FF yapıları: {FF_ORDER}.  ⚠ aparat asılı + ~{args.cutoff:.0f}° önü AÇIK, telefon YOK.\n")
    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    rows = []   # (t, ff_mode, sp, theta, u, phase)
    def read_drain(duration, ff_mode, sp, phase, t0):
        """duration boyunca telemetri oku + logla; θ-kesme kontrolü. theta listesi döndür."""
        thetas=[]; end=time.time()+duration
        while time.time() < end:
            line = ser.readline().decode("utf-8","ignore").strip()
            if not line: continue
            mE=EC2.search(line)
            if not mE: continue
            theta=int(mE.group(1))*DEG_PER_COUNT
            mU=U2.search(line); u=float(mU.group(1)) if mU else 0.0
            el=round(time.time()-t0,3)
            rows.append((el, ff_mode, sp, round(theta,2), round(u,4), phase))
            thetas.append(theta)
            if abs(theta) > args.cutoff:
                send(ser,"DUTY2:0"); send(ser,"STOP")
                print(f"[{ts()}] ⚠ θ={theta:+.0f}° > kesme → STOP"); raise KeyboardInterrupt
        return thetas

    seg_stats=[]   # (ff_mode, sp, theta_std, theta_mean, ss_err)
    try:
        ser.reset_input_buffer()
        send(ser,"PING"); time.sleep(0.3)
        send(ser,"RESET"); time.sleep(0.3)         # enc-2 sıfırla (dip=0°)
        t0=time.time()
        for sp in setpoints:
            for ff in FF_ORDER:
                # FF yapısını kur
                for c in FF_SETUP[ff]: send(ser, c); time.sleep(0.05)
                send(ser,"MODE2:POS"); time.sleep(0.1)
                print(f"[{ts()}] ── {ff:5s} @ {sp:.0f}° ──")
                # basamak ver
                send(ser, f"POS_DEG2:{sp:.1f}")
                read_drain(args.dwell, ff, sp, "hold", t0)
                # son ~3 s'lik kuyruktan limit-cycle metriği
                tail=[r[3] for r in rows if r[1]==ff and r[2]==sp][-int(3.0/0.025):]
                if len(tail)>=4:
                    mean=sum(tail)/len(tail)
                    std=(sum((x-mean)**2 for x in tail)/len(tail))**0.5
                    sserr=abs(mean-sp)
                    seg_stats.append((ff,sp,std,mean,sserr))
                    flag="⚠ LIMIT-CYCLE" if std>1.0 else "STABİL"
                    print(f"    θ_std={std:.2f}°  ss_err={sserr:.2f}°  → {flag}")
                # sıfıra dön + FF kapat
                send(ser,"LFF2:0"); send(ser, "POS_DEG2:0.0")
                read_drain(2.5, ff, sp, "return", t0)
        send(ser,"DUTY2:0"); send(ser,"STOP"); time.sleep(0.2)
        print(f"\n[{ts()}] tamam — aparat sıfıra döndü/durduruldu.")
    except KeyboardInterrupt:
        send(ser,"DUTY2:0"); send(ser,"STOP"); print("\nCtrl-C/kesme — STOP")
    finally:
        try: ser.write(b"LFF2:0\nDUTY2:0\nSTOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    with open(out/"raw"/"data.csv","w",newline="") as fh:
        w=csv.writer(fh); w.writerow(["t","ff_mode","sp","theta_deg","u","phase"]); w.writerows(rows)
    analyze(out, tid, args, rows)
    return 0

def analyze(out, tid, args, rows):
    # segment istatistikleri (kuyruk θ_std) — reanalyze'da CSV'den yeniden hesapla
    setpoints=sorted({r[2] for r in rows})
    stats={}   # (ff,sp) -> (std,mean,sserr)
    for ff in FF_ORDER:
        for sp in setpoints:
            seg=[r[3] for r in rows if r[1]==ff and r[2]==sp and r[5]=="hold"]
            tail=seg[-int(3.0/0.025):] if seg else []
            if len(tail)>=4:
                mean=sum(tail)/len(tail); std=(sum((x-mean)**2 for x in tail)/len(tail))**0.5
                stats[(ff,sp)]=(std,mean,abs(mean-sp))
    print(f"\n[{ts()}] ── YÜKLÜ FF RE-TEST SONUÇ ── (kuyruk θ_std, limit-cycle göstergesi)")
    print(f"    {'FF':6s} " + " ".join(f"{sp:.0f}°(std/ss)" for sp in setpoints))
    for ff in FF_ORDER:
        cells=[]
        for sp in setpoints:
            if (ff,sp) in stats: s=stats[(ff,sp)]; cells.append(f"{s[0]:.2f}/{s[2]:.2f}")
            else: cells.append("  -  ")
        print(f"    {ff:6s} " + "  ".join(cells))

    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        n=len(setpoints)
        fig,ax=plt.subplots(n+1,1,figsize=(10,3*(n+1)))
        if n==0: ax=[ax]
        cols={"off":"tab:blue","grav":"tab:orange","db":"tab:green","sign":"tab:red"}
        for si,sp in enumerate(setpoints):
            for ff in FF_ORDER:
                seg=[(r[0],r[3]) for r in rows if r[1]==ff and r[2]==sp and r[5]=="hold"]
                if not seg: continue
                t0s=seg[0][0]; ax[si].plot([t-t0s for t,_ in seg],[th for _,th in seg],
                                           color=cols[ff],label=ff,lw=1.1)
            ax[si].axhline(sp,ls='--',c='k',lw=0.8); ax[si].set_ylabel(f'θ @ {sp:.0f}° (°)')
            ax[si].grid(True); ax[si].legend(fontsize=8,ncol=4)
        ax[0].set_title('Yüklü cascade FF re-test — θ takip (FF yapısı kıyası)')
        # θ_std bar
        axb=ax[n]; w=0.2
        for j,ff in enumerate(FF_ORDER):
            vals=[stats.get((ff,sp),(float('nan'),))[0] for sp in setpoints]
            axb.bar([i+j*w for i in range(len(setpoints))],vals,w,label=ff,color=cols[ff])
        axb.axhline(1.0,ls='--',c='r'); axb.set_xticks([i+1.5*w for i in range(len(setpoints))])
        axb.set_xticklabels([f"{sp:.0f}°" for sp in setpoints]); axb.set_ylabel('θ_std (°)')
        axb.legend(fontsize=8,ncol=4); axb.grid(True); axb.set_title('Kuyruk θ_std (>1° limit-cycle)')
        fig.tight_layout(); p=out/"loaded_ff_plot.png"; fig.savefig(p,dpi=130); plt.close(fig)
        print(f"    Plot: {p}")
    except Exception as e:
        print(f"    [plot atlandı: {e}]")

    # PASS şartı: FF (db veya sign) limit-cycle açılarında off'a göre θ_std'yi <1°'ye indirdi
    improved=False
    for sp in setpoints:
        off=stats.get(("off",sp)); best=min((stats[(f,sp)][0] for f in ("db","sign") if (f,sp) in stats), default=None)
        if off and best is not None and off[0]>1.0 and best<1.0: improved=True
    status="PASS" if improved else "REVIEW"

    with open(out/"summary.md","w") as f:
        f.write(f"# Yüklü cascade FF re-test (motor-2) — {tid}\n\n")
        f.write(f"- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M} · **Commit:** `{commit()}` · **Durum:** {status}\n")
        f.write(f"- **Yük:** son kol + boş telefon-standı (telefon yok), dibe asılı\n")
        f.write(f"- **Yöntem:** MODE2:POS basamak; FF yapısı × setpoint; kuyruk(~3s) θ_std limit-cycle metriği\n")
        f.write(f"- **FF yapıları:** off / grav / db(default) / sign — firmware LFF*/LFFG/LFFC/LFFDB komutları\n\n")
        f.write(f"## Sonuç (θ_std° / ss_err°)\n\n| FF | " + " | ".join(f"{sp:.0f}°" for sp in setpoints) + " |\n")
        f.write("|" + "---|"*(len(setpoints)+1) + "\n")
        for ff in FF_ORDER:
            cells=[f"{stats[(ff,sp)][0]:.2f} / {stats[(ff,sp)][2]:.2f}" if (ff,sp) in stats else "-" for sp in setpoints]
            f.write(f"| {ff} | " + " | ".join(cells) + " |\n")
        f.write(f"\n## PASS/FAIL gerekçesi\n")
        f.write(f"PASS şartı: off limit-cycle (θ_std>1°) gösteren açıda FF (db|sign) θ_std<1°'ye indirir. "
                f"Sonuç: **{status}**. (sim öngörüsü design_loaded_feedforward.m: off≈2.2°, sign/db≈0°)\n")
        f.write(f"\n## Artifacts\n- raw/data.csv\n- loaded_ff_plot.png\n")
    with open(out/"meta.json","w") as f:
        json.dump({"test_id":tid,"timestamp":dt.datetime.now().isoformat(),"commit":commit(),
                   "status":status,"method":"MODE2:POS step × FF structure, tail theta_std",
                   "setpoints_deg":setpoints,"dwell_s":args.dwell,
                   "theta_std":{f"{ff}_{sp:.0f}":round(stats[(ff,sp)][0],3) for ff in FF_ORDER for sp in setpoints if (ff,sp) in stats},
                   "ss_err":{f"{ff}_{sp:.0f}":round(stats[(ff,sp)][2],3) for ff in FF_ORDER for sp in setpoints if (ff,sp) in stats},
                   "artifacts":["raw/data.csv","loaded_ff_plot.png"]}, f, indent=2)
    print(f"[{ts()}] Artifact: {out}/  (durum: {status})")

if __name__ == "__main__":
    raise SystemExit(main())
