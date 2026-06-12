#!/usr/bin/env python3
"""
Aşama 3.3 — Eksen IMU mirror takip testi (axis-parametrik).

İnstance-based 2-eksen firmware'inde bir eksenin MIRROR modunu (Aşama 2.7)
gerçek motorda doğrular. Motor, IMU fused_pitch'ini canlı takip eder (board'u
eğince motor şaftı aynı açıya gider). Cascade altyapısı (poz P → hız PI) üzerine
yalnız referans kaynağı değişir: sabit hedef yerine slew'li/clamp'li göreli pitch.

ASIL SORU: Seçilen eksende motor IMU'yu temiz takip ediyor mu? Takip hatası RMS
(θ_out − θ_ref) ne? Motor-2 = karakterize sağlıklı ünite → Aşama 2.7 ile uyumlu
(~4-5° RMS yavaş elde) beklenir.

Telemetri:
  FP   = fused_pitch (mutlak IMU pitch, derece)
  TR(2)= PositionP setpoint = slew'li/clamp'li göreli pitch hedefi (kontrolcünün izlediği)
  EC(2)= enkoder count → θ_out = EC×360/466 (çıkış mili derece, motorun gittiği)
Takip hatası = θ_out − TR.

KULLANICI: test başlayınca board'u **YAVAŞ** pitch ekseninde ileri-geri eğ
(~±30°, birkaç döngü), sonunda bir kez daha hızlı eğ (bant limiti görünür).
Motor şaftının takip ettiğini izle. ~30 sn.

Çıktı: artifacts/3/mirror_m<motor>/<test_id>/ (summary + meta + plot; raw gitignored)

Kullanım: python3 scripts/motor_mirror_test.py --motor 2 --dur 30
"""
from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, re, shutil, subprocess, sys, time
from pathlib import Path
import serial

HEARTBEAT_S = 0.25
GZIP_THRESHOLD = 50 * 1024
CPR_OUT = 466.0
DEG_PER_COUNT = 360.0 / CPR_OUT


def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def mean(x): return sum(x)/len(x) if x else 0.0
def rms(x): return (sum(v*v for v in x)/len(x))**0.5 if x else 0.0
def send(ser, c): ser.write((c+"\n").encode())


def main():
    ap=argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--motor", type=int, default=2, choices=[1,2])
    ap.add_argument("--mode", default="mirror", choices=["mirror","stab"],
                    help="mirror=+takip (taklit) / stab=−takip (base'i karşıla, payload sabit)")
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--dur", type=float, default=30.0, help="kayıt süresi (s)")
    ap.add_argument("--test-id", default=None)
    args=ap.parse_args()
    sfx = "" if args.motor==1 else "2"
    mode_cmd = f"MODE{sfx}"
    mode_word = "MIRROR" if args.mode=="mirror" else "STAB"
    EC = re.compile(rf"EC{sfx}:(-?\d+)")
    FP = re.compile(r"FP:(-?[\d.]+)")
    TR = re.compile(rf"TR{sfx}:(-?[\d.]+)")

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path(f"artifacts/3/{args.mode}_m{args.motor}")/test_id
    (out/"raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out/"raw"/"data.csv"

    act = "takip eder (taklit)" if args.mode=="mirror" else "TERS döner (base'i karşılar)"
    print(f"[{ts()}] Eksen-{args.motor} {mode_word} — {mode_cmd}:{mode_word}, süre {args.dur:.0f}s")
    print(f"[{ts()}] ⚠ BOARD'U YAVAŞ EĞ (pitch ±~30°, birkaç döngü), sonunda 1 hızlı eğ. Motor {act}.\n")
    try:
        ser=serial.Serial(args.port,args.baud,timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    samples=[]   # (t, fp, tr, theta)
    try:
        ser.reset_input_buffer(); send(ser,"PING"); time.sleep(0.3)
        send(ser,f"{mode_cmd}:{mode_word}"); time.sleep(0.15)   # enc 0° = geçiş anı, pitch0 alınır
        ser.reset_input_buffer()
        t0=time.time(); last_hb=t0; last_p=t0
        with raw_csv.open("w",newline="") as fh:
            w=csv.writer(fh); w.writerow(["t","fp","tr","ec","theta_deg","err"])
            while time.time()-t0 < args.dur:
                now=time.time()
                if now-last_hb>=HEARTBEAT_S: send(ser,"PING"); last_hb=now
                line=ser.readline().decode("utf-8","ignore").strip()
                mec=EC.search(line); mfp=FP.search(line); mtr=TR.search(line)
                if not (mec and mfp and mtr): continue
                ec=int(mec.group(1)); fp=float(mfp.group(1)); tr=float(mtr.group(1))
                theta=ec*DEG_PER_COUNT; err=theta-tr
                t=now-t0
                samples.append((t,fp,tr,theta))
                w.writerow([f"{t:.3f}",f"{fp:.2f}",f"{tr:.2f}",ec,f"{theta:.2f}",f"{err:.2f}"])
                if now-last_p>=1.0:
                    print(f"    t={t:4.1f}s  FP={fp:+6.1f}°  ref={tr:+6.1f}°  θ_motor={theta:+6.1f}°  hata={err:+5.1f}°")
                    last_p=now
        send(ser,"STOP"); send(ser,f"{mode_cmd}:DUTY"); time.sleep(0.2)
    except KeyboardInterrupt:
        send(ser,"STOP"); print("\nCtrl-C — STOP")
    finally:
        try: ser.write(b"STOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    raw_final=raw_csv
    if raw_csv.exists() and raw_csv.stat().st_size>GZIP_THRESHOLD:
        gz=raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz,"wb") as fo: shutil.copyfileobj(fi,fo)
        raw_csv.unlink(); raw_final=gz

    # ── Analiz ──
    res = analyze(samples)
    plot_path = make_plot(out, raw_final, args.motor, args.mode, res)
    write_artifacts(out, test_id, args, res, raw_final, plot_path)

    print(f"\n[{ts()}] ── ÖZET ──")
    print(f"    FP aralığı (eğme genliği): {res['fp_range']:.1f}°  (min {res['fp_min']:.1f} / max {res['fp_max']:.1f})")
    print(f"    takip RMS (θ−ref): {res['rms']:.2f}°   |   max |hata|: {res['max_err']:.1f}°")
    print(f"[{ts()}] Durum: {res['status']}")
    print(f"[{ts()}] Artifact: {out}/")
    if plot_path: print(f"[{ts()}] Plot: {plot_path}")
    return 0


def analyze(samples):
    if len(samples)<30:
        return {"status":"NO_DATA","n":len(samples),"fp_range":0,"fp_min":0,"fp_max":0,"rms":0,"max_err":0,"moving_rms":0}
    fp=[s[1] for s in samples]; errs=[s[3]-s[2] for s in samples]
    fp_min,fp_max=min(fp),max(fp); fp_range=fp_max-fp_min
    r=rms(errs); mx=max(abs(e) for e in errs)
    # yalnız hareketli pencere (|ref| anlamlı) RMS — durağan başı dışla
    mov=[s[3]-s[2] for s in samples if abs(s[2])>3.0]
    mrms=rms(mov)
    # PASS: kullanıcı yeterince eğdi (FP aralığı >20°) VE takip makul (<10° RMS)
    if fp_range < 20.0:        status="NO_MOTION"   # board yeterince eğilmedi → tekrar
    elif r < 10.0:             status="PASS"
    else:                      status="HIGH_ERROR"
    return {"status":status,"n":len(samples),"fp_range":round(fp_range,1),
            "fp_min":round(fp_min,1),"fp_max":round(fp_max,1),
            "rms":round(r,2),"max_err":round(mx,1),"moving_rms":round(mrms,2)}


def make_plot(out, raw, motor, mode, res):
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    except Exception: return None
    rows=[]
    op=gzip.open if str(raw).endswith(".gz") else open
    with op(raw,"rt") as fh:
        for r in csv.DictReader(fh): rows.append(r)
    if not rows: return None
    t=[float(r["t"]) for r in rows]; fp=[float(r["fp"]) for r in rows]
    tr=[float(r["tr"]) for r in rows]; th=[float(r["theta_deg"]) for r in rows]
    er=[float(r["err"]) for r in rows]
    fig,ax=plt.subplots(2,1,figsize=(11,7),sharex=True)
    ax[0].plot(t,fp,color="0.6",lw=1.0,label="FP (IMU pitch)")
    ax[0].plot(t,tr,"r--",lw=1.0,label="ref (slew+clamp)")
    ax[0].plot(t,th,"b",lw=1.3,label="θ_motor (EC)")
    ax[0].set_ylabel("açı (°)"); ax[0].legend(loc="best"); ax[0].grid(alpha=0.3)
    mlbl = "mirror (taklit)" if mode=="mirror" else "stabilizasyon (karşı)"
    ax[0].set_title(f"Aşama 3.3 — Eksen-{motor} IMU {mlbl} (RMS {res['rms']:.2f}°)")
    ax[1].plot(t,er,"k",lw=0.9); ax[1].axhline(0,color="r",ls=":",lw=0.8)
    ax[1].set_ylabel("takip hatası θ−ref (°)"); ax[1].set_xlabel("t (s)"); ax[1].grid(alpha=0.3)
    fig.tight_layout()
    p=out/"mirror_plot.png"; fig.savefig(p,dpi=130); plt.close(fig)
    return p


def write_artifacts(out, test_id, args, res, raw, plot):
    mword = "MIRROR" if args.mode=="mirror" else "STAB"
    mtitle = "IMU Mirror Takip (taklit, +pitch)" if args.mode=="mirror" else "IMU Stabilizasyon (karşı, −pitch)"
    with (out/"summary.md").open("w") as f:
        f.write(f"# Aşama 3.3 — Eksen-{args.motor} {mtitle}\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n")
        f.write(f"- **Eksen:** motor-{args.motor} (MODE{'' if args.motor==1 else '2'}:{mword})\n")
        if args.mode=="stab":
            f.write("- **Mod:** STAB — motor base eğimine TERS döner (gerçek gimbalda payload sabit). "
                    "⚠ IMU base'de + mil boş → bu, stabilizasyon YASASININ demosu; tam eylemsiz "
                    "doğrulama IMU payload'a taşınınca (Aşama 5).\n")
        f.write(f"- **Mimari:** cascade + canlı referans (clamp ±60°, slew 90°/s, Kp_pos=6 takip)\n")
        f.write(f"- **Komut:** `python3 scripts/motor_mirror_test.py --motor {args.motor} --dur {args.dur:.0f}`\n\n")
        f.write("## Sonuç (sayısal)\n\n| Metrik | Değer |\n|---|---|\n")
        f.write(f"| Eğme genliği (FP aralığı) | {res['fp_range']:.1f}° ({res['fp_min']:.1f}…{res['fp_max']:.1f}) |\n")
        f.write(f"| Takip RMS (θ−ref) | **{res['rms']:.2f}°** |\n")
        f.write(f"| Hareketli pencere RMS | {res['moving_rms']:.2f}° |\n")
        f.write(f"| Max |hata| | {res['max_err']:.1f}° |\n")
        f.write(f"| Örnek sayısı | {res['n']} |\n")
        f.write(f"\n## Durum: **{res['status']}**\n\n")
        f.write("## Yorum\n")
        if res['status']=="PASS":
            f.write(f"🟢 Motor-{args.motor} IMU pitch'ini takip etti, RMS {res['rms']:.2f}° (<10° hedef). "
                    "Aşama 2.7 mirror (sağlıklı ünite ~4.02°) ile mertebe-uyumlu → instance-based "
                    "MIRROR yolu gerçek-donanımda doğrulandı. Hızlı el bant limitini aşar (beklenen).\n")
        elif res['status']=="NO_MOTION":
            f.write(f"⚠ Board yeterince eğilmedi (FP aralığı {res['fp_range']:.1f}° < 20°). Tekrar: "
                    "pitch ekseninde daha geniş yavaş eğme.\n")
        else:
            f.write(f"⚠ Takip hatası yüksek (RMS {res['rms']:.2f}°). Çok hızlı eğme (bant limiti) veya "
                    "motor/kazanç sorunu — raw incele.\n")
        f.write(f"\n## Artifacts\n- `{raw.name}`\n")
        if plot: f.write(f"- `{plot.name}` (FP/ref/θ_motor + hata)\n")
    meta={"test_id":test_id,"title":f"Aşama 3.3 eksen-{args.motor} IMU {args.mode}",
          "timestamp":dt.datetime.now().isoformat(timespec="seconds"),"commit":commit(),
          "status":res['status'],"motor":args.motor,"mode":args.mode,"metrics":res,
          "note":"serbest mil; instance-based 2-eksen firmware (g_axis); Kp_pos=6 takip",
          "artifacts":[raw.name]+([plot.name] if plot else [])}
    json.dump(meta,(out/"meta.json").open("w"),indent=2,ensure_ascii=False)


if __name__ == "__main__":
    sys.exit(main())
