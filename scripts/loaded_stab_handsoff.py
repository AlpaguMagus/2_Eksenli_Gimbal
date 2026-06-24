#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded STAB HANDS-OFF polarite/stabilite teshisi — sen DOKUNMA, sadece izle.
Her config: STAB'a gir (FP0 yakalanir), hic dokunulmaz, gravite kendi perturbasyonunu verir.
  STABLE  : FP ~FP0'da kalir (kontrolcu tutar)
  OSCILLATE: FP0 etrafinda sinirli salinim (dogru polarite + az sonum)
  DIVERGE : FP0'dan tek-yon kacar -> clamp (YANLIS polarite = pozitif feedback)
Konfig: pure cascade P-stab (gyro OFF, gravite-FF OFF) -> SADECE polariteyi izole eder.
Cikti: artifacts/5/loaded_stab_handsoff/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC = 360.0/466.0
HOLD = 6.0   # her config hands-off sn

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
FPr=re.compile(r"FP:(-?[\d.]+)"); ECr=re.compile(r"EC2:(-?\d+)"); Ur=re.compile(r"U2:(-?[\d.]+)")

def run_cfg(name, stabdir):
    print(f"\n>>> {name}: STAB hands-off {HOLD:.0f} sn — DOKUNMA")
    send("STOP"); send("STALLEN:0"); time.sleep(0.4)
    send("LFF2:0"); send("KFF2:0"); send(f"STABDIR2:{stabdir}")   # gravite-FF OFF, gyro OFF
    ser.reset_input_buffer(); send("MODE2:STAB")
    t0=time.time(); lp=0; rows=[]; FP0=None
    while time.time()-t0<HOLD:
        if time.time()-lp>0.2: send("PING"); lp=time.time()
        ln=ser.readline().decode("utf-8","replace").strip()
        if not ln.startswith("T_US"): continue
        mf=FPr.search(ln); me=ECr.search(ln); mu=Ur.search(ln)
        if not mf: continue
        fp=float(mf.group(1)); th=int(me.group(1))*LP_DPC if me else 0.0; u=float(mu.group(1)) if mu else 0.0
        if FP0 is None: FP0=fp
        rows.append((time.time()-t0, fp, fp-FP0, th, u))
    send("STOP"); time.sleep(0.3)
    rel=[r[2] for r in rows]
    if not rel: return name, rows, "VERI-YOK", 0, 0, 0
    final=rel[-1]; mx=max(abs(x) for x in rel)
    zc=sum(1 for i in range(1,len(rel)) if rel[i]*rel[i-1]<0)
    # siniflandirma: |final| buyuk + dusuk zc -> DIVERGE; yuksek zc -> OSCILLATE; kucuk -> HOLD
    if mx < 4.0:                         cls="HOLD (tutuyor)"
    elif zc>=4 and abs(final)<mx*0.6:    cls="OSCILLATE (sinirli salinim)"
    elif abs(final) > 0.6*mx and mx>6:   cls="DIVERGE (kacti -> yanlis polarite?)"
    else:                                cls="BELIRSIZ"
    print(f"    FP_rel: final={final:+.1f} max|.|={mx:.1f} sifir-gecis={zc}  -> {cls}")
    return name, rows, cls, final, mx, zc

print("=== Loaded STAB hands-off polarite teshisi (DOKUNMA) ===")
results=[]
results.append(run_cfg("A: STABDIR=+1 (turetilen dogru)", 1))
results.append(run_cfg("B: STABDIR=-1 (ters)", -1))
send("STOP");

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_stab_handsoff/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/handsoff.csv","w",newline="")); w.writerow(["cfg","t","fp","fp_rel","theta_out","u2"])
for name,rows,cls,final,mx,zc in results:
    for r in rows: w.writerow([name[:1]]+[f"{r[0]:.3f}",f"{r[1]:.2f}",f"{r[2]:.2f}",f"{r[3]:.2f}",f"{r[4]:.3f}"])
print("\n"+"="*56)
for name,rows,cls,final,mx,zc in results:
    print(f"  {name:34s} -> {cls}  (final {final:+.1f}, max {mx:.1f})")
print("="*56)
ser.close()
json.dump({"test_id":"5.loaded-stab-handsoff","timestamp":ts,"commit":commit(),
    "results":[{"cfg":n,"class":c,"final_rel":round(f,1),"max_rel":round(m,1),"zero_cross":z}
               for n,_,c,f,m,z in results]},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/")
