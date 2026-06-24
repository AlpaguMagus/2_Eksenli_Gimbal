#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded gyro DAMPING ISARETI testi (Asama 5 adim-1) — k_ff +/- hangisi sonumler?
3 faz, her biri STAB (STABDIR2:1 dogru polarite + gravite-FF):
  Faz 1: k_ff=0  (baseline ring-down)
  Faz 2: k_ff=+8
  Faz 3: k_ff=-8
Her fazda sen stand'i BIR kez ~25 it-birak; kontrolcu tutar, ring-down'i logla.
En HIZLI sonen (en az salinim) k_ff isareti = DOGRU damping isareti.
Guvenli: STABDIR2:1 hands-off KARARLI (runaway yok), modest k_ff, clamp +-60.
Cikti: artifacts/5/loaded_gyro_sign/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime
PORT, BAUD = "/dev/ttyACM0", 115200
PH = 7.0   # her faz sn
CFGS=[("k_ff=0 (baseline)",0.0),("k_ff=+8",8.0),("k_ff=-8",-8.0)]
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
FPr=re.compile(r"FP:(-?[\d.]+)")

def run_phase(name,kff):
    print(f"\n>>> {name}: STAB {PH:.0f} sn — stand'i 1 kez ~25 IT-BIRAK")
    send("STOP"); send("STALLEN:0"); time.sleep(0.3)
    send("STABDIR2:1"); send("LFFG2:0.21"); send("LFF2:1"); send(f"KFF2:{kff}")
    ser.reset_input_buffer(); send("MODE2:STAB")
    t0=time.time(); lp=0; T=[]; FP=[]
    while time.time()-t0<PH:
        if time.time()-lp>0.2: send("PING"); lp=time.time()
        ln=ser.readline().decode("utf-8","replace").strip()
        m=FPr.search(ln) if ln.startswith("T_US") else None
        if m: T.append(time.time()-t0); FP.append(float(m.group(1)))
    send("STOP"); time.sleep(0.3)
    if not FP: return name,kff,[],[],None,None
    # itis sonrasi decay: en buyuk |sapma| aninda sonra salinim say + settling
    fp0=FP[0]; rel=[v-fp0 for v in FP]
    ipk=max(range(len(rel)),key=lambda i:abs(rel[i])); peak=abs(rel[ipk])
    tail=rel[ipk:]
    zc=sum(1 for i in range(1,len(tail)) if tail[i]*tail[i-1]<0)        # itis sonrasi salinim
    # settling: |rel| son kez %20*peak ustunde oldugu an
    thr=0.2*peak; sidx=ipk
    for i in range(ipk,len(rel)):
        if abs(rel[i])>thr: sidx=i
    settle=T[sidx]-T[ipk] if sidx<len(T) else None
    print(f"    itis-tepe={peak:.0f}  sonra salinim={zc}  settling~{settle:.1f}s" if settle else f"    tepe={peak:.0f} salinim={zc}")
    return name,kff,T,FP,zc,settle

print("=== Loaded gyro DAMPING isareti testi (DOGRU isaret = en az salinim/en hizli sonme) ===")
R=[run_phase(n,k) for n,k in CFGS]
send("STOP")
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_gyro_sign/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/sign.csv","w",newline="")); w.writerow(["kff","t","fp"])
for n,k,T,FP,zc,st in R:
    for t,v in zip(T,FP): w.writerow([k,f"{t:.3f}",f"{v:.2f}"])
print("\n"+"="*56)
for n,k,T,FP,zc,st in R:
    print(f"  {n:18s}: salinim={zc}  settling={st:.1f}s" if st is not None else f"  {n}: veri yok")
# en az salinim olan = en cok damping
valid=[(n,k,zc,st) for n,k,T,FP,zc,st in R if zc is not None]
if valid:
    best=min(valid,key=lambda x:(x[2], x[3] if x[3] else 99))
    print(f"  >>> EN COK DAMPING: {best[0]} (salinim {best[2]})  -> dogru gyro isareti bu yon")
print("="*56)
ser.close()
json.dump({"test_id":"5.loaded-gyro-sign","timestamp":ts,"commit":commit(),
    "results":[{"cfg":n,"k_ff":k,"post_push_osc":zc,"settling_s":round(st,2) if st else None} for n,k,T,FP,zc,st in R]},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/")
