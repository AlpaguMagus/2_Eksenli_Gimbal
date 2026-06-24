#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Y0 — Yüklü nonlineer plant RIGOROUS ID veri-yakalama (Asama 5, B Yolu).
Protokol (loaded_plant_id_design.m'de turetildi + sentetik dogrulandi, estimator PASS):
  DIP: motor OFF, asili dengeye otur -> fp_dip, th_dip (gravitasyonel-notr referans, theta=0).
  B1 (gravite + statik surtunme): YAVAS UCGEN duty-rampa 0->+umax->-umax->0 (~36 s, kvazi-statik)
      -> histerezis dongusu theta(u); yukari/asagi dal = a*sin(theta)+s+ / a*sin(theta)-s-.
  B3 (validasyon): kopma-USTU birkac duty adimi -> theta(t) gecici -> NRMSE.
  (B2 free-decay omega_n/zeta: AYRI -> scripts/loaded_pendulum_id.py, lift+release.)
Acik-dongu DUTY (saf plant; LFF/KFF KAPALI). Motor KENDI gider (B1/B3) -> sen IZLE.
GUVENLIK: |FP|>72 veya |theta_out|>80 -> DUTY2:0 + abort. umax=0.26 (theta~50°, ±90 kablo-guvenli).
Cikti: artifacts/5/loaded_plant_id/<ts>/raw/plantid.csv -> MATLAB fit (loaded_plant_id_design.m fit-modu).
"""
import serial, time, re, os, csv, json, subprocess, datetime, atexit, sys, math
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC = 360.0/466.0
UMAX = 0.26                    # tepe duty (theta~50°, kopma 0.10 + a*sin50 0.16)
RAMP_UP, RAMP_FULL, RAMP_DN = 9.0, 18.0, 9.0      # ucgen segment sureleri (s)
FP_LIM, TH_LIM = 72.0, 80.0   # guvenlik (IMU pitch / encoder mil acisi)
VAL_STEPS = [0.15, -0.11, 0.20, 0.0]; VAL_HOLD = 3.0

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
def _safe_stop():
    try:
        if ser.is_open: ser.write(b"DUTY2:0\nSTOP\n"); ser.flush(); ser.close()
    except Exception: pass
atexit.register(_safe_stop)
FPr = re.compile(r"FP:(-?[\d.]+)"); ECr = re.compile(r"EC2:(-?\d+)")

ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d = f"artifacts/5/loaded_plant_id/{ts}"; os.makedirs(f"{d}/raw", exist_ok=True)
w = csv.writer(open(f"{d}/raw/plantid.csv","w",newline="")); w.writerow(["phase","t","duty","fp","th_out","fp_rel","th_rel"])
rows = []; aborted = False

def read_one():
    ln = ser.readline().decode("utf-8","replace").strip()
    if not ln.startswith("T_US"): return None
    mf = FPr.search(ln); me = ECr.search(ln)
    if not mf: return None
    return float(mf.group(1)), (int(me.group(1))*LP_DPC if me else 0.0)

def settle(dur, duty=None, ping=True):
    t0=time.time(); lp=0; last=(0.0,0.0)
    while time.time()-t0 < dur:
        if ping and time.time()-lp>0.2: send("PING"); lp=time.time()
        r = read_one()
        if r: last = r
    return last

print("=== Y0 yuklu plant-ID veri-yakalama (B1 ucgen-rampa + B3 validasyon) ===")
send("STOP"); send("STALLEN2:0"); send("LFF2:0"); send("KFF2:0"); send("MODE2:DUTY"); time.sleep(0.4)
print(">>> DIP olcumu: motor OFF, asili dengeye otursun (~2.5 sn, DOKUNMA)...")
fp_dip, th_dip = settle(2.5)
print(f"    DIP: fp_dip={fp_dip:+.1f}°  th_dip={th_dip:+.1f}°  (theta=0 referans)")

def log(phase, duty, t0):
    global aborted
    r = read_one()
    if not r: return
    fp, th = r
    w.writerow([phase, f"{time.time()-t0:.3f}", f"{duty:.4f}", f"{fp:.2f}", f"{th:.2f}",
                f"{fp-fp_dip:.2f}", f"{th-th_dip:.2f}"])
    rows.append((phase, time.time()-t0, duty, fp, th))
    if (abs(fp) > FP_LIM or abs(th) > TH_LIM) and not aborted:
        send("DUTY2:0"); aborted = True
        print(f"  !! GUVENLIK: |FP|={abs(fp):.0f} |th|={abs(th):.0f} -> DUTY2:0 ABORT")

# ---- B1: yavas ucgen duty-rampa (kvazi-statik histerezis) ----
print(f">>> B1: ucgen duty-rampa 0->+{UMAX}->-{UMAX}->0 (~{RAMP_UP+RAMP_FULL+RAMP_DN:.0f} sn). Motor kendi gidecek, IZLE.")
t0 = time.time(); lp = 0
def tri_duty(te):
    if te < RAMP_UP:                 return  UMAX*(te/RAMP_UP)
    if te < RAMP_UP+RAMP_FULL:       return  UMAX*(1 - 2*(te-RAMP_UP)/RAMP_FULL)
    if te < RAMP_UP+RAMP_FULL+RAMP_DN: return -UMAX*(1 - (te-RAMP_UP-RAMP_FULL)/RAMP_DN)
    return 0.0
TT = RAMP_UP+RAMP_FULL+RAMP_DN
while True:
    te = time.time()-t0
    if te >= TT or aborted: break
    du = tri_duty(te)
    if time.time()-lp > 0.10: send(f"DUTY2:{du:.4f}"); lp=time.time()
    log("B1", du, t0)
send("DUTY2:0"); settle(2.0)

# ---- B3: validasyon adimlari (kopma ustu) ----
if not aborted:
    print(">>> B3: validasyon adimlari (kopma ustu) — IZLE.")
    for du in VAL_STEPS:
        send(f"DUTY2:{du:.4f}"); t0=time.time(); lp=0
        while time.time()-t0 < VAL_HOLD and not aborted:
            if time.time()-lp>0.2: send("PING"); lp=time.time()
            log("B3", du, t0)
        send("DUTY2:0"); settle(1.2)
send("DUTY2:0"); send("STOP"); ser.close()

# ---- ozet/artifact ----
fp_span = (max(r[3] for r in rows)-min(r[3] for r in rows)) if rows else 0.0
status = "OK" if (rows and not aborted and fp_span > 20) else ("ABORTED" if aborted else "NO_MOTION")
print("\n"+"="*58)
print(f"  Ornek: {len(rows)}  FP-span: {fp_span:.1f}°  durum: {status}")
print(f"  Ham -> MATLAB fit: {d}/raw/plantid.csv (B1=histerezis, B3=validasyon)")
print(f"  B2 (omega_n/zeta) AYRI: python3 scripts/loaded_pendulum_id.py")
print("="*58)
json.dump({"test_id":"5.loaded-plant-id","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":{"fp_dip":round(fp_dip,1),"th_dip":round(th_dip,1),"n_samples":len(rows),
        "fp_span_deg":round(fp_span,1),"umax":UMAX}},
    open(f"{d}/meta.json","w"), ensure_ascii=False, indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 5.loaded-plant-id — Y0 yüklü plant-ID veri-yakalama

- **Test ID:** 5.loaded-plant-id
- **Tarih:** {ts}
- **Commit:** {commit()}
- **Hedef:** Yüklü nonlineer plant için B1 (gravite+statik-sürtünme, üçgen-rampa histerezis) +
  B3 (validasyon adımları) ham verisi. Gravite/sürtünme ayrıştırma → `loaded_plant_id_design.m`.
- **Komut:** `python3 scripts/loaded_plant_id_capture.py`

## Sonuç
| Metric | Değer |
|---|---|
| DIP referans (fp/θ_out) | {fp_dip:+.1f}° / {th_dip:+.1f}° |
| Örnek sayısı | {len(rows)} |
| FP span | {fp_span:.1f}° |
| Durum | {status} |

## Durum / gerekçe
`{status}` — B1 histerezis + B3 validasyon ham verisi `raw/plantid.csv`'de. Gravite/sürtünme
ayrıştırma + ω_n/ζ (free-decay ayrı) + NRMSE → MATLAB. ABORTED ise |FP|>72/|θ|>80 güvenlik tetiklendi.

## Artifacts
- raw/plantid.csv  (phase,t,duty,fp,th_out,fp_rel,th_rel)
""")
print(f"Artifact: {d}/")
