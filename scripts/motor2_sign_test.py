#!/usr/bin/env python3
"""
Aşama 3.2b — Motor-2 yön/kimlik (sign/identity) doğrulama testi.

ASIL SORU: Motor-2 (2. TB6612, PB1 PWM / PB4-PB5 yön / PB10 STBY) açık-döngüde
dönüyor mu, encoder-2 (TIM1 PA8/PA9, telemetri EC2) onu okuyor mu, ve
**motor-2'nin (duty → encoder işareti) polaritesi motor-1 ile AYNI mı TERS mi?**

NEDEN kritik: Aşama 3.3 baseline'da motor-2'ye Aşama-2 cascade'i (poz P → hız PI)
YENİDEN KULLANILACAK. Cascade geri-beslemesi yanlış işaretliyse (motor-2 enkoder
polaritesi ters) → pozitif geri besleme → kararsızlık/kaçış. Bu test, baseline'dan
ÖNCE polariteyi ampirik saptar (gerekirse firmware'de motor-2 için işaret çevirme).

Akış (denetimli, serbest mil — DOKUNMA):
  1. (ref) MODE:DUTY → DUTY:+d → motor-1'i sür, ΔEC işaretini ölç (motor-1 referansı)
  2. DUTY2:+d → motor-2 ileri, ΔEC2 işareti + hız
  3. DUTY2:-d → motor-2 geri, ΔEC2 işareti + hız
  4. STOP

Karar:
  - Motor-2 her iki yönde döndü mü? (|rate| > eşik → motor + enkoder sağlam)
  - +duty ve -duty işaretleri ZIT mı? (kendi-içinde tutarlı)
  - sign(motor-2 +duty) == sign(motor-1 +duty)? → polarite AYNI; değilse TERS
  PASS = motor-2 iki yönde döndü + işaretler zıt + motor-1 ref döndü.
  Polarite (AYNI/TERS) → 3.3 için kaydedilir (FALSE-PASS önleme: ölü motor PASS vermez).

Çıktı (CLAUDE.md disiplini): artifacts/3/motor2_sign/<test_id>/
    ├── raw/data.csv(.gz)   ├── summary.md   ├── meta.json   └── motor2_sign_plot.png

Kullanım:
    python3 scripts/motor2_sign_test.py
    python3 scripts/motor2_sign_test.py --duty 0.30 --hold 2.0 --port /dev/ttyACM0

⚠ Watchdog (firmware 1 sn komutsuz → motor durur); script PING stream'ler.
   Duty-cap firmware %50; varsayılan 0.30 düşük/güvenli. Motor-2'de stall-lockout
   YOK (3.2b minimal sürücü) → denetimli, kısa süreli sürüş.
Kaynaklar: [TB6612_DS] sf 4 (H-SW yön), [Pololu_25D] 48 CPR, asama_3_mimo_model.md §12.2
"""
from __future__ import annotations
import argparse, csv, datetime as dt, gzip, json, shutil, subprocess, sys, time, re
from pathlib import Path
import serial

EC_RE   = re.compile(r"EC:(-?\d+)")        # motor-1 enkoder (referans)
EC2_RE  = re.compile(r"EC2:(-?\d+)")       # motor-2 enkoder
U2_RE   = re.compile(r"U2:(-?[\d.]+)")     # motor-2 uygulanan signed duty
HEARTBEAT_S = 0.25
GZIP_THRESHOLD = 50 * 1024
CPR_MOTOR = 48.0 * 4              # motor şaftı 4×-decoded event/rev (quadrature)
MIN_RATE_CPS = 200.0             # döndü-saymak için min |count/s| (gürültü eşiği üstü)


def ts(): return time.strftime("%H:%M:%S")
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "UNKNOWN"
def send(ser, c): ser.write((c+"\n").encode())
def sign_str(x): return "+" if x > 0 else ("-" if x < 0 else "0")


def drive_segment(ser, label, cmd, hold_s, ec_key, writer, seg_idx, t_global0):
    """Bir sürüş segmenti: cmd gönder, hold_s boyunca EC/EC2 örnekle, rate hesapla.
       ec_key: 'EC' (motor-1) veya 'EC2' (motor-2) — hangi enkoderin rate'i ölçülecek.
       Dönüş: {label, cmd, rate_cps, n, c_start, c_end, dt} """
    rgx = EC_RE if ec_key == "EC" else EC2_RE
    send(ser, cmd)
    print(f"[{ts()}] {label:18s}  {cmd:10s}  ({hold_s:.1f}s)", flush=True)
    t0 = time.time(); last_hb = t0; last_p = t0
    samples = []   # (t_seg, ec, ec2, u2)
    while time.time() - t0 < hold_s:
        now = time.time()
        if now - last_hb >= HEARTBEAT_S: send(ser, "PING"); last_hb = now
        line = ser.readline().decode("utf-8", "ignore").strip()
        m1 = EC_RE.search(line); m2 = EC2_RE.search(line); mu = U2_RE.search(line)
        if not (m1 and m2): continue
        ec = int(m1.group(1)); ec2 = int(m2.group(1)); u2 = float(mu.group(1)) if mu else 0.0
        t_seg = now - t0
        samples.append((t_seg, ec, ec2, u2))
        writer.writerow([seg_idx, label, cmd, f"{now-t_global0:.4f}", f"{t_seg:.4f}", ec, ec2, f"{u2:.3f}"])
        if now - last_p >= 0.5:
            cval = ec if ec_key == "EC" else ec2
            print(f"    t={t_seg:4.1f}s  {ec_key}={cval:+8d}  (EC={ec:+d} EC2={ec2:+d} U2={u2:+.2f})")
            last_p = now
    # rate: ilk %20'yi at (rampa/cevap), kalan pencerede (son-baş)/dt
    rate = 0.0; c_start = c_end = 0; dseg = 0.0; n = len(samples)
    if n >= 5:
        idx0 = int(n * 0.2)
        col = 1 if ec_key == "EC" else 2
        c_start = samples[idx0][col]; c_end = samples[-1][col]
        dseg = samples[-1][0] - samples[idx0][0]
        rate = (c_end - c_start) / dseg if dseg > 0 else 0.0
    return {"label": label, "cmd": cmd, "ec_key": ec_key, "n": n,
            "rate_cps": round(rate, 1), "c_start": c_start, "c_end": c_end, "dt_s": round(dseg, 2)}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--duty", type=float, default=0.30, help="test duty büyüklüğü (0..0.5)")
    ap.add_argument("--hold", type=float, default=2.0, help="her segment süresi (s)")
    ap.add_argument("--no-m1-ref", action="store_true", help="motor-1 referans sürüşünü atla")
    ap.add_argument("--test-id", default=None)
    args = ap.parse_args()
    d = max(0.0, min(args.duty, 0.50))

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/3/motor2_sign") / test_id
    (out / "raw").mkdir(parents=True, exist_ok=True)
    raw_csv = out / "raw" / "data.csv"

    print(f"[{ts()}] Motor-2 yön/kimlik testi — duty=±{d}, hold={args.hold}s")
    print(f"[{ts()}] DOKUNMA — serbest mil. Motor-2'nin FİZİKSEL dönüş yönünü gözle.\n")
    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    segs = []
    try:
        ser.reset_input_buffer(); send(ser, "PING"); time.sleep(0.3)
        send(ser, "MODE:DUTY"); time.sleep(0.1)   # motor-1 DUTY modu (ref için); motor-2 mod-bağımsız
        ser.reset_input_buffer()
        t_global0 = time.time()
        with raw_csv.open("w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["seg", "label", "cmd", "t_global", "t_seg", "ec", "ec2", "u2"])
            si = 0
            if not args.no_m1_ref:
                segs.append(drive_segment(ser, "motor-1 ref +", f"DUTY:{d}", args.hold, "EC", w, (si:=si+1), t_global0))
                send(ser, "DUTY:0"); time.sleep(0.6)
            segs.append(drive_segment(ser, "motor-2 ileri +", f"DUTY2:{d}", args.hold, "EC2", w, (si:=si+1), t_global0))
            send(ser, "DUTY2:0"); time.sleep(0.6)
            segs.append(drive_segment(ser, "motor-2 geri -", f"DUTY2:-{d}", args.hold, "EC2", w, (si:=si+1), t_global0))
            send(ser, "DUTY2:0"); time.sleep(0.2)
        send(ser, "STOP"); time.sleep(0.2)
    except KeyboardInterrupt:
        send(ser, "STOP"); print("\nCtrl-C — STOP")
    finally:
        try: ser.write(b"STOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    raw_final = raw_csv
    if raw_csv.exists() and raw_csv.stat().st_size > GZIP_THRESHOLD:
        gz = raw_csv.with_suffix(".csv.gz")
        with raw_csv.open("rb") as fi, gzip.open(gz, "wb") as fo: shutil.copyfileobj(fi, fo)
        raw_csv.unlink(); raw_final = gz

    # ── Analiz ────────────────────────────────────────────────────────────
    m1_ref = next((s for s in segs if s["label"].startswith("motor-1")), None)
    m2_plus = next((s for s in segs if s["label"].startswith("motor-2 ileri")), None)
    m2_minus = next((s for s in segs if s["label"].startswith("motor-2 geri")), None)

    spun_plus = m2_plus and abs(m2_plus["rate_cps"]) > MIN_RATE_CPS
    spun_minus = m2_minus and abs(m2_minus["rate_cps"]) > MIN_RATE_CPS
    opposite = (m2_plus and m2_minus and
                m2_plus["rate_cps"] * m2_minus["rate_cps"] < 0)   # işaretler zıt
    m1_spun = (m1_ref is None) or abs(m1_ref["rate_cps"]) > MIN_RATE_CPS

    # polarite: motor-2 +duty işareti vs motor-1 +duty işareti
    polarity = "BİLİNMİYOR"
    if m1_ref and m2_plus and m1_spun and spun_plus:
        same = (m1_ref["rate_cps"] > 0) == (m2_plus["rate_cps"] > 0)
        polarity = "AYNI (motor-1 ile)" if same else "TERS (motor-1'e göre)"
    elif m2_plus and spun_plus:
        # ref yoksa: mutlak konvansiyon (+duty=CW → +count beklenir, motor-1 gibi)
        polarity = "AYNI (varsayılan: +duty→+count)" if m2_plus["rate_cps"] > 0 else "TERS (+duty→-count)"

    if spun_plus and spun_minus and opposite and m1_spun:
        status = "PASS"
    elif not (spun_plus or spun_minus):
        status = "NO_SPIN"     # motor-2 hiç dönmedi (kablo/güç/sürücü) — FAIL
    elif not opposite:
        status = "SIGN_INCONSISTENT"  # iki yön aynı işaret → enkoder/yön kablolama sorunu
    else:
        status = "PARTIAL"     # bir yön dönmedi

    plot_path = make_plot(out, raw_final)
    write_artifacts(out, test_id, args, d, segs, status, polarity,
                    {"spun_plus": spun_plus, "spun_minus": spun_minus,
                     "opposite": opposite, "m1_spun": m1_spun}, raw_final, plot_path)

    print(f"\n[{ts()}] ── ÖZET ──")
    if m1_ref: print(f"    motor-1 ref +duty : {m1_ref['rate_cps']:+.0f} count/s ({sign_str(m1_ref['rate_cps'])})")
    if m2_plus: print(f"    motor-2 +duty     : {m2_plus['rate_cps']:+.0f} count/s ({sign_str(m2_plus['rate_cps'])})")
    if m2_minus: print(f"    motor-2 -duty     : {m2_minus['rate_cps']:+.0f} count/s ({sign_str(m2_minus['rate_cps'])})")
    print(f"    polarite          : {polarity}")
    print(f"[{ts()}] Durum: {status}")
    print(f"[{ts()}] Artifact: {out}/")
    if plot_path: print(f"[{ts()}] Plot: {plot_path}")
    return 0


def make_plot(out, raw):
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    except Exception: return None
    rows = []
    op = gzip.open if str(raw).endswith(".gz") else open
    with op(raw, "rt") as fh:
        for r in csv.DictReader(fh): rows.append(r)
    if not rows: return None
    tg = [float(r["t_global"]) for r in rows]
    ec = [int(r["ec"]) for r in rows]
    ec2 = [int(r["ec2"]) for r in rows]
    u2 = [float(r["u2"]) for r in rows]
    fig, ax = plt.subplots(2, 1, figsize=(11, 6.5), sharex=True)
    ax[0].plot(tg, ec, color="0.6", lw=1.0, label="EC (motor-1, ref)")
    ax[0].plot(tg, ec2, "b", lw=1.4, label="EC2 (motor-2)")
    ax[0].set_ylabel("enkoder count"); ax[0].legend(loc="best"); ax[0].grid(alpha=0.3)
    ax[0].set_title("Aşama 3.2b — Motor-2 yön/kimlik doğrulama (açık-döngü)")
    ax[1].plot(tg, u2, "k", lw=1.0); ax[1].axhline(0, color="r", ls=":", lw=0.8)
    ax[1].set_ylabel("U2 (motor-2 duty)"); ax[1].set_xlabel("t (s)")
    ax[1].set_ylim(-0.55, 0.55); ax[1].grid(alpha=0.3)
    fig.tight_layout()
    p = out / "motor2_sign_plot.png"; fig.savefig(p, dpi=130); plt.close(fig)
    return p


def write_artifacts(out, test_id, args, d, segs, status, polarity, checks, raw, plot):
    with (out / "summary.md").open("w") as f:
        f.write("# Aşama 3.2b — Motor-2 Yön/Kimlik Doğrulama\n\n")
        f.write(f"- **Test ID:** {test_id}\n- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M}\n")
        f.write(f"- **Commit:** `{commit()}`\n")
        f.write(f"- **Hedef:** Motor-2 açık-döngü döner mi + EC2 okur mu + polarite (motor-1'e göre)?\n")
        f.write(f"- **Komut:** `python3 scripts/motor2_sign_test.py --duty {d} --hold {args.hold}`\n")
        f.write(f"- **NOT:** Serbest mil (yüksüz), denetimli. Motor-2 stall-lockout YOK (3.2b minimal sürücü).\n\n")
        f.write("## Sonuç (sayısal)\n\n")
        f.write("| Segment | Komut | rate (count/s) | işaret | süre | durum |\n|---|---|---|---|---|---|\n")
        for s in segs:
            spun = abs(s["rate_cps"]) > MIN_RATE_CPS
            f.write(f"| {s['label']} | `{s['cmd']}` | {s['rate_cps']:+.0f} | {sign_str(s['rate_cps'])} | "
                    f"{s['dt_s']}s | {'🟢 döndü' if spun else '⚠ dönmedi'} |\n")
        f.write(f"\n- **Polarite:** **{polarity}**\n")
        f.write(f"- eşik: |rate| > {MIN_RATE_CPS:.0f} count/s = 'döndü' "
                f"(motor şaftı {CPR_MOTOR:.0f} CPR → ~{MIN_RATE_CPS/CPR_MOTOR:.1f} dev/s)\n\n")
        f.write(f"## Durum: **{status}**\n\n")
        f.write("## PASS/FAIL gerekçesi\n")
        if status == "PASS":
            f.write("🟢 Motor-2 her iki yönde döndü, encoder-2 (EC2) okudu, işaretler ZIT (kendi-içinde "
                    "tutarlı), motor-1 referansı da döndü. Polarite saptandı.\n\n")
            if "TERS" in polarity:
                f.write("⚠ **POLARİTE TERS** → Aşama 3.3 baseline'da motor-2 cascade'i için enkoder veya "
                        "duty işareti ÇEVRİLMELİ (yoksa pozitif geri besleme → kaçış). Firmware'de motor-2 "
                        "için işaret-çevirme bayrağı eklenecek.\n")
            else:
                f.write("✓ **POLARİTE AYNI** → Aşama 2 cascade'i motor-2'ye işaret değişikliği olmadan "
                        "yeniden kullanılabilir (3.3 baseline).\n")
        elif status == "NO_SPIN":
            f.write("✗ Motor-2 dönmedi. Olası: PB1/PB4/PB5/PB10 kablo, 2. TB6612 güç (VM=12V, VCC=3.3/5V, "
                    "STBY-2=PB10), motor bağlantısı (AO1/AO2). Multimetre: STBY-2 HIGH mı, PWM PB1'de var mı.\n")
        elif status == "SIGN_INCONSISTENT":
            f.write("✗ İki yön AYNI işaret → enkoder-2 A/B kanalı (PA8/PA9) ters bağlı VEYA yön (PB4/PB5) "
                    "tek yönde takılı. Kablolama kontrol.\n")
        else:
            f.write("⚠ Kısmi: bir yön dönmedi veya motor-1 referansı eksik. raw/data.csv incele.\n")
        f.write("\n## Artifacts\n")
        f.write(f"- `{raw.name}` (seg/EC/EC2/U2 zaman serisi)\n")
        if plot: f.write(f"- `{plot.name}` (EC2 + U2 vs t)\n")
    meta = {"test_id": test_id, "title": "Aşama 3.2b motor-2 yön/kimlik",
            "timestamp": dt.datetime.now().isoformat(timespec="seconds"), "commit": commit(),
            "status": status, "duty": d, "hold_s": args.hold, "polarity": polarity,
            "checks": checks, "min_rate_cps": MIN_RATE_CPS,
            "segments": segs, "artifacts": [raw.name] + ([plot.name] if plot else [])}
    json.dump(meta, (out / "meta.json").open("w"), indent=2, ensure_ascii=False)


if __name__ == "__main__":
    sys.exit(main())
