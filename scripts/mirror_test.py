#!/usr/bin/env python3
"""
Aşama 2.7/2.8 — IMU mirror takip testi (Test 2.T6).

MODE:MIRROR'da motor, IMU pitch açısını (fused_pitch) cascade ile takip eder.
Kullanıcı breadboard'u (IMU) elle eğer; motor şaftı aynı açıya gitmeye çalışır.
Takip hatası (θ_ref − θ_out) RMS'i ölçülür.

Akış:
  - MODE:MIRROR (firmware: pitch0 göreli referans, encoder 0'lanır)
  - ~25 sn kayıt; kullanıcı 5-20 sn arası breadboard'u ±30° YAVAŞÇA eğip geri getirir (2-3 kez)
  - TR (θ_ref, slew'li göreli hedef), EC→θ_out (çıkış mili), FP (ham fused_pitch) kaydedilir
  - Metrik: takip hatası RMS, max; PASS hedefi RMS < 5° (ROADMAP Test 2.T6)

Çıktı: artifacts/2/mirror/<test_id>/ (summary + meta + raw + plot)

Kullanım:
    python3 scripts/mirror_test.py
    python3 scripts/mirror_test.py --duration 25

GÜVENLİK: Motor IMU'yu takip eder → çıkış mili serbest/yüksüz olmalı, ±60° hareket eder.
Kaynaklar: [Franklin2010] §6.4 (cascade takip), Aşama 2.5 pozisyon cascade
"""
from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, re, shutil, subprocess, sys, time
from pathlib import Path
import serial

TR_RE    = re.compile(r"TR:(-?[\d.]+)")
EC_RE    = re.compile(r"EC:(-?\d+)")
FP_RE    = re.compile(r"FP:(-?[\d.]+)")
U_RE     = re.compile(r",U:(-?[\d.]+)")
STALL_RE = re.compile(r"STALL_DETECTED")
HEARTBEAT_S = 0.25
GZIP_THRESHOLD = 50 * 1024
DEG_PER_COUNT = 360.0 / 466.0   # çıkış mili (48×9.7 event/rev)
RMS_PASS_DEG = 5.0              # Test 2.T6 hedefi


def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def send(ser, c): ser.write((c+"\n").encode())


def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--duration", type=float, default=25.0)
    ap.add_argument("--kpp", type=float, default=None,
                    help="pozisyon P kazancı override (verilmezse firmware MODE:MIRROR default'u=6, analitik)")
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/2/mirror")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"

    print(f"[{ts()}] IMU mirror takip testi — {args.duration:.0f} sn")
    print(f"[{ts()}] 0-5 sn DOKUNMA (referans) → 5-20 sn breadboard'u ±30° YAVAŞ eğ+geri (2-3 kez) → bırak")
    print(f"[{ts()}] GÜVENLİK: çıkış mili serbest olsun, motor ±60° takip eder.\n")
    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    samples=[]; stall=False
    try:
        ser.reset_input_buffer(); send(ser,"PING"); time.sleep(0.3)
        send(ser,"MODE:MIRROR"); time.sleep(0.1)
        if args.kpp is not None:   # override; yoksa firmware MODE:MIRROR default'u (6, analitik)
            send(ser,f"KPP:{args.kpp}"); time.sleep(0.05)
        ser.reset_input_buffer()
        t0=time.time(); last_hb=t0; last_p=t0
        while time.time()-t0 < args.duration:
            now=time.time()
            if now-last_hb >= HEARTBEAT_S: send(ser,"PING"); last_hb=now
            line=ser.readline().decode("utf-8","ignore").strip()
            if STALL_RE.search(line): stall=True
            mtr=TR_RE.search(line); mec=EC_RE.search(line); mfp=FP_RE.search(line)
            if not (mtr and mec): continue
            tr=float(mtr.group(1)); ec=int(mec.group(1)); fp=float(mfp.group(1)) if mfp else 0.0
            theta_out=ec*DEG_PER_COUNT
            t=now-t0
            samples.append((t, tr, theta_out, fp))
            if now-last_p >= 0.5:
                print(f"  t={t:4.1f}s  θ_ref={tr:+6.1f}°  θ_out={theta_out:+6.1f}°  hata={tr-theta_out:+5.1f}°")
                last_p=now
    except KeyboardInterrupt:
        pass
    finally:
        send(ser,"STOP"); send(ser,"MODE:DUTY"); time.sleep(0.2)
        try: ser.close()
        except Exception: pass

    with raw_csv.open("w",newline="") as fh:
        w=csv.writer(fh); w.writerow(["t_s","theta_ref","theta_out","fused_pitch"])
        for s in samples: w.writerow([f"{s[0]:.4f}",f"{s[1]:.2f}",f"{s[2]:.2f}",f"{s[3]:.2f}"])

    res = analyze(samples, stall)
    print(f"\n[{ts()}] ── ANALİZ ──")
    for k,v in res.items(): print(f"  {k}: {v}")

    raw_final=raw_csv
    if raw_csv.stat().st_size > GZIP_THRESHOLD:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    plot_path = make_plot(out, samples)
    write_artifacts(out, test_id, args, res, raw_final, plot_path)
    print(f"\n[{ts()}] Durum: {res.get('status')}  |  Artifact: {out}/")
    if plot_path: print(f"[{ts()}] Plot: {plot_path}")
    return 0


def analyze(samples, stall):
    if len(samples) < 30: return {"valid": False, "note": "az veri", "status": "PARTIAL"}
    # Hareket penceresi: |θ_ref| anlamlı (>3°) olan örnekler (baseline değil)
    moving = [(tr, th) for _,tr,th,_ in samples if abs(tr) > 3.0]
    err_all = [tr-th for _,tr,th,_ in samples]
    rms_all = (sum(e*e for e in err_all)/len(err_all))**0.5
    max_err = max(abs(e) for e in err_all)
    span = max(tr for _,tr,_,_ in samples) - min(tr for _,tr,_,_ in samples)
    if moving:
        err_mv = [tr-th for tr,th in moving]
        rms_mv = (sum(e*e for e in err_mv)/len(err_mv))**0.5
    else:
        rms_mv = rms_all
    status = "PASS" if (rms_mv < RMS_PASS_DEG and not stall and span > 10) else \
             ("STALL" if stall else ("PARTIAL" if span <= 10 else "FAIL"))
    return {"valid": True, "n": len(samples),
            "rms_error_deg": round(rms_mv,2), "rms_all_deg": round(rms_all,2),
            "max_error_deg": round(max_err,2), "ref_span_deg": round(span,1),
            "stall": stall, "status": status}


def make_plot(out, samples):
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    except Exception: return None
    if not samples: return None
    t=[s[0] for s in samples]; tr=[s[1] for s in samples]
    th=[s[2] for s in samples]; fp=[s[3] for s in samples]
    err=[s[1]-s[2] for s in samples]
    fig,ax=plt.subplots(2,1,figsize=(11,6),sharex=True)
    ax[0].plot(t,tr,'r',lw=1.4,label='θ_ref (hedef = göreli pitch, slew)')
    ax[0].plot(t,th,'b',lw=1.3,label='θ_out (motor, ölçülen)')
    ax[0].plot(t,fp,'g',lw=0.7,alpha=0.5,label='fused_pitch (ham, mutlak)')
    ax[0].set_ylabel('açı (°)'); ax[0].legend(loc='best'); ax[0].grid(alpha=0.3)
    ax[0].set_title('Aşama 2.7 — IMU mirror takip (motor IMU pitch\'ini izler)')
    ax[1].plot(t,err,'k',lw=0.9); ax[1].axhline(0,color='gray',lw=0.5)
    ax[1].axhline(5,color='r',ls=':',lw=0.8); ax[1].axhline(-5,color='r',ls=':',lw=0.8)
    ax[1].set_ylabel('takip hatası (°)'); ax[1].set_xlabel('t (s)'); ax[1].grid(alpha=0.3)
    fig.tight_layout()
    p=out/"mirror_plot.png"; fig.savefig(p,dpi=130); plt.close(fig)
    return p


def write_artifacts(out, test_id, args, res, raw, plot):
    with (out/"summary.md").open("w") as f:
        f.write("# Aşama 2.7/2.8 — IMU Mirror Takip (Test 2.T6)\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n")
        f.write(f"- **Mimari:** MODE:MIRROR — θ_ref=clamp(fused_pitch−pitch₀, ±60°), slew 90°/s → cascade "
                f"(Kp_pos={args.kpp if args.kpp is not None else 'firmware 6 (analitik, [Franklin2010] §4.2)'})\n")
        f.write(f"- **Komut:** `python3 scripts/mirror_test.py`\n")
        f.write(f"- **NOT:** Serbest mil. Kazançlar Aşama 2.3/2.5 (yüksüz). Gerçek gimbalda yük ile yeniden ayar.\n\n")
        f.write("## Sonuçlar\n\n| Metrik | Değer |\n|---|---|\n")
        for k,v in res.items(): f.write(f"| {k} | {v} |\n")
        f.write("\n## Yorum\n\n")
        st=res.get("status")
        if st=="PASS":
            f.write(f"🟢 **PASS** — takip hatası RMS {res.get('rms_error_deg')}° < 5° (hedef). "
                    f"Motor IMU pitch'ini cascade ile izledi (ref aralığı {res.get('ref_span_deg')}°). "
                    "Pozisyon dış döngü + hız PI iç döngü canlı değişen referansı takip ediyor.\n")
        elif st=="STALL":
            f.write("⚠ STALL — müdahale çok sertti veya mil sıkıştı. Daha hafif/serbest tekrar.\n")
        elif st=="PARTIAL":
            f.write("🟡 PARTIAL — referans aralığı küçük (breadboard yeterince eğilmedi). Tekrarla, ±30° eğ.\n")
        else:
            f.write(f"🔴 FAIL — RMS {res.get('rms_error_deg')}° ≥ 5°. Takip yetersiz; slew/clamp/kazanç gözden geçir.\n")
        f.write(f"\n## Artifacts\n- `{raw.name}`\n")
        if plot: f.write(f"- `{plot.name}` (θ_ref vs θ_out + hata)\n")
    meta={"test_id":test_id,"title":"Aşama 2.7/2.8 IMU mirror takip (Test 2.T6)",
          "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
          "status":res.get("status"),"result":res,
          "note":"serbest mil; gimbalda yük ile yeniden ayar","artifacts":[raw.name]+([plot.name] if plot else [])}
    json.dump(meta,(out/"meta.json").open("w"),indent=2,ensure_ascii=False)


if __name__ == "__main__":
    sys.exit(main())
