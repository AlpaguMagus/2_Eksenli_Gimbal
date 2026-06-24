#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded STAB — ASILI-NOKTADAN UZAK (level) tutma + base bozucu. Gravite TAKLIT EDEMEZ.
Sarkac asili dengesi FP~+13 (theta_out=0). Hedef: stand'i FP~0 (LEVEL) tut = ~13 off-hanging.
Akis: (1) POS ile theta_out~+18'e sur -> FP~0 (level) oturt; (2) MODE2:STAB (FP0~0 yakalanir)
+ gravite-FF + gyro(+ isaret); (3) sen base'i yavasca egip-tut; FP IMU'da level kaliyor mu?
YARGI = FP IZI (metrik degil): level'da kalir (STAB calisir) vs sarkiga (+13) duser (gravite/yok).
Guvenlik: FP |.|>50 olursa script STOP'lar. Cikti: artifacts/5/loaded_stab_offhang/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC=360.0/466.0
KFF=0.0          # ilk test: GYRO YOK (saf cascade STAB izole et); sonra gyro eklenir
THETA_LEVEL=18   # theta_out ~+18 -> FP~0 (POS verisinden interpolasyon)
DUR=12.0
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
FPr=re.compile(r"FP:(-?[\d.]+)"); ECr=re.compile(r"EC2:(-?\d+)"); Ur=re.compile(r"U2:(-?[\d.]+)")

print("=== Loaded STAB off-hanging (level) tutma + base bozucu ===")
# (1) POS ile level'a oturt
send("STOP"); send("STALLEN:0"); time.sleep(0.4)
send("LFFG2:0.21"); send("LFF2:1"); send("MODE2:POS"); send(f"POS_DEG2:{THETA_LEVEL}")
print(f">>> motor stand'i LEVEL'a (FP~0) goturuyor... (2.5 sn)")
t0=time.time(); lp=0; pos_th=0; pos_fp=0
while time.time()-t0<2.5:
    if time.time()-lp>0.2: send("PING"); lp=time.time()
    ln=ser.readline().decode("utf-8","replace").strip()
    if ln.startswith("T_US"):
        me=ECr.search(ln); mf=FPr.search(ln)
        if me: pos_th=int(me.group(1))*LP_DPC
        if mf: pos_fp=float(mf.group(1))
print(f"    POS-sonu: theta_out={pos_th:+.1f}° (hedef {THETA_LEVEL})  FP={pos_fp:+.1f}° (level~0 olmali)")
# (2) STAB'a gec (FP0~0 yakalanir)
send("STABDIR2:1"); send(f"KFF2:{KFF}"); send("MODE2:STAB")
print(f">>> STAB AKTIF (level tutuyor). {DUR:.0f} sn: base'i YAVASCA egip-tut (birkac kez). FP'ye bak!")
ser.reset_input_buffer()
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
    if abs(fp)>50 and not stopped:   # guvenlik
        send("STOP"); stopped=True; print("  !! FP>50 GUVENLIK STOP")
    if time.time()-lpr>0.6:
        lpr=time.time(); print(f"   t={T[-1]:4.1f}  FP={fp:+6.1f} (level hedef 0)  theta_out={th:+5.1f}  duty={u:+.3f}")
send("MODE2:POS"); send("POS_DEG2:0"); time.sleep(1.0); send("STOP"); ser.close()

# YARGI: FP IZI — level'da mi kaldi (|FP| kucuk) yoksa sarkiga (~+13) mi kaydi
import statistics
fp_mean=statistics.mean(FP); fp_std=statistics.stdev(FP) if len(FP)>1 else 0
fp_absmax=max(abs(x) for x in FP)
hang=13.0   # asili denge FP
# STAB calisirsa FP ~0 civari (std kucuk, ortalama 0'a yakin, sarkiga kaymadi)
held_level = abs(fp_mean)<7 and fp_absmax<25
print("\n"+"="*56)
print(f"  FP ortalama={fp_mean:+.1f}  std={fp_std:.1f}  |FP|max={fp_absmax:.1f}  (hedef level=0; sarkik=+{hang:.0f})")
print(f"  >>> {'LEVEL TUTTU — base egilirken stand level kaldi (STAB calisiyor, gravite degil)' if held_level else 'LEVEL TUTAMADI — sarkiga kaydi veya savruldu (FP izi: STAB yetersiz)'}")
print("  (Asil yargi SENIN gozun: stand base eğilirken level kaldi mi, sarktı mı?)")
print("="*56)
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_stab_offhang/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/offhang.csv","w",newline="")); w.writerow(["t","fp","theta_out","u2"])
for t,fp,th,u in zip(T,FP,TH,U): w.writerow([f"{t:.3f}",f"{fp:.2f}",f"{th:.2f}",f"{u:.3f}"])
json.dump({"test_id":"5.loaded-stab-offhang","timestamp":ts,"commit":commit(),
    "key_metrics":{"fp_mean":round(fp_mean,1),"fp_std":round(fp_std,1),"fp_absmax":round(fp_absmax,1),
        "held_level":held_level,"k_ff":KFF,"hang_eq_deg":hang}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/")
