#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded SİSTEMATİK duty-step sistem tanımlama (serbest-mil Aşama-1 metodolojisi, yüklüye uyarlı).
Serbest mil: duty->sabit HIZ (1. mertebe K,τ). Yüklü = sarkaç (gravite): duty->sabit AÇI (2. mertebe).
Aynı sistematik: BELLİ duty oranları ver (±90 güvenli) -> AÇI çıktısını ölç -> yüklü plant fit.
  Her duty için: sabit-açı (statik kazanç) + geçici-rejim (ω_n, ζ overshoot/periyottan).
Açık-döngü DUTY (Aşama-1 gibi), SINIRLI duty (overshoot dahil <±80). Motor kendi gider — sen İZLE.
Güvenlik: |FP|>78 -> STOP. Cikti: artifacts/5/loaded_sysid/<ts>/ (ham -> MATLAB fit).
"""
import serial, time, re, os, csv, json, subprocess, datetime, math, atexit
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC=360.0/466.0
DUTIES=[0.05, 0.08, -0.05, -0.08, 0.10, -0.10]   # sınırlı; sabit-açı ~ asin(duty/0.21)
STEP=3.0; REST=1.8
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
def _safe_stop():
    try:
        if ser.is_open:
            ser.write(b"STOP\n"); ser.flush(); ser.close()
    except Exception:
        pass
atexit.register(_safe_stop)
FPr=re.compile(r"FP:(-?[\d.]+)"); ECr=re.compile(r"EC2:(-?\d+)")

def settle(dur, ping_duty=None):
    t0=time.time(); lp=0; last=(0,0)
    while time.time()-t0<dur:
        if time.time()-lp>0.2: send("PING"); lp=time.time()
        ln=ser.readline().decode("utf-8","replace").strip()
        if ln.startswith("T_US"):
            mf=FPr.search(ln); me=ECr.search(ln)
            if mf: last=(float(mf.group(1)), int(me.group(1))*LP_DPC if me else 0)
    return last

print("=== Loaded SİSTEMATİK duty-step ID (serbest-mil gibi, AÇI ölçer) ===")
send("STOP"); send("STALLEN2:0"); send("LFF2:0"); send("KFF2:0")   # FF KAPALI (saf plant ID)
send("MODE2:DUTY"); time.sleep(0.4)
print(">>> Motor kendi gidecek (sınırlı duty). İZLE, dokunma. ~30 sn.")
fp_hang,_=settle(1.5); print(f"    Asılı denge FP0={fp_hang:+.1f}°")
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_sysid/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/sysid.csv","w",newline="")); w.writerow(["duty","t","fp","fp_rel","theta_out"])
res=[]
for du in DUTIES:
    send(f"DUTY2:{du}")
    t0=time.time(); lp=0; seg=[]; stopped=False
    while time.time()-t0<STEP:
        if time.time()-lp>0.2: send("PING"); lp=time.time()
        ln=ser.readline().decode("utf-8","replace").strip()
        if not ln.startswith("T_US"): continue
        mf=FPr.search(ln); me=ECr.search(ln)
        if not mf: continue
        fp=float(mf.group(1)); th=int(me.group(1))*LP_DPC if me else 0; tt=time.time()-t0
        seg.append((tt,fp,fp-fp_hang,th)); w.writerow([du,f"{tt:.3f}",f"{fp:.2f}",f"{fp-fp_hang:.2f}",f"{th:.2f}"])
        if abs(fp)>78 and not stopped: send("DUTY2:0"); stopped=True; print("  !! |FP|>78 GUVENLIK")
    send("DUTY2:0")
    sseg=[s for s in seg if s[0]>STEP-1.0]
    ss=sum(s[2] for s in sseg)/len(sseg) if sseg else 0           # sabit açı (denge-rel)
    pk=max((abs(s[2]) for s in seg), default=0)                   # peak (overshoot)
    res.append((du,ss,pk)); print(f"  duty={du:+.2f} -> sabit açı={ss:+6.1f}°  peak={pk:5.1f}°")
    fp_hang,_=settle(REST)   # dengeye dön + güncelle (drift takip)
send("DUTY2:0"); send("STOP"); ser.close()

# statik kazanç fit: açı_ss = K_stat * duty  (lineer)
pts=[(du,ss) for du,ss,pk in res]
n=len(pts); sx=sum(p[0] for p in pts); sy=sum(p[1] for p in pts)
sxx=sum(p[0]**2 for p in pts); sxy=sum(p[0]*p[1] for p in pts)
Kstat=(n*sxy-sx*sy)/(n*sxx-sx*sx) if (n*sxx-sx*sx)!=0 else 0
print("\n"+"="*56)
print(f"  STATİK KAZANÇ: açı = {Kstat:.0f}°/duty  (= {Kstat*math.pi/180:.2f} rad/duty)")
print(f"  Türetilen K_m/J = ω_n²·(rad/duty) ile çapraz-kontrol; ω_n/ζ ham geçici-rejimden (MATLAB fit)")
print(f"  Ham veri -> MATLAB: {d}/raw/sysid.csv (her duty step'in açı yanıtı)")
print("="*56)
status="OK" if (Kstat!=0 and max((abs(ss) for du,ss,pk in res),default=0)>1.0) else "NO_MOTION"
json.dump({"test_id":"5.loaded-sysid-systematic","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":{"K_static_deg_per_duty":round(Kstat,1),"steps":[[du,round(ss,1),round(pk,1)] for du,ss,pk in res],
        "hang_eq_deg":round(fp_hang,1)},
    "note":"Serbest-mil metodolojisi yüklüye uyarlı: duty->AÇI (2.mertebe sarkaç). ω_n/ζ MATLAB fit raw'dan."},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 5.loaded-sysid-systematic — Yüklü sistematik duty-step ID

- **Test ID:** 5.loaded-sysid-systematic
- **Tarih:** {ts}
- **Commit:** {commit()}
- **Hedef:** Yüklü (sarkaç) eksende belirli duty oranlarına karşılık sabit-açı yanıtını ölçüp statik kazanç (K_static) ve geçici-rejim verisini çıkarmak (MATLAB fit için).
- **Komut:** `python3 scripts/loaded_sysid_systematic.py`

## Sonuç (sayısal)
- **K_static:** {Kstat:.1f} °/duty ({Kstat*math.pi/180:.2f} rad/duty)
- **Asılı denge (hang_eq):** {fp_hang:+.1f}°
- **Duty step yanıtları (duty -> sabit açı / peak):**
""")
    for du,ss,pk in res:
        f.write(f"  - duty={du:+.2f} -> sabit açı={ss:+.1f}°  peak={pk:.1f}°\n")
    f.write(f"""
## Durum / gerekçe
- **Status:** {status} — {"motor hareket etti (sabit açı sapması > 1.0° ve K_static != 0)" if status=="OK" else "ölü/kilitli motor: anlamlı açı sapması yok (yanlış-PASS önlendi)"}

## Artifacts
- raw/sysid.csv
""")
print(f"Artifact: {d}/")
