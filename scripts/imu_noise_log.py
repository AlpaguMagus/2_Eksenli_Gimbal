#!/usr/bin/env python3
"""
Aşama 0 — IMU statik gürültü logu (Allan variance için ham veri).

Complementary filter α'sının VERİ-TEMELLİ optimal değerini çıkarmak için IMU'yu
sabit tutup uzun süre ham gyro (GX/GY, °/s) ve accel-açı (P/R, °) loglar. Motor
SÜRÜLMEZ (güvenli — sadece IMU okunur). Sonra matlab/asama_0_altyapi/
analyze_allan_variance.m ile Allan deviation → angle random walk (ARW) + bias
instability → optimal complementary kesim frekansı + α türetilir.

⚠ KULLANIM: IMU'yu titreşimsiz, sabit bir yüzeye koy ve süre boyunca DOKUNMA.
Masa titreşimi/hava akımı bile Allan eğrisini bozar. İdeal: 30+ dk; minimum ~15 dk.

Çıktı (CLAUDE.md logging disiplini):
  artifacts/0/imu_noise/<test_id>/{raw/data.csv[.gz], summary.md, meta.json}

Kullanım:
    python3 scripts/imu_noise_log.py                 # 900 s (15 dk)
    python3 scripts/imu_noise_log.py --duration 1800 # 30 dk

Kaynak: IEEE Std 952-1997 (Allan variance), [Mahony2008] (complementary filter)
"""

from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, shutil, subprocess, sys, time
from pathlib import Path
import re
import serial

T_US = re.compile(r"T_US:(\d+)")
P_RE = re.compile(r",P:(-?[\d.]+)")
R_RE = re.compile(r",R:(-?[\d.]+)")
GX   = re.compile(r"GX:(-?[\d.]+)")
GY   = re.compile(r"GY:(-?[\d.]+)")
GZIP_THRESHOLD = 50 * 1024


def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def send(ser, c): ser.write((c+"\n").encode())

def handshake(ser):
    ser.reset_input_buffer(); send(ser,"PING"); t0=time.time()
    while time.time()-t0 < 2.0:
        if "PONG" in ser.readline().decode("utf-8","ignore"):
            return (time.time()-t0)*1000
    raise RuntimeError("Handshake timeout")


def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--duration", type=float, default=900, help="log süresi [s] (default 900=15dk)")
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/0/imu_noise")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"

    print(f"[{ts()}] IMU gürültü logu | süre {args.duration:.0f}s ({args.duration/60:.0f} dk)")
    print(f"[{ts()}] ⚠ IMU SABİT ve titreşimsiz olmalı — süre boyunca dokunma!")
    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.1)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    n=0; t_first=None; t_last=None
    try:
        time.sleep(1.5)   # boot reset bekle
        rtt=handshake(ser); print(f"[{ts()}] PONG ({rtt:.1f} ms)")
        send(ser,"MODE:DUTY"); time.sleep(0.05); send(ser,"STOP")   # motor garanti dursun
        time.sleep(0.2); ser.reset_input_buffer()
        t0=time.time(); last_report=t0
        with raw_csv.open("w",newline="") as fh:
            w=csv.writer(fh); w.writerow(["t_us","gx_dps","gy_dps","pitch_acc","roll_acc"])
            while time.time()-t0 < args.duration:
                line=ser.readline().decode("utf-8","ignore")
                mt=T_US.search(line); mgx=GX.search(line); mgy=GY.search(line)
                mp=P_RE.search(line); mr=R_RE.search(line)
                if not (mt and mgx and mgy and mp and mr): continue
                tus=int(mt.group(1))
                w.writerow([tus, mgx.group(1), mgy.group(1), mp.group(1), mr.group(1)])
                n+=1
                if t_first is None: t_first=tus
                t_last=tus
                now=time.time()
                if now-last_report >= 30:
                    el=now-t0
                    print(f"[{ts()}]   {el:5.0f}s / {args.duration:.0f}s  ({n} örnek, {n/el:.0f} Hz)", flush=True)
                    last_report=now
    except KeyboardInterrupt:
        print(f"\n[{ts()}] Ctrl-C — erken durduruldu ({n} örnek)")
    finally:
        try: ser.close()
        except Exception: pass

    # örnekleme frekansı: n/süre (DWT µs 44.7s'de wrap eder → t_last-t_first güvenilmez)
    fs = n / args.duration if args.duration > 0 else 0.0

    raw_final=raw_csv
    if raw_csv.stat().st_size > GZIP_THRESHOLD:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    res={"samples":n, "duration_s":round(args.duration,1), "fs_hz":round(fs,1)}
    with (out/"summary.md").open("w") as f:
        f.write("# Aşama 0 — IMU Statik Gürültü Logu (Allan variance)\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n- **Süre:** {args.duration:.0f} s · **Örnek:** {n} · **fs:** {fs:.1f} Hz\n")
        f.write(f"- **Komut:** `python3 scripts/imu_noise_log.py --duration {args.duration:.0f}`\n\n")
        f.write("## Sonraki adım\n`matlab/asama_0_altyapi/analyze_allan_variance.m` → Allan deviation, ARW, bias instability, optimal α.\n\n")
        f.write(f"## Artifacts\n- `{raw_final.name}`\n")
    json.dump({"test_id":test_id,"title":"IMU statik gürültü (Allan variance)",
               "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
               "result":res,"artifacts":[raw_final.name]},
              (out/"meta.json").open("w"), indent=2, ensure_ascii=False)

    print(f"[{ts()}] Tamamlandı: {n} örnek @ {fs:.1f} Hz → {out}/")
    print(f"[{ts()}] Allan analizi: matlab -batch \"cd('matlab/asama_0_altyapi'); analyze_allan_variance('{test_id}')\"")
    return 0


if __name__ == "__main__":
    sys.exit(main())
