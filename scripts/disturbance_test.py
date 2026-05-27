#!/usr/bin/env python3
"""
Aşama 2.4 — Disturbance rejection testi.

Motor sabit setpoint'te (varsayılan 100 rad/s) dönerken kullanıcı elle yük
uygular (çıkış milini yavaşlatır). Kontrolcünün (PI integral) hızı setpoint'e
geri getirme yeteneği ölçülür.

Akış:
  - MODE:SP_W + ampirik kazanç (Kp=0.002, Ki=0.1)
  - SP_W sabit, ~16 sn kayıt
  - Kullanıcı 3-14 sn arası 2-3 kez şaftı yavaşlatıp bırakır
  - ω, u, sp zaman serisi kaydedilir
  - Analiz: baseline ω, disturbance dip'leri, u tepkisi (PI), recovery

Çıktı: artifacts/2/disturbance/<test_id>/ (summary + meta + raw gzip)

Kullanım:
    python3 scripts/disturbance_test.py
    python3 scripts/disturbance_test.py --setpoint 100 --duration 16

Kaynaklar: [Franklin2010] §4 (disturbance rejection), [AstromMurray2008] §10
"""
from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, shutil, subprocess, sys, time
from pathlib import Path
import serial

OMEGA_RE = __import__("re").compile(r"OMEGA:(-?[\d.]+)")
SP_RE    = __import__("re").compile(r"SP:(-?[\d.]+)")
U_RE     = __import__("re").compile(r",U:(-?[\d.]+)")
STALL_RE = __import__("re").compile(r"STALL_DETECTED")
HEARTBEAT_S = 0.25
MA_WINDOW = 5

def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def mean(x): return sum(x)/len(x) if x else 0.0
def moving_avg(x,w):
    out=[]
    for i in range(len(x)):
        lo=max(0,i-w+1); out.append(sum(x[lo:i+1])/(i-lo+1))
    return out
def send(ser,c): ser.write((c+"\n").encode())

def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--setpoint", type=float, default=100)
    ap.add_argument("--duration", type=float, default=16.0)
    ap.add_argument("--kp", type=float, default=0.002)
    ap.add_argument("--ki", type=float, default=0.1)
    ap.add_argument("--slew", type=float, default=200)
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/2/disturbance")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"
    SP = args.setpoint

    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    print(f"[{ts()}] Disturbance testi — SP_W:{SP:.0f}, {args.duration:.0f} sn")
    print(f"[{ts()}] 0-3 sn DOKUNMA (baseline) → 3-14 sn 2-3 kez YAVAŞLAT+BIRAK → 14-16 sn bırak\n")

    ser.reset_input_buffer(); send(ser,"PING"); time.sleep(0.3)
    send(ser,"MODE:SP_W"); time.sleep(0.05)
    send(ser,f"KP:{args.kp}"); send(ser,f"KI:{args.ki}"); send(ser,f"SLEW:{args.slew}")
    time.sleep(0.05); ser.reset_input_buffer()

    samples=[]; stall=False
    send(ser,f"SP_W:{SP}")
    t0=time.time(); last_hb=t0; last_p=t0
    try:
        while time.time()-t0 < args.duration:
            now=time.time()
            if now-last_hb >= HEARTBEAT_S: send(ser,"PING"); last_hb=now
            line=ser.readline().decode("utf-8","ignore").strip()
            if STALL_RE.search(line): stall=True
            mo=OMEGA_RE.search(line); ms=SP_RE.search(line); mu=U_RE.search(line)
            if not mo: continue
            om=float(mo.group(1)); spa=float(ms.group(1)) if ms else 0; u=float(mu.group(1)) if mu else 0
            t=now-t0; samples.append((t,om,u,spa))
            if now-last_p >= 0.5:
                print(f"  t={t:4.1f}s  ω={om:+7.1f}  u={u:+.3f}")
                last_p=now
    except KeyboardInterrupt:
        pass
    finally:
        send(ser,"STOP"); send(ser,"MODE:DUTY"); time.sleep(0.2)
        try: ser.close()
        except Exception: pass

    # CSV
    with raw_csv.open("w",newline="") as fh:
        w=csv.writer(fh); w.writerow(["t_s","omega","u","sp_actual"])
        for s in samples: w.writerow([f"{s[0]:.4f}",f"{s[1]:.2f}",f"{s[2]:.3f}",f"{s[3]:.2f}"])

    # Analiz
    res = analyze(SP, samples, stall)
    print(f"\n[{ts()}] ── ANALİZ ──")
    for k,v in res.items(): print(f"  {k}: {v}")

    # gzip
    raw_final=raw_csv
    if raw_csv.stat().st_size > 50*1024:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    write_artifacts(out, test_id, args, res, raw_final, stall)
    print(f"\n[{ts()}] Artifact: {out}/")
    return 0

def analyze(SP, samples, stall):
    if len(samples)<20: return {"valid":False,"note":"az veri"}
    t=[s[0] for s in samples]; om=[s[1] for s in samples]; u=[s[2] for s in samples]
    omf=moving_avg(om,MA_WINDOW)
    # Baseline: 0-3 sn ortalama
    base=[omf[i] for i in range(len(t)) if t[i]<3.0]
    base_om=mean(base) if base else SP
    base_u=mean([u[i] for i in range(len(t)) if t[i]<3.0]) if base else 0
    # Disturbance penceresi (3 sn sonrası)
    dist_idx=[i for i in range(len(t)) if t[i]>=3.0]
    if not dist_idx: return {"valid":False}
    dist_om=[omf[i] for i in dist_idx]
    dist_u=[u[i] for i in dist_idx]
    min_om=min(dist_om)        # en derin yavaşlama
    max_u=max(dist_u)          # PI'nin maksimum duty tepkisi
    dip_pct=(base_om-min_om)/base_om*100 if base_om else 0
    # Recovery: son 2 sn ω setpoint'e döndü mü
    tail=[omf[i] for i in range(len(t)) if t[i]>t[-1]-2.0]
    recovered=abs(mean(tail)-SP)/SP*100 < 10 if SP else False
    return {"valid":True,"baseline_omega":round(base_om,1),"baseline_u":round(base_u,3),
            "min_omega_during_dist":round(min_om,1),"max_dip_pct":round(dip_pct,1),
            "max_u_response":round(max_u,3),"final_omega":round(mean(tail),1),
            "recovered_to_setpoint":recovered,"stall_triggered":stall}

def write_artifacts(out, test_id, args, res, raw, stall):
    with (out/"summary.md").open("w") as f:
        f.write(f"# Aşama 2.4 — Disturbance Rejection\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n- **Setpoint:** {args.setpoint:.0f} rad/s\n")
        f.write(f"- **Kazanç:** Kp={args.kp}, Ki={args.ki}\n")
        f.write(f"- **Yöntem:** Motor sabit hızda dönerken çıkış mili elle yavaşlatıldı (2-3 kez)\n\n")
        f.write("## Sonuçlar\n\n| Metrik | Değer |\n|---|---|\n")
        for k,v in res.items(): f.write(f"| {k} | {v} |\n")
        f.write("\n## Yorum\n\n")
        if res.get("stall_triggered"):
            f.write("⚠ Stall detection tetiklendi — müdahale çok sertti (motor durma sınırına geldi). "
                    "Koruma katmanı çalıştı; saf disturbance rejection için daha hafif müdahale gerekir.\n")
        elif res.get("recovered_to_setpoint"):
            f.write(f"🟢 PASS — Disturbance ile ω %{res.get('max_dip_pct')} düştü "
                    f"(min {res.get('min_omega_during_dist')} rad/s), PI duty'yi {res.get('baseline_u')}→"
                    f"{res.get('max_u_response')}'e çıkararak telafi etti, ω setpoint'e döndü "
                    f"(son {res.get('final_omega')} rad/s). İntegral aksiyon disturbance rejection sağlıyor.\n")
        else:
            f.write("🟡 Kısmi — ω setpoint'e tam dönmedi veya müdahale yetersiz. Tekrar denenebilir.\n")
        f.write(f"\n## Artifacts\n- `{raw.name}`\n")
    meta={"test_id":test_id,"title":"Aşama 2.4 disturbance rejection",
          "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
          "setpoint":args.setpoint,"gains":{"Kp":args.kp,"Ki":args.ki},"result":res,
          "artifacts":[raw.name]}
    json.dump(meta,(out/"meta.json").open("w"),indent=2,ensure_ascii=False)

if __name__=="__main__":
    sys.exit(main())
