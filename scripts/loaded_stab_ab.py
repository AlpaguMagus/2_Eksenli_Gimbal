#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded STAB A/B — pasif gravite vs aktif kontrol AYIRT-EDICI (confound'suz).
Faz A (KAPALI/coast): motor STOP -> Hi-Z; sen HIZLI flick. FP savrulmasi = open-loop baseline.
Faz B (ACIK/STAB): STABDIR2:1 (yuklu polarite k_kin=-1.04) + gravite-FF + modest gyro (k_ff~3);
AYNI HIZLI flick. FP coast'a gore daha az savrulursa = AKTIF kontrol (pasif gravite degil).
Reddi = 1 - FP_p2p(ACIK)/FP_p2p(KAPALI)  (turetilen theta_base'e degil, GERCEK open-loop'a kiyas).
HIZLI flick sart: yavas bozucuda sarkac pasif yetisir (ayrim yok). Cikti: artifacts/3/loaded_stab_ab/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime, sys
PORT, BAUD = "/dev/ttyACM0", 115200
PHASE = 9.0     # her faz sn
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
FPr=re.compile(r"FP:(-?[\d.]+)")

def run_phase(label, dur, ping):
    print(f"\n>>> {label}: {dur:.0f} sn — HIZLI flick (3-4 kez)"); ser.reset_input_buffer()
    t0=time.time(); lp=0; fps=[]; ts=[]
    while time.time()-t0<dur:
        if ping and time.time()-lp>0.2: send("PING"); lp=time.time()
        ln=ser.readline().decode("utf-8","replace").strip()
        m=FPr.search(ln) if ln.startswith("T_US") else None
        if m: fps.append(float(m.group(1))); ts.append(time.time()-t0)
    p2p=(max(fps)-min(fps)) if fps else 0.0
    print(f"    FP min={min(fps):+.1f} max={max(fps):+.1f}  tepe-tepe={p2p:.1f}")
    return fps, ts, p2p

print("=== Loaded STAB A/B (pasif vs aktif) ===")
# FAZ A — KAPALI (coast, Hi-Z)
send("STOP"); send("STALLEN:0"); time.sleep(0.5)
fpA,tA,p2pA = run_phase("FAZ A — KONTROLCU KAPALI (coast)", PHASE, ping=False)
# FAZ B — ACIK: STAB polarite (STABDIR2:1, yuklu k_kin=-1.04) + gravite-FF + modest gyro; argv: k_ff
KFF = float(sys.argv[1]) if len(sys.argv)>1 else 3.0   # gyro-FF kazanci (ampirik-guvenli ~3); integral YOK (ilk rung)
print(f"\n[FAZ B config: STABDIR2=1 (yuklu polarite) + gravite-FF (LFF) + KFF2={KFF} (gyro)]")
send("LFFG2:0.21"); send("LFF2:1"); send("STABDIR2:1"); send(f"KFF2:{KFF}")
send("MODE2:STAB"); time.sleep(0.1)
fpB,tB,p2pB = run_phase("FAZ B — KONTROLCU ACIK (STAB)", PHASE, ping=True)
send("STOP"); ser.close()

rej = (1 - p2pB/p2pA) if p2pA>1e-6 else 0.0
PASS = (p2pA>=8.0) and (rej>=0.40)   # KAPALI'da anlamli savrulma OLMALI (olu-sistem yanlis-PASS vermesin) + ACIK >=40% kessin
print("\n"+"="*54)
print(f"  KAPALI FP tepe-tepe = {p2pA:.1f}   (open-loop savrulma)")
print(f"  ACIK   FP tepe-tepe = {p2pB:.1f}   (kontrolcu ile)")
print(f"  REDDI = 1 - {p2pB:.1f}/{p2pA:.1f} = {100*rej:.0f}%")
print(f"  >>> {'PASS (aktif kontrol KANITLI)' if PASS else 'FAIL veya belirsiz — KAPALI savrulma yetersizse flick daha HIZLI/BUYUK'}")
print("="*54)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_stab_ab/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/ab.csv","w",newline="")); w.writerow(["phase","t","fp"])
for t,f in zip(tA,fpA): w.writerow(["OFF",f"{t:.3f}",f"{f:.2f}"])
for t,f in zip(tB,fpB): w.writerow(["ON",f"{t:.3f}",f"{f:.2f}"])
json.dump({"test_id":"5.loaded-stab-ab","timestamp":ts,"commit":commit(),"status":"PASS" if PASS else "FAIL",
    "key_metrics":{"fp_p2p_off":round(p2pA,1),"fp_p2p_on":round(p2pB,1),"rejection":round(rej,3),"k_ff":KFF}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
open(f"{d}/summary.md","w").write(f"""# 3.loaded-stab-ab — Pasif gravite vs aktif kontrol (ayirt-edici)
- **Tarih:** {ts} · **Commit:** {commit()} · **Durum:** {'PASS' if PASS else 'FAIL'}
- **Yontem:** AYNI hizli flick, KAPALI(coast) vs ACIK(STAB k_ff={KFF}, STABDIR2:1+gravite-FF). Reddi=1-p2p_ON/p2p_OFF (gercek open-loop kiyas).
| Faz | FP tepe-tepe |
|---|---|
| KAPALI (coast) | {p2pA:.1f}° |
| ACIK (STAB) | {p2pB:.1f}° |
| **Reddi** | **{100*rej:.0f}%** |
{'PASS — KAPALI savrulma anlamli + ACIK >=40% bastirdi => AKTIF kontrol kanitli (pasif gravite degil).' if PASS else 'FAIL/belirsiz — KAPALI savrulma <8 ise flick yavas/kucuk; tekrarla.'}
## Ureten: `scripts/loaded_stab_ab.py`
""")
print(f"Artifact: {d}/")
