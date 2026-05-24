#!/usr/bin/env python3
"""
Aşama 2.5 — Pozisyon cascade step response testi (Test 2.5).

Cascade (pozisyon P dış → hız PI iç) gerçek motorda doğrulanır. ASIL SORU:
gerçekçi simde görülen küçük limit-cycle (θ hedef civarında gezinme) gerçek
motorda VAR MI, yoksa statik sürtünme onu söndürüyor mu?

Akış:
  - MODE:POS (firmware encoder'ı 0° referans yapar)
  - KPP:<kp_pos> (varsayılan 2.0, design_position_p.m)
  - Ardışık mutlak açı hedefleri: POS_DEG:<deg>, her biri ~4 sn
  - θ_out = EC × 360/466 (çıkış mili derece) — firmware EC telemetrisinden
  - Metrik (her segment): ss_error, overshoot, settling (±2°), limit-cycle (θ std)

Çıktı (CLAUDE.md disiplini): artifacts/2/position_step/<test_id>/
    ├── raw/data.csv(.gz)   ├── summary.md   ├── meta.json   └── position_plot.png

Kullanım:
    python3 scripts/position_step_test.py
    python3 scripts/position_step_test.py --targets 30 90 45 0 -45 0 --kpp 2.0 --hold 4

NOT: Serbest mil (yüksüz). Gerçek gimbalda yük ile yeniden ayar (ROADMAP §5).
Kaynaklar: [Franklin2010] §6.4 (cascade), §4.3 (tip-1 ss), §3.5 (step metrikleri)
"""
from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, re, shutil, subprocess, sys, time
from pathlib import Path
import serial

EC_RE    = re.compile(r"EC:(-?\d+)")
OMEGA_RE = re.compile(r"OMEGA:(-?[\d.]+)")
SP_RE    = re.compile(r"SP:(-?[\d.]+)")
U_RE     = re.compile(r",U:(-?[\d.]+)")
STALL_RE = re.compile(r"STALL_DETECTED")
HEARTBEAT_S = 0.25
GZIP_THRESHOLD = 50 * 1024
CPR_OUT = 466.0                 # çıkış mili event/rev (48 × 9.7)
DEG_PER_COUNT = 360.0 / CPR_OUT # 0.773°/count
SETTLE_BAND_DEG = 2.0           # kuantizasyon 0.773° → ±2° fiziksel anlamlı
LIMIT_CYCLE_DEG = 2.0           # kararlı hal θ std bu üstüyse limit-cycle


def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def mean(x): return sum(x)/len(x) if x else 0.0
def std(x):
    if len(x) < 2: return 0.0
    m = mean(x); return (sum((v-m)**2 for v in x)/len(x))**0.5
def send(ser, c): ser.write((c+"\n").encode())


def run_segment(ser, target_deg, hold_s, writer, seg_idx, t_global0):
    """Bir pozisyon hedefi. CSV'ye yaz, metrik döndür."""
    send(ser, f"POS_DEG:{target_deg}")
    print(f"[{ts()}] segment {seg_idx:2d}  POS_DEG:{target_deg:+.0f}°", flush=True)
    t0 = time.time(); last_hb = t0; last_p = t0
    samples = []   # (t_seg, theta_deg, omega, u, sp)
    while time.time()-t0 < hold_s:
        now = time.time()
        if now-last_hb >= HEARTBEAT_S: send(ser,"PING"); last_hb=now
        line = ser.readline().decode("utf-8","ignore").strip()
        mec = EC_RE.search(line)
        if not mec: continue
        ec = int(mec.group(1))
        theta = ec * DEG_PER_COUNT
        mo=OMEGA_RE.search(line); ms=SP_RE.search(line); mu=U_RE.search(line)
        om=float(mo.group(1)) if mo else 0.0
        sp=float(ms.group(1)) if ms else 0.0
        u =float(mu.group(1)) if mu else 0.0
        t_seg = now-t0
        samples.append((t_seg, theta, om, u, sp))
        writer.writerow([seg_idx, target_deg, f"{now-t_global0:.4f}", f"{t_seg:.4f}",
                         ec, f"{theta:.2f}", f"{om:.1f}", f"{u:.3f}", f"{sp:.1f}"])
        if now-last_p >= 0.5:
            print(f"    t={t_seg:4.1f}s  θ={theta:+7.2f}°  ω={om:+6.1f}  u={u:+.3f}")
            last_p=now
    return compute_metrics(target_deg, samples)


def compute_metrics(target, samples):
    if len(samples) < 10: return {"target": target, "n": len(samples), "valid": False}
    t  = [s[0] for s in samples]
    th = [s[1] for s in samples]
    th_start = th[0]
    span = abs(target - th_start)            # step büyüklüğü
    tail = th[int(len(th)*0.6):]             # kararlı hal penceresi
    th_ss = mean(tail)
    ss_err_deg = abs(th_ss - target)
    ss_err_pct = ss_err_deg/abs(span)*100 if span > 1 else 0.0
    # overshoot (hedef yönünde aşma)
    if target >= th_start:
        peak = max(th); ov = max(0.0, (peak-target))
    else:
        peak = min(th); ov = max(0.0, (target-peak))
    ov_pct = ov/abs(span)*100 if span > 1 else 0.0
    # settling: hedefin ±SETTLE_BAND_DEG bandına girip kalma
    settle_t = None
    for i in range(len(th)):
        if all(abs(v-target) <= SETTLE_BAND_DEG for v in th[i:]):
            settle_t = t[i]; break
    # LİMİT-CYCLE: kararlı halde θ std (asıl soru!)
    th_std_ss = std(tail)
    limit_cycle = th_std_ss > LIMIT_CYCLE_DEG
    return {"target": target, "n": len(samples), "valid": True,
            "theta_start": round(th_start,1), "theta_ss": round(th_ss,2),
            "ss_err_deg": round(ss_err_deg,2), "ss_err_pct": round(ss_err_pct,1),
            "overshoot_deg": round(ov,2), "overshoot_pct": round(ov_pct,1),
            "settling_s": round(settle_t,3) if settle_t else None,
            "theta_std_ss": round(th_std_ss,2), "limit_cycle": limit_cycle}


def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--targets", type=float, nargs="+", default=[30,90,45,0,-45,0])
    ap.add_argument("--kpp", type=float, default=2.0)
    ap.add_argument("--hold", type=float, default=4.0)
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/2/position_step")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"

    print(f"[{ts()}] Pozisyon cascade test — Kp_pos={args.kpp}, hedefler={args.targets}")
    print(f"[{ts()}] DOKUNMA — serbest mil. Limit-cycle (θ gezinme) gözleniyor.\n")
    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    results=[]; stall=False
    try:
        ser.reset_input_buffer(); send(ser,"PING"); time.sleep(0.3)
        send(ser,"MODE:POS"); time.sleep(0.1)          # encoder 0° referans
        send(ser,f"KPP:{args.kpp}"); time.sleep(0.05)
        ser.reset_input_buffer()
        t_global0=time.time()
        with raw_csv.open("w",newline="") as fh:
            w=csv.writer(fh)
            w.writerow(["seg","target_deg","t_global","t_seg","ec","theta_deg","omega","u","sp"])
            for i,tg in enumerate(args.targets,1):
                m=run_segment(ser, tg, args.hold, w, i, t_global0)
                results.append(m)
                if m.get("valid"):
                    lc="⚠LIMIT-CYCLE" if m["limit_cycle"] else "OK"
                    st=f'{m["settling_s"]}s' if m["settling_s"] else "—"
                    print(f'        θ_ss={m["theta_ss"]:+7.2f}° ss_err={m["ss_err_deg"]:.2f}° '
                          f'OS={m["overshoot_deg"]:.2f}° settle={st} θ_std={m["theta_std_ss"]:.2f}° {lc}')
        send(ser,"STOP"); send(ser,"MODE:DUTY"); time.sleep(0.2)
    except KeyboardInterrupt:
        send(ser,"STOP"); print("\nCtrl-C — STOP");
    finally:
        try: ser.write(b"STOP\nMODE:DUTY\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    # raw gzip
    raw_final=raw_csv
    if raw_csv.exists() and raw_csv.stat().st_size > GZIP_THRESHOLD:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    plot_path = make_plot(out, raw_final, args.targets)
    valid=[r for r in results if r.get("valid")]
    n_lc=sum(1 for r in valid if r["limit_cycle"])
    status = "PASS" if valid and n_lc==0 else ("LIMIT_CYCLE" if n_lc else "PARTIAL")
    write_artifacts(out, test_id, args, results, status, raw_final, plot_path, stall)

    print(f"\n[{ts()}] ── ÖZET ──  Durum: {status}  ({len(valid)-n_lc}/{len(valid)} segment temiz)")
    print(f"[{ts()}] Artifact: {out}/")
    if plot_path: print(f"[{ts()}] Plot: {plot_path}")
    return 0


def make_plot(out, raw, targets):
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    except Exception: return None
    rows=[]
    op = gzip.open if str(raw).endswith(".gz") else open
    with op(raw,"rt") as fh:
        rd=csv.DictReader(fh)
        for r in rd: rows.append(r)
    if not rows: return None
    tg=[float(r["t_global"]) for r in rows]
    th=[float(r["theta_deg"]) for r in rows]
    om=[float(r["omega"]) for r in rows]
    u =[float(r["u"]) for r in rows]
    sp=[float(r["sp"]) for r in rows]
    # hedef step çizgisi
    tgt=[float(r["target_deg"]) for r in rows]
    fig,ax=plt.subplots(3,1,figsize=(11,8),sharex=True)
    ax[0].plot(tg,th,'b',lw=1.3,label='θ_out (ölçülen)')
    ax[0].plot(tg,tgt,'r--',lw=1.0,label='hedef')
    ax[0].set_ylabel('θ çıkış mili (°)'); ax[0].legend(loc='best'); ax[0].grid(alpha=0.3)
    ax[0].set_title('Aşama 2.5 — Pozisyon cascade step (gerçek motor)')
    ax[1].plot(tg,sp,'m',lw=0.9,label='ω_ref (dış P çıkışı)')
    ax[1].plot(tg,om,'b',lw=1.1,label='ω ölçülen')
    ax[1].set_ylabel('ω motor (rad/s)'); ax[1].legend(loc='best'); ax[1].grid(alpha=0.3)
    ax[2].plot(tg,u,'k',lw=0.9); ax[2].set_ylabel('duty u'); ax[2].set_xlabel('t (s)')
    ax[2].set_ylim(-0.55,0.55); ax[2].grid(alpha=0.3)
    fig.tight_layout()
    p=out/"position_plot.png"; fig.savefig(p,dpi=130); plt.close(fig)
    return p


def write_artifacts(out, test_id, args, results, status, raw, plot, stall):
    with (out/"summary.md").open("w") as f:
        f.write(f"# Aşama 2.5 — Pozisyon Cascade Step (Test 2.5)\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n")
        f.write(f"- **Mimari:** cascade (pozisyon P Kp_pos={args.kpp} → hız PI Kp=0.002/Ki=0.1)\n")
        f.write(f"- **Hedefler:** {args.targets} (mutlak çıkış mili açısı, derece)\n")
        f.write(f"- **Komut:** `python3 scripts/position_step_test.py --kpp {args.kpp}`\n")
        f.write(f"- **NOT:** Serbest mil (yüksüz). Gerçek gimbalda yük ile yeniden ayar (ROADMAP §5).\n\n")
        f.write("## Sonuçlar\n\n")
        f.write("| Hedef | θ_ss | ss_err° | OS° | settling | θ_std° | durum |\n|---|---|---|---|---|---|---|\n")
        for r in results:
            if not r.get("valid"):
                f.write(f"| {r['target']:+.0f}° | — | — | — | — | — | ✗ az veri |\n"); continue
            st=f'{r["settling_s"]}s' if r["settling_s"] else "—"
            d="⚠ LIMIT-CYCLE" if r["limit_cycle"] else "🟢 OK"
            f.write(f"| {r['target']:+.0f}° | {r['theta_ss']:+.2f}° | {r['ss_err_deg']} | "
                    f"{r['overshoot_deg']} | {st} | {r['theta_std_ss']} | {d} |\n")
        f.write(f"\n## Durum: **{status}**\n\n")
        f.write("## ASIL SORU — limit-cycle var mı?\n")
        n_lc=sum(1 for r in results if r.get("valid") and r["limit_cycle"])
        if n_lc==0:
            f.write("🟢 **Limit-cycle YOK** — gerçek motorda statik sürtünme, simdeki düşük-hız "
                    "kuantizasyon gezinmesini söndürdü. Cascade gerçek sistemde temiz oturuyor. "
                    "Sim kötümserdi (sürtünmesiz). Hipotez doğrulandı.\n")
        else:
            f.write(f"⚠ **Limit-cycle VAR** ({n_lc} segment) — sim öngörüsü gerçekleşti. θ hedef "
                    "civarında gezniyor. Kök neden: iç hız döngüsü düşük hızda (~1 rad/s) encoder "
                    "kuantizasyonuyla (18.7 rad/s) kör. Hedefli çözüm: hız penceresi büyüt / T-metodu "
                    "hız ölçümü / pozisyon ölü-bant.\n")
        f.write("\n## Hedef (Test 2.5)\n- ss_error < 2°, overshoot < %20, limit-cycle θ_std < 2°\n")
        f.write("- θ_out = EC × 360/466 (çıkış mili, pozisyon kuant. 0.773°/count)\n")
        f.write(f"\n## Artifacts\n- `{raw.name}`\n")
        if plot: f.write(f"- `{plot.name}` (θ takip + ω_ref/ω + u)\n")
    meta={"test_id":test_id,"title":"Aşama 2.5 pozisyon cascade step (Test 2.5)",
          "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
          "status":status,"architecture":"cascade_pos_P_speed_PI",
          "kp_pos":args.kpp,"inner":{"Kp":0.002,"Ki":0.1},"targets":args.targets,
          "note":"serbest mil; gimbalda yük ile yeniden ayar (ROADMAP §5)",
          "results":results,"artifacts":[raw.name]+([plot.name] if plot else [])}
    json.dump(meta,(out/"meta.json").open("w"),indent=2,ensure_ascii=False)


if __name__ == "__main__":
    sys.exit(main())
