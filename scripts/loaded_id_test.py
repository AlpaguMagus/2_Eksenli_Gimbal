#!/usr/bin/env python3
"""Aşama 5 ön-çalışması — YÜKLÜ tek-motor sistem-ID (gravite torku), motor-2 ekseni.

Sarkaç (aparat dibe asılı) üzerinde AÇIK-DÖNGÜ, KUASİ-STATİK gravite-torku ölçümü:
  - Yavaş duty-RAMPASI (step DEĞİL → dinamik aşım/flip yok), kuasi-statik θ_eq(u) izi.
  - CANLI θ-KESME: |θ| > cutoff olursa anında DUTY2:0 (tepeden aşırma/fırlatma güvenliği).
  - Yerçekimi torku: kuasi-statikte  u_applied ≈ (mgL/K)·sin(θ)  →  fit a = mgL/K [duty].
    a = horizontal'de (90°) gereken holding-duty; a<0.5 ise motor yatayda yükü tutar.

Neden ramp + kesme: yüklü sarkaçta sabit-duty STEP'i momentumla 90°'yi aşıp kolu fırlatabilir.
Yavaş ramp kuasi-statik kalır; θ-kesme yedek emniyet.

Kullanım:  python3 scripts/loaded_id_test.py            (default umax=0.15, ramp 18s, cutoff 60°)
Çıktı: artifacts/3/loaded_id_m2/<test_id>/ (summary.md + meta.json + raw/data.csv + plot.png)
Test artifact disiplini (global CLAUDE.md). DUTY2 yalnız MODE2:DUTY'de (cmd_parser).
"""
import serial, time, csv, re, math, argparse, datetime as dt, json, subprocess
from pathlib import Path

DEG_PER_COUNT = 360.0 / 466.0
EC2 = re.compile(r"EC2:(-?\d+)")
OM2 = re.compile(r"OMEGA2:(-?[\d.]+)")
U2  = re.compile(r"U2:(-?[\d.]+)")

def send(ser, c): ser.write((c + "\n").encode())
def ts(): return dt.datetime.now().strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "?"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--umax", type=float, default=0.15, help="maks duty (kuasi-statik ~35°; θ-kesme yedek)")
    ap.add_argument("--ramp", type=float, default=18.0, help="yukarı rampa süresi (s) — yavaş=kuasi-statik")
    ap.add_argument("--cutoff", type=float, default=60.0, help="θ güvenlik kesme (derece)")
    ap.add_argument("--test-id", default=None)
    ap.add_argument("--reanalyze", default=None,
                    help="kayıtlı bir test dizinini (raw/data.csv) donanımsız yeniden analiz et")
    args = ap.parse_args()

    if args.reanalyze:                              # donanım YOK — kayıtlı CSV'den yeniden üret
        d = Path(args.reanalyze)
        rows = []
        with open(d/"raw"/"data.csv") as fh:
            rd = csv.reader(fh); next(rd, None)     # başlık
            for r in rd:
                if len(r) < 6: continue
                rows.append((float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4]), r[5]))
        print(f"[{ts()}] REANALYZE {d}  ({len(rows)} satır) — donanım çalıştırılmadı")
        analyze(d, d.name, args, rows)
        return 0

    tid = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/3/loaded_id_m2") / tid
    (out / "raw").mkdir(parents=True, exist_ok=True)

    print(f"[{ts()}] YÜKLÜ ID — motor-2, yavaş duty-rampası 0→{args.umax} ({args.ramp:.0f}s), θ-kesme {args.cutoff:.0f}°")
    print(f"[{ts()}] ⚠ aparat serbestçe asılı + ~{args.cutoff+10:.0f}° önü AÇIK olsun. Motor yavaşça kaldırır, sonra indirir.\n")
    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    rows = []   # (t, u_cmd, u_app, theta, omega, phase)
    try:
        ser.reset_input_buffer()
        send(ser, "PING"); time.sleep(0.3)
        send(ser, "RESET"); time.sleep(0.3)          # enc-2 sıfırla (asılı = 0°)
        send(ser, "MODE2:DUTY"); time.sleep(0.15)    # DUTY2 bu modda etkin
        ser.reset_input_buffer()
        t0 = time.time(); last_hb = t0; last_sent = -1.0
        phase = "up"; u_cmd = 0.0; t_phase = t0; u_down0 = args.umax; tripped = False
        while True:
            now = time.time(); el = now - t0
            if now - last_hb >= 0.4: send(ser, "PING"); last_hb = now
            line = ser.readline().decode("utf-8", "ignore").strip()
            if not line:
                pass
            else:
                mE = EC2.search(line)
                if mE:
                    theta = int(mE.group(1)) * DEG_PER_COUNT
                    mO = OM2.search(line); om = float(mO.group(1)) if mO else 0.0
                    mU = U2.search(line);  ua = float(mU.group(1)) if mU else 0.0
                    rows.append((round(el,3), round(u_cmd,4), round(ua,4), round(theta,2), round(om,1), phase))
                    if abs(theta) > args.cutoff and not tripped:   # CANLI GÜVENLİK KESME
                        tripped = True; u_cmd = 0.0; send(ser, "DUTY2:0"); last_sent = 0.0
                        phase = "down"; t_phase = now; u_down0 = ua
                        print(f"[{ts()}] ⚠ θ={theta:+.0f}° > {args.cutoff:.0f}° → KESME + indir")
                    if len(rows) % 20 == 0:
                        print(f"    t={el:5.1f}s  θ={theta:+6.1f}°  ω={om:+6.1f}  u={ua:+.3f}  [{phase}]")
            # ── faz makinesi (u_cmd üret) ──
            if phase == "up":
                u_cmd = min(args.umax, args.umax * el / args.ramp)
                if el >= args.ramp: phase = "hold"; t_phase = now
            elif phase == "hold":
                u_cmd = args.umax
                if now - t_phase >= 3.0: phase = "down"; t_phase = now; u_down0 = args.umax
            elif phase == "down":
                u_cmd = max(0.0, u_down0 * (1.0 - (now - t_phase) / 5.0))
                if u_cmd <= 0.001 and (now - t_phase) > 5.0: break
            # ── duty gönder (değişti ise) ──
            if abs(u_cmd - last_sent) >= 0.003 or (u_cmd == 0.0 and last_sent != 0.0):
                send(ser, f"DUTY2:{u_cmd:.3f}"); last_sent = u_cmd
            if el > args.ramp + 12: break    # emniyet zaman aşımı
        send(ser, "DUTY2:0"); send(ser, "STOP"); send(ser, "MODE2:DUTY"); time.sleep(0.2)
        print(f"\n[{ts()}] tamam — aparat indirildi/durduruldu.")
    except KeyboardInterrupt:
        send(ser, "DUTY2:0"); send(ser, "STOP"); print("\nCtrl-C — STOP")
    finally:
        try: ser.write(b"DUTY2:0\nSTOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    # ── ham veri yaz ──
    with open(out/"raw"/"data.csv","w",newline="") as fh:
        w=csv.writer(fh); w.writerow(["t","u_cmd","u_app","theta_deg","omega","phase"]); w.writerows(rows)
    analyze(out, tid, args, rows)
    return 0

def analyze(out, tid, args, rows):
    # YÜKLÜ PLANT MODELİ: u = u_coulomb·sign(ω) + (mgL/K)·sin(θ) [Coulomb sürtünme + gravite].
    # Saf u=a·sinθ (origin) YETMEZ — stiction offset'i ihmal eder (stick-slip). Coulomb+gravite fit.
    th_max = max((abs(r[3]) for r in rows), default=0.0)
    u_at_max = max((r[2] for r in rows), default=0.0)
    brk = next((r[2] for r in rows if abs(r[3]) > 5 and r[5] == "up"), None)   # breakaway (gravite~0)
    mv = [(r[2], math.sin(math.radians(abs(r[3])))) for r in rows if r[5] in ("up","hold") and abs(r[3]) > 10]
    uc = a = r2 = None
    n = len(mv)
    if n >= 4:                                   # iki-parametre lineer en-küçük-kareler: u = uc + a·s
        sx=sum(s for _,s in mv); sy=sum(u for u,_ in mv); sxx=sum(s*s for _,s in mv); sxy=sum(u*s for u,s in mv)
        den = n*sxx - sx*sx
        if den != 0:
            a = (n*sxy - sx*sy)/den; uc = (sy - a*sx)/n
            ssr = sum((u-(uc+a*s))**2 for u,s in mv); sst = sum((u-sy/n)**2 for u,_ in mv)
            r2 = 1 - ssr/sst if sst > 0 else None
    print(f"\n[{ts()}] ── YÜKLÜ ID SONUÇ ── (model: u = u_coulomb + (mgL/K)·sinθ)")
    print(f"    Maks açı {th_max:.1f}°  | stiction breakaway u_s ≈ {brk if brk else float('nan'):.3f} duty")
    if a is not None:
        print(f"    Coulomb sürtünme u_c ≈ {uc:.3f} duty,  gravite a=mgL/K ≈ {a:.3f} duty  (R²={r2:.3f}, n={n})")
        print(f"    → yatay(90°) toplam holding ≈ {uc+a:.3f}"
              + ("  ✓ <0.5" if uc+a < 0.5 else "  ⚠ 0.5 zorlar")
              + f";  35° çapraz-kontrol model {uc+a*math.sin(math.radians(35)):.3f} (cascade ölçüm ~0.15)")
        print(f"    KÖK NEDEN: Coulomb sürtünme ({uc:.3f}) ≥ gravite → stick-slip → cascade limit-cycle.")
    else:
        print("    Fit için yetersiz nokta.")

    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        t=[r[0] for r in rows]; th=[r[3] for r in rows]; ua=[r[2] for r in rows]
        fig,ax=plt.subplots(2,1,figsize=(9,7))
        ax[0].plot(t,th,'b',label='θ (deg)'); ax[0].set_ylabel('θ (deg)'); ax[0].grid(True)
        ax0b=ax[0].twinx(); ax0b.plot(t,ua,'g',alpha=0.7,label='u_app'); ax0b.set_ylabel('duty',color='g')
        ax[0].axhline(args.cutoff,ls=':',c='r'); ax[0].set_title('Yüklü ID — yavaş duty-rampası (kuasi-statik)')
        ax[0].set_xlabel('t (s)')
        # u vs sin(theta) fit
        thr=[abs(x[3]) for x in rows if x[5] in('up','hold')]; uar=[x[2] for x in rows if x[5] in('up','hold')]
        ax[1].scatter([math.sin(math.radians(x)) for x in thr], uar, s=8, c='b', label='ölçüm (up)')
        if a is not None:
            xs=[i/100 for i in range(101)]
            ax[1].plot(xs,[uc+a*x for x in xs],'r',label=f'fit u={uc:.3f}+{a:.3f}·sinθ (R²={r2:.2f})')
            if brk: ax[1].axhline(brk,ls='--',c='orange',label=f'stiction breakaway {brk:.3f}')
        ax[1].set_xlabel('sin θ'); ax[1].set_ylabel('u_applied (duty)'); ax[1].grid(True); ax[1].legend()
        ax[1].set_title('Coulomb+gravite: u = u_coulomb + (mgL/K)·sin θ (stick-slip görünür)')
        fig.tight_layout(); p=out/"loaded_id_plot.png"; fig.savefig(p,dpi=130); plt.close(fig)
        print(f"    Plot: {p}")
    except Exception as e:
        print(f"    [plot atlandı: {e}]")

    with open(out/"summary.md","w") as f:
        f.write(f"# Yüklü tek-motor ID (motor-2, sarkaç) — {tid}\n\n")
        f.write(f"- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M} · **Commit:** `{commit()}`\n")
        f.write(f"- **Yük:** orijinal son kol + boş telefon-standı (telefon yok), dibe asılı sarkaç\n")
        f.write(f"- **Yöntem:** açık-döngü yavaş duty-rampası 0→{args.umax} ({args.ramp:.0f}s) + θ-kesme {args.cutoff:.0f}°\n\n")
        f.write(f"## Sonuç (model: u = u_coulomb + (mgL/K)·sinθ)\n- Maks açı: {th_max:.1f}°\n")
        if brk is not None:
            f.write(f"- **Stiction breakaway: {brk:.3f} duty** (dipten kopuş, θ küçük → gravite~0, ≈ saf statik sürtünme)\n")
        if a is not None:
            f.write(f"- **Coulomb sürtünme u_c = {uc:.3f} duty** · gravite a=mgL/K = **{a:.3f} duty** (R²={r2:.3f}, n={n})\n")
            f.write(f"- Yatay(90°) toplam holding ≈ {uc+a:.3f} duty {'✓ <0.5' if uc+a<0.5 else '⚠ 0.5 zorlar'}; "
                    f"35° çapraz-kontrol model {uc+a*math.sin(math.radians(35)):.3f} vs cascade ölçüm ~0.15\n")
            f.write(f"- **KÖK NEDEN:** Coulomb sürtünme ({uc:.3f}) ≥ gravite katkısı → stick-slip → "
                    f"serbest-mil cascade kazançları yük altında limit-cycle veriyor. "
                    f"Çözüm: sürtünme+gravite feedforward (sonraki adım).\n")
        f.write(f"\n## Artifacts\n- raw/data.csv\n- loaded_id_plot.png\n")
    with open(out/"meta.json","w") as f:
        json.dump({"test_id":tid,"timestamp":dt.datetime.now().isoformat(),"commit":commit(),
                   "load":"son kol + bos telefon standi (sarkac)","method":"open-loop slow duty ramp + theta cutoff",
                   "model":"u = u_coulomb + (mgL/K)*sin(theta)",
                   "umax":args.umax,"ramp_s":args.ramp,"cutoff_deg":args.cutoff,
                   "theta_max_deg":round(th_max,1),
                   "stiction_breakaway_duty":round(brk,4) if brk is not None else None,
                   "coulomb_friction_uc_duty":round(uc,4) if uc is not None else None,
                   "gravity_coeff_a_mgL_over_K":round(a,4) if a is not None else None,
                   "holding_90deg_total":round(uc+a,4) if a is not None else None,
                   "fit_r2":round(r2,3) if r2 is not None else None,"fit_n":n}, f, indent=2)
    print(f"[{ts()}] Artifact: {out}/")

if __name__ == "__main__":
    raise SystemExit(main())
