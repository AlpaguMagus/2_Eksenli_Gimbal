#!/usr/bin/env python3
"""
Aşama 2.3 kapanış — Hız PI resmi step response testi (Test 2.T2).

Aşama 2.3'te ampirik bulunan kazançla (Kp=0.002, Ki=0.1) hız PI'nin resmi
performans metriklerini ölçer: settling time, overshoot, steady-state error.

Akış:
  - MODE:SP_W + runtime kazanç (KP/KI/SLEW) ayarı
  - Her setpoint için: STOP (temiz başlangıç) → SP_W → 3 sn drive → STOP coast
  - Çoklu setpoint × CW/CCW
  - ω post-process moving-average (telemetri raw kuantize, yumuşatılır)
  - Metrik: settling (±%5), overshoot, ss_error

Çıktı (CLAUDE.md logging disiplini):
  artifacts/2/speed_step/<test_id>/
    ├── raw/data.csv.gz
    ├── summary.md
    └── meta.json

Kullanım:
    python3 scripts/speed_step_test.py
    python3 scripts/speed_step_test.py --setpoints 50 100 150 --kp 0.002 --ki 0.1

NOT: Serbest mil (yüksüz). Kazançlar serbest mil için (Aşama 2.3). Gerçek gimbalda
yük ile yeniden ayarlanacak (ROADMAP Aşama 5 kritik not).

Kaynaklar: [Franklin2010] §3.5 (step metrikleri), [AstromMurray2008] §10
"""

from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, os, re, shutil, subprocess, sys, time
from pathlib import Path
import serial

OMEGA_RE = re.compile(r"OMEGA:(-?[\d.]+)")
SP_RE    = re.compile(r"SP:(-?[\d.]+)")
U_RE     = re.compile(r",U:(-?[\d.]+)")
HEARTBEAT_S = 0.25
GZIP_THRESHOLD = 50 * 1024
MA_WINDOW = 5   # post-process moving-average (raw ω kuantize)


def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def mean(x): return sum(x)/len(x) if x else 0.0
def moving_avg(x, w):
    out=[]
    for i in range(len(x)):
        lo=max(0,i-w+1); out.append(sum(x[lo:i+1])/(i-lo+1))
    return out


def send(ser, c): ser.write((c+"\n").encode())

def handshake(ser):
    ser.reset_input_buffer(); send(ser,"PING"); t0=time.time()
    while time.time()-t0 < 1.0:
        if "PONG" in ser.readline().decode("utf-8","ignore"):
            return (time.time()-t0)*1000
    raise RuntimeError("Handshake timeout")


def run_step(ser, sp, drive_s, writer, step_idx):
    """Bir setpoint step. CSV'ye yaz, metrik döndür."""
    send(ser, f"SP_W:{sp}")
    print(f"[{ts()}] step {step_idx:2d}  SP_W:{sp:+.0f}", flush=True)
    t0=time.time(); last_hb=t0
    samples=[]   # (t, omega, u, sp_actual)
    while time.time()-t0 < drive_s:
        now=time.time()
        if now-last_hb >= HEARTBEAT_S:
            send(ser,"PING"); last_hb=now
        line=ser.readline().decode("utf-8","ignore").strip()
        mo=OMEGA_RE.search(line); ms=SP_RE.search(line); mu=U_RE.search(line)
        if not mo: continue
        om=float(mo.group(1))
        spa=float(ms.group(1)) if ms else 0.0
        u=float(mu.group(1)) if mu else 0.0
        t=now-t0
        samples.append((t,om,u,spa))
        writer.writerow([step_idx, sp, f"{t:.4f}", f"{om:.2f}", f"{u:.3f}", f"{spa:.2f}"])
    return compute_metrics(sp, samples)


def compute_metrics(sp, samples):
    if len(samples) < 10:
        return {"setpoint": sp, "n": len(samples), "valid": False}
    t  = [s[0] for s in samples]
    om = [s[1] for s in samples]
    om_f = moving_avg(om, MA_WINDOW)   # kuantizasyonu yumuşat
    sgn = 1 if sp >= 0 else -1
    om_abs = [sgn*v for v in om_f]; sp_abs = abs(sp)

    tail = om_abs[int(len(om_abs)*0.6):]
    om_ss = mean(tail)
    ss_err = abs(om_ss - sp_abs)/sp_abs*100 if sp_abs>0 else 0
    overshoot = max(0.0, (max(om_abs)-sp_abs)/sp_abs*100) if sp_abs>0 else 0
    # Settling: ±%5 bandına girip kalma anı
    band = 0.05*sp_abs
    settle_t=None
    for i in range(len(om_abs)):
        if all(abs(v-sp_abs)<=band for v in om_abs[i:]):
            settle_t=t[i]; break
    # bang-bang kontrolü
    us = [s[2] for s in samples][int(len(samples)*0.6):]
    u_std = (sum((v-mean(us))**2 for v in us)/len(us))**0.5 if us else 0
    bang = u_std > 0.2
    return {"setpoint": sp, "n": len(samples), "valid": True,
            "omega_ss": round(om_ss,1), "ss_error_pct": round(ss_err,1),
            "overshoot_pct": round(overshoot,1),
            "settling_s": round(settle_t,3) if settle_t else None,
            "u_std": round(u_std,3), "bang_bang": bang}


def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--setpoints", type=float, nargs="+", default=[40,80,120,160])
    ap.add_argument("--kp", type=float, default=0.002)
    ap.add_argument("--ki", type=float, default=0.1)
    ap.add_argument("--slew", type=float, default=200)
    ap.add_argument("--drive", type=float, default=3.0)
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/2/speed_step")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"

    # signed setpoint listesi (her biri CW + CCW)
    sps=[]
    for s in args.setpoints: sps += [+abs(s), -abs(s)]

    print(f"[{ts()}] Test ID: {test_id}  |  Kp={args.kp}, Ki={args.ki}, slew={args.slew}")
    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    results=[]
    try:
        rtt=handshake(ser); print(f"[{ts()}] PONG ({rtt:.1f} ms)")
        send(ser,"MODE:SP_W"); time.sleep(0.05)
        send(ser,f"KP:{args.kp}"); send(ser,f"KI:{args.ki}"); send(ser,f"SLEW:{args.slew}")
        time.sleep(0.05)
        with raw_csv.open("w",newline="") as fh:
            w=csv.writer(fh); w.writerow(["step","setpoint","t_s","omega","u","sp_actual"])
            for i,sp in enumerate(sps,1):
                send(ser,"STOP"); time.sleep(1.0)   # temiz başlangıç (PI+filtre reset)
                send(ser,"MODE:SP_W"); time.sleep(0.03)
                send(ser,f"KP:{args.kp}"); send(ser,f"KI:{args.ki}"); send(ser,f"SLEW:{args.slew}")
                time.sleep(0.03); ser.reset_input_buffer()
                m=run_step(ser, sp, args.drive, w, i)
                results.append(m)
                if m.get("valid"):
                    bb="⚠BANG" if m["bang_bang"] else "OK"
                    st=f'{m["settling_s"]}s' if m["settling_s"] else "—"
                    print(f'        ω_ss={m["omega_ss"]:+7.1f} ss_err={m["ss_error_pct"]:4.1f}% '
                          f'OS={m["overshoot_pct"]:4.1f}% settle={st} u_std={m["u_std"]:.3f} {bb}')
        send(ser,"STOP"); send(ser,"MODE:DUTY"); time.sleep(0.2)
    except KeyboardInterrupt:
        send(ser,"STOP"); print("\nCtrl-C — STOP"); return 130
    finally:
        try: ser.write(b"STOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    # gzip raw
    raw_final = raw_csv
    if raw_csv.stat().st_size > GZIP_THRESHOLD:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    # summary + meta
    valid=[r for r in results if r.get("valid")]
    # FALSE-PASS bug fix: eskiden yalnızca bang_bang'e bakıyordu → motor hiç dönmese de
    # (ω≈0, salınım yok, settle=None) "PASS" verirdi. Hedefe ulaşma (±%5 banda oturma) da şart.
    reached = lambda r: (not r["bang_bang"]) and r.get("settling_s") is not None
    n_ok=sum(1 for r in valid if reached(r))
    if valid and n_ok==len(valid):
        status="PASS"
    elif any(r["bang_bang"] for r in valid):
        status="BANG_BANG"
    elif any(not reached(r) for r in valid):
        status="NO_REACH"
    else:
        status="PARTIAL"
    write_summary(out, test_id, args, results, status, raw_final)
    write_meta(out, test_id, args, results, status, raw_final)
    print(f"\n[{ts()}] Durum: {status}  ({n_ok}/{len(valid)} step temiz)")
    print(f"[{ts()}] Artifact: {out}/")
    return 0


def write_summary(out, test_id, args, results, status, raw):
    with (out/"summary.md").open("w") as f:
        f.write(f"# Aşama 2.3 — Hız PI Step Response (Test 2.T2)\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n")
        f.write(f"- **Kazanç:** Kp={args.kp}, Ki={args.ki}, slew={args.slew} (Aşama 2.3 ampirik)\n")
        f.write(f"- **Komut:** `python3 scripts/speed_step_test.py`\n")
        f.write(f"- **NOT:** Serbest mil (yüksüz). Gerçek gimbalda yük ile yeniden ayar (ROADMAP §5).\n\n")
        f.write("## Sonuçlar\n\n")
        f.write("| Setpoint | ω_ss | ss_err % | OS % | settling | u_std | durum |\n|---|---|---|---|---|---|---|\n")
        for r in results:
            if not r.get("valid"):
                f.write(f"| {r['setpoint']:+.0f} | — | — | — | — | — | ✗ az veri |\n"); continue
            st=f'{r["settling_s"]}s' if r["settling_s"] else "—"
            d="⚠ BANG" if r["bang_bang"] else "🟢 OK"
            f.write(f"| {r['setpoint']:+.0f} | {r['omega_ss']:+.1f} | {r['ss_error_pct']} | {r['overshoot_pct']} | {st} | {r['u_std']} | {d} |\n")
        f.write(f"\n## Durum: **{status}**\n\n")
        f.write("## Hedef (Test 2.T2)\n- settling < 5τ (~300 ms), overshoot < %10, ss_error < %2\n")
        f.write("- ω metrikleri raw telemetri %d-örnek moving-average ile yumuşatıldı (encoder kuantizasyon)\n" % MA_WINDOW)
        f.write(f"\n## Artifacts\n- `{raw.name}`\n")


def write_meta(out, test_id, args, results, status, raw):
    meta={"test_id":test_id,"title":"Aşama 2.3 hız PI step response (Test 2.T2)",
          "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
          "status":status,"gains":{"Kp":args.kp,"Ki":args.ki,"slew":args.slew},
          "note":"serbest mil; gimbalda yük ile yeniden ayar (ROADMAP §5)",
          "ma_window":MA_WINDOW,"results":results,"artifacts":[raw.name]}
    json.dump(meta,(out/"meta.json").open("w"),indent=2,ensure_ascii=False)


if __name__ == "__main__":
    sys.exit(main())
