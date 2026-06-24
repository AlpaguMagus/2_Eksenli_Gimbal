#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded SARKAC free-decay ID (Asama 5.x — yuk ile sistem tanimlama, ROADMAP KRITIK NOT).
Yuklu LP = gravite sarkaci; yuksuz modelde YOK. Stabilizasyon damping'ini ANALITIK tasarlamak icin
sarkacin omega_n (dogal frekans) ve zeta (sonum) lazim. Yontem: COAST (motor Hi-Z) + free-decay:
  sen stand'i ~30 kaldirip BIRAK, serbestce 2-3 salinim yapsin. FP ring-down'dan:
    omega_n = 2*pi/T  (ardisik tepe periyodu),  zeta = delta/sqrt(4pi^2+delta^2), delta=ln(A_k/A_k+1)
Pasif test (motor calismaz) -> guvenli. Cikti: artifacts/5/loaded_pendulum_id/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime, math
PORT, BAUD = "/dev/ttyACM0", 115200
CAP = 16.0   # yakalama sn
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
FPr=re.compile(r"FP:(-?[\d.]+)")

send("STOP"); send("STALLEN:0"); time.sleep(0.4)   # COAST (Hi-Z), motor serbest
print(f"=== Loaded sarkac free-decay ID (COAST/pasif) ===")
print(f">>> {CAP:.0f} sn: stand'i ~30 KALDIR + BIRAK, serbestce salinsin (2-3 kez). Motor calismaz.")
ser.reset_input_buffer()
t0=time.time(); lp=0; T=[]; FP=[]
while time.time()-t0<CAP:
    if time.time()-lp>0.5: send("PING"); lp=time.time()   # watchdog (DUTY modunda zaten coast)
    ln=ser.readline().decode("utf-8","replace").strip()
    m=FPr.search(ln) if ln.startswith("T_US") else None
    if m: T.append(time.time()-t0); FP.append(float(m.group(1)))
send("STOP"); ser.close()

# --- tepe tespiti (basit yerel-maksimum, isaret-degisimli) ---
fp0=sum(FP)/len(FP) if FP else 0.0
y=[v-fp0 for v in FP]
peaks=[]  # (t, amp, sign)
for i in range(2,len(y)-2):
    if abs(y[i])<2.0: continue
    if y[i]>0 and y[i]>=y[i-1] and y[i]>=y[i+1] and y[i]>y[i-2] and y[i]>y[i+2]:
        peaks.append((T[i], y[i], +1))
    if y[i]<0 and y[i]<=y[i-1] and y[i]<=y[i+1] and y[i]<y[i-2] and y[i]<y[i+2]:
        peaks.append((T[i], y[i], -1))
# ardisik AYNI yondeki tepeler -> periyot & log-decrement
pos=[p for p in peaks if p[2]>0];
# komsu tepeleri ayikla (min 0.15s arali)
def thin(ps):
    out=[]
    for p in ps:
        if not out or p[0]-out[-1][0]>0.15: out.append(p)
        elif abs(p[1])>abs(out[-1][1]): out[-1]=p
    return out
pos=thin(pos)
periods=[pos[i+1][0]-pos[i][0] for i in range(len(pos)-1)]
T_osc=(sum(periods)/len(periods)) if periods else None
wn=(2*math.pi/T_osc) if T_osc else None
# log decrement ardisik POZ tepe genliklerinden
deltas=[math.log(abs(pos[i][1])/abs(pos[i+1][1])) for i in range(len(pos)-1) if abs(pos[i+1][1])>0.5]
delta=(sum(deltas)/len(deltas)) if deltas else None
zeta=(delta/math.sqrt(4*math.pi**2+delta**2)) if delta else None
wn_undamped=(wn/math.sqrt(1-zeta**2)) if (wn and zeta and zeta<1) else wn

print("\n"+"="*56)
print(f"  Yakalanan ornek: {len(FP)}  FP {min(FP):+.1f}..{max(FP):+.1f}  denge~{fp0:+.1f}")
print(f"  Tespit edilen poz-tepe: {len(pos)}  (genlikler: {[round(p[1],1) for p in pos]})")
if T_osc:
    print(f"  Salinim periyodu T = {T_osc:.3f} s  ->  omega_d = {wn:.2f} rad/s ({wn/2/math.pi:.2f} Hz)")
if zeta is not None:
    print(f"  Log-decrement delta = {delta:.3f}  ->  zeta = {zeta:.3f}  (sonum orani)")
    print(f"  omega_n (sonumsuz) = {wn_undamped:.2f} rad/s ({wn_undamped/2/math.pi:.2f} Hz)")
else:
    print("  zeta hesaplanamadi (yeterli ardisik tepe yok — daha buyuk/temiz salinim gerek)")
print("="*56)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_pendulum_id/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
import csv as _c
w=_c.writer(open(f"{d}/raw/decay.csv","w",newline="")); w.writerow(["t","fp"])
for t,v in zip(T,FP): w.writerow([f"{t:.3f}",f"{v:.2f}"])
json.dump({"test_id":"5.loaded-pendulum-id","timestamp":ts,"commit":commit(),
    "key_metrics":{"omega_d_radps":round(wn,3) if wn else None,"omega_n_radps":round(wn_undamped,3) if wn_undamped else None,
        "T_osc_s":round(T_osc,3) if T_osc else None,"zeta":round(zeta,3) if zeta is not None else None,
        "n_peaks":len(pos),"equilibrium_deg":round(fp0,1)}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/  (analiz/dogrulama icin raw/decay.csv MATLAB'a)")
