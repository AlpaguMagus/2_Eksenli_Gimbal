#!/usr/bin/env python3
"""
Aşama 2 — Anti-windup recovery testi (Test 2.T3, gerçek motor).

Anti-windup back-calculation'ın (firmware'de hep aktif, speed_pi.c) integrator
wind-up'ı önlediğini GERÇEK motorda doğrular. Sim (verify_antiwindup.m) teoriyi
kanıtladı (anti-windup ON 235 ms vs OFF 715 ms recovery); bu test sim-to-real
gap'i kapatır (gerçek ON recovery'yi sim ON ile karşılaştır).

Senaryo (sim ile aynı):
  - MODE:SP_W, ulaşılamaz step SP_W:450 (u=0.5 max ~327 rad/s → 450 asla ulaşılmaz,
    error sürekli pozitif, integrator şişer = wind-up) — up_drive saniye
  - sonra SP_W:50 → recovery: anti-windup'lı firmware integratörü hızlı boşaltır,
    ω 50'ye hızlı oturur. recovery süresi ölçülür.
  - Karşılaştırma: sim ON ~235 ms (beklenen), sim OFF ~715 ms (anti-windup olmasaydı)

NOT: Firmware'de anti-windup runtime toggle YOK (back-calc kodda sabit). Bu test
gerçek ON recovery'yi ölçer; OFF referansı simdendir (gerçekte kapatılamaz).

⚠ GÜVENLİK: 450 setpoint motoru max hıza (saturation, ~327 rad/s no-load) sürer.
Mil serbest olmalı. Duty cap %50 aktif. Watchdog STOP komutuyla kesilebilir.

Çıktı (CLAUDE.md logging disiplini):
  artifacts/2/antiwindup/<test_id>/{raw/data.csv[.gz], summary.md, meta.json}

Kullanım:
    python3 scripts/antiwindup_test.py
    python3 scripts/antiwindup_test.py --sp-high 450 --sp-low 50 --up 1.5 --down 2.0

Kaynak: [AstromMurray2008] §10.4 (back-calculation anti-windup)
"""

from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, shutil, subprocess, sys, time
from pathlib import Path
import re
import serial

OMEGA_RE = re.compile(r"OMEGA:(-?[\d.]+)")
SP_RE    = re.compile(r"SP:(-?[\d.]+)")
U_RE     = re.compile(r",U:(-?[\d.]+)")
HEARTBEAT_S = 0.25
GZIP_THRESHOLD = 50 * 1024
MA_WINDOW = 5
SIM_ON_MS = 235     # verify_antiwindup.m referansları
SIM_OFF_MS = 715


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


def drive(ser, sp, dur, writer, phase, t_global0):
    """sp setpoint'i dur saniye sür; örnekleri CSV'ye yaz, listeyi döndür."""
    send(ser, f"SP_W:{sp}")
    print(f"[{ts()}] {phase}: SP_W:{sp:+.0f} ({dur:.1f} s)", flush=True)
    t0=time.time(); last_hb=t0; samples=[]
    while time.time()-t0 < dur:
        now=time.time()
        if now-last_hb >= HEARTBEAT_S:
            send(ser,"PING"); last_hb=now
        line=ser.readline().decode("utf-8","ignore").strip()
        mo=OMEGA_RE.search(line)
        if not mo: continue
        om=float(mo.group(1))
        ms=SP_RE.search(line); mu=U_RE.search(line)
        spa=float(ms.group(1)) if ms else sp
        u=float(mu.group(1)) if mu else 0.0
        tg=now-t_global0
        samples.append((tg,om,u,spa))
        writer.writerow([phase, sp, f"{tg:.4f}", f"{om:.2f}", f"{u:.3f}", f"{spa:.2f}"])
    return samples


def settle_time(t, om, target, tol, t_start):
    """t_start sonrası ω'nın target'a ±tol içinde girip kaldığı ilk an (göreli)."""
    idx=[i for i,tt in enumerate(t) if tt>=t_start]
    for k,i in enumerate(idx):
        if all(abs(om[j]-target)<=tol for j in idx[k:]):
            return t[i]-t_start
    return None


def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--sp-high", type=float, default=450, help="ulaşılamaz step (wind-up)")
    ap.add_argument("--sp-low", type=float, default=50, help="recovery hedefi")
    ap.add_argument("--up", type=float, default=1.5, help="yüksek setpoint süresi (wind-up birikimi)")
    ap.add_argument("--down", type=float, default=2.0, help="recovery gözlem süresi")
    ap.add_argument("--kp", type=float, default=0.002)
    ap.add_argument("--ki", type=float, default=0.1)
    ap.add_argument("--slew", type=float, default=0, help="0 = slew kapalı (ani step, wind-up için)")
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/2/antiwindup")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"

    print(f"[{ts()}] Test ID: {test_id} | step {args.sp_high}→{args.sp_low}, Kp={args.kp}, Ki={args.ki}")
    print(f"[{ts()}] ⚠ Mil serbest olmalı (450 setpoint motoru saturation'a sürer)")
    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    up=down=[]
    try:
        rtt=handshake(ser); print(f"[{ts()}] PONG ({rtt:.1f} ms)")
        send(ser,"STOP"); time.sleep(1.0)
        send(ser,"MODE:SP_W"); time.sleep(0.05)
        send(ser,f"KP:{args.kp}"); send(ser,f"KI:{args.ki}"); send(ser,f"SLEW:{args.slew}")
        time.sleep(0.05); ser.reset_input_buffer()
        tg0=time.time()
        with raw_csv.open("w",newline="") as fh:
            w=csv.writer(fh); w.writerow(["phase","setpoint","t_s","omega","u","sp_actual"])
            up   = drive(ser, args.sp_high, args.up,   w, "up(windup)", tg0)
            down = drive(ser, args.sp_low,  args.down, w, "down(recov)", tg0)
        send(ser,"STOP"); send(ser,"MODE:DUTY"); time.sleep(0.2)
    except KeyboardInterrupt:
        send(ser,"STOP"); print("\nCtrl-C — STOP"); return 130
    finally:
        try: ser.write(b"STOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    # recovery metriği
    alls = up+down
    t  = [s[0] for s in alls]
    om = moving_avg([s[1] for s in alls], MA_WINDOW)
    t_down = up[-1][0] if up else 0.0   # recovery başlangıç anı (down fazı ilk örnek ~)
    rec = settle_time(t, om, args.sp_low, 0.05*args.sp_low, t_down)
    om_high = mean([s[1] for s in up[len(up)//2:]]) if up else 0.0   # wind-up platosu
    rec_ms = round(rec*1000) if rec else None

    status = "PASS" if (rec_ms is not None and rec_ms < SIM_OFF_MS) else "CHECK"

    # gzip
    raw_final=raw_csv
    if raw_csv.stat().st_size > GZIP_THRESHOLD:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    res={"sp_high":args.sp_high,"sp_low":args.sp_low,"omega_high_plateau":round(om_high,1),
         "recovery_ms":rec_ms,"sim_on_ms":SIM_ON_MS,"sim_off_ms":SIM_OFF_MS}
    write_summary(out,test_id,args,res,status,raw_final)
    write_meta(out,test_id,args,res,status,raw_final)
    print(f"\n[{ts()}] recovery={rec_ms} ms (sim ON {SIM_ON_MS}, sim OFF {SIM_OFF_MS})")
    print(f"[{ts()}] wind-up platosu ω≈{om_high:.0f} rad/s (450 ulaşılamaz, saturation)")
    print(f"[{ts()}] Durum: {status}  |  Artifact: {out}/")
    return 0


def write_summary(out, test_id, args, res, status, raw):
    with (out/"summary.md").open("w") as f:
        f.write("# Aşama 2 — Anti-Windup Recovery (Test 2.T3, gerçek motor)\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n")
        f.write(f"- **Komut:** `python3 scripts/antiwindup_test.py --sp-high {args.sp_high} --sp-low {args.sp_low}`\n")
        f.write(f"- **Kazanç:** Kp={args.kp}, Ki={args.ki}, slew={args.slew}\n")
        f.write(f"- **Hedef:** anti-windup (firmware'de aktif) recovery'yi sim OFF ({SIM_OFF_MS} ms) altına indirir\n\n")
        f.write("## Sonuç\n\n")
        f.write("| Metric | Değer | Referans | Durum |\n|---|---|---|---|\n")
        f.write(f"| recovery (450→50) | {res['recovery_ms']} ms | sim ON {SIM_ON_MS} / OFF {SIM_OFF_MS} | {'✓' if status=='PASS' else '?'} |\n")
        f.write(f"| wind-up platosu | {res['omega_high_plateau']} rad/s | ~327 (max no-load) | — |\n\n")
        f.write(f"## Durum: **{status}**\n\n")
        f.write("Gerçek recovery sim OFF'tan belirgin hızlıysa anti-windup gerçekte çalışıyor demektir "
                "(sim ON ile uyum → sim-to-real gap kapalı). Detay: docs/asama_2_kontrol.md §11.12.9.\n\n")
        f.write(f"## Artifacts\n- `{raw.name}`\n")


def write_meta(out, test_id, args, res, status, raw):
    meta={"test_id":test_id,"title":"Anti-windup recovery (Test 2.T3, gerçek motor)",
          "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
          "status":status,"gains":{"Kp":args.kp,"Ki":args.ki,"slew":args.slew},
          "result":res,"artifacts":[raw.name]}
    json.dump(meta,(out/"meta.json").open("w"),indent=2,ensure_ascii=False)


if __name__ == "__main__":
    sys.exit(main())
