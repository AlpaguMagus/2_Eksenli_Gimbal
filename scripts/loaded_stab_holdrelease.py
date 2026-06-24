#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded STAB hold-release GIMBAL demo — off-hanging'i SEN tanimla (mutlak-esleme yok).
Sen stand'i BELIRGIN off-hanging (yukari/yatay) elinle tut; STAB o aciyi yakalar (encoder
reset → giris=hold). Sen birakinca: stand o acida KALIRSA = aktif kontrol (gravite asiliya
cekerdi); DUSERSE = kontrol yok. Sonra base'i egince KALIRSA = stabilizasyon.
YARGI = SENIN GOZUN + FP izi (girise gore kaydi mi). Guvenlik: FP|.|>55 -> STOP.
Cikti: artifacts/5/loaded_stab_holdrelease/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC=360.0/466.0; DUR=13.0
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
FPr=re.compile(r"FP:(-?[\d.]+)"); ECr=re.compile(r"EC2:(-?\d+)"); Ur=re.compile(r"U2:(-?[\d.]+)")

print("=== Loaded STAB hold-release gimbal demo ===")
print(">>> Stand'i elinle BELIRGIN off-hanging tut (yukari/yatay). STAB simdi aciyi yakalayacak.")
send("STOP"); send("STALLEN:0"); time.sleep(0.6)
send("STABDIR2:1"); send("LFFG2:0.21"); send("LFF2:1"); send("KFF2:0")
ser.reset_input_buffer(); send("MODE2:STAB")
print(f">>> STAB AKTIF — acin YAKALANDI. ~2 sn say, sonra YAVASCA BIRAK. Tutuyor mu izle.")
print(f"    (sonra base'i egip-tut: stand acida kaliyor mu?)  {DUR:.0f} sn.")
t0=time.time(); lp=0; lpr=0; T=[]; FP=[]; TH=[]; U=[]; FP0=None; stopped=False
while time.time()-t0<DUR:
    if time.time()-lp>0.2: send("PING"); lp=time.time()
    ln=ser.readline().decode("utf-8","replace").strip()
    if not ln.startswith("T_US"): continue
    mf=FPr.search(ln); me=ECr.search(ln); mu=Ur.search(ln)
    if not mf: continue
    fp=float(mf.group(1)); th=int(me.group(1))*LP_DPC if me else 0; u=float(mu.group(1)) if mu else 0
    if FP0 is None: FP0=fp
    T.append(time.time()-t0); FP.append(fp); TH.append(th); U.append(u)
    if abs(fp)>80 and not stopped: send("STOP"); stopped=True; print("  !! FP>80 GUVENLIK STOP (kablo limiti)")
    if time.time()-lpr>0.7:
        lpr=time.time(); print(f"   t={T[-1]:4.1f}  FP={fp:+6.1f} (giris={FP0:+.0f})  sapma={fp-FP0:+5.1f}  theta_out={th:+5.1f}  duty={u:+.3f}")
send("STOP"); ser.close()
import statistics
dev=[f-FP0 for f in FP]; dmax=max(abs(x) for x in dev); dfin=dev[-1]
held = dmax<12   # girise gore <12 sapma = tuttu (gravite asiliya cekemedi)
print("\n"+"="*56)
print(f"  Giris(yakalanan) FP0={FP0:+.1f}°  son sapma={dfin:+.1f}  max sapma={dmax:.1f}")
print(f"  >>> {'TUTTU — off-hanging acida kaldi (AKTIF kontrol)' if held else 'DUSTU/savruldu — girise gore kaydi'}")
print("  (ASIL yargi SENIN gozun: birakinca acida kaldi mi, asiliya mi dustu? base egilince kaldi mi?)")
print("="*56)
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_stab_holdrelease/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/hr.csv","w",newline="")); w.writerow(["t","fp","theta_out","u2"])
for t,fp,th,u in zip(T,FP,TH,U): w.writerow([f"{t:.3f}",f"{fp:.2f}",f"{th:.2f}",f"{u:.3f}"])
json.dump({"test_id":"5.loaded-stab-holdrelease","timestamp":ts,"commit":commit(),
    "key_metrics":{"fp0":round(FP0,1),"dev_final":round(dfin,1),"dev_max":round(dmax,1),"held":held}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/")
