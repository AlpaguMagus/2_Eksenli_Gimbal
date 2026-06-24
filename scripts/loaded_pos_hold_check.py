#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded AKTIF POZISYON HOLD check (Asama 5) — gravite'nin TAKLIT EDEMEYECEGI test.
MODE2:POS + gravite-FF; motor cikis milini komut acilarina surer/TUTAR. Gravite stand'i
sarkik dengeye ceker; motor onu UZAK bir acida tutabiliyorsa = AKTIF KONTROL KANITI (gravite yapamaz).
Sen sadece IZLE (motor kendi gider). Her komutta: theta_out komuta ulasti+TUTTU mu, duty surdu mu.
Komut dizisi (cikis mili derece): 0 -> +25 -> -25 -> +20 -> 0.  Sinirli (+-25, +-90 kablo guvenli).
Cikti: artifacts/5/loaded_pos_hold/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime, atexit
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC=360.0/466.0
SEQ=[0, 25, -25, 20, 0]; HOLD=3.5
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
ECr=re.compile(r"EC2:(-?\d+)"); FPr=re.compile(r"FP:(-?[\d.]+)"); Ur=re.compile(r"U2:(-?[\d.]+)")

print("=== Loaded AKTIF pozisyon-hold check (IZLE — motor kendi gider) ===")
send("STOP"); send("STALLEN2:0"); time.sleep(0.4)
send("LFFG2:0.21"); send("LFF2:1"); send("MODE2:POS"); time.sleep(0.2); ser.reset_input_buffer()
rows=[]; res=[]
for tgt in SEQ:
    send(f"POS_DEG2:{tgt}")
    t0=time.time(); lp=0; seg=[]
    while time.time()-t0<HOLD:
        if time.time()-lp>0.2: send("PING"); lp=time.time()
        ln=ser.readline().decode("utf-8","replace").strip()
        if not ln.startswith("T_US"): continue
        me=ECr.search(ln); mf=FPr.search(ln); mu=Ur.search(ln)
        if not me: continue
        th=int(me.group(1))*LP_DPC; fp=float(mf.group(1)) if mf else 0.0; u=float(mu.group(1)) if mu else 0.0
        seg.append((time.time()-t0,th,fp,u)); rows.append((tgt,)+seg[-1])
    ss=[s for s in seg if s[0]>HOLD-1.2]   # son 1.2s (oturmus)
    th_ss=sum(s[1] for s in ss)/len(ss) if ss else 0; fp_ss=sum(s[2] for s in ss)/len(ss) if ss else 0
    u_ss=sum(abs(s[3]) for s in ss)/len(ss) if ss else 0
    err=th_ss-tgt
    print(f"  komut θ_out={tgt:+4d}° -> ulasti={th_ss:+6.1f}° (hata {err:+5.1f})  FP={fp_ss:+6.1f}°  |duty|={u_ss:.3f}")
    res.append((tgt,th_ss,fp_ss,u_ss,err))
send("POS_DEG2:0"); time.sleep(1.0); send("STOP"); ser.close()

# PASS: komutlara |hata|<6 (tuttu) + uzak-acilarda duty sustained (gravite'ye karsi is)
far=[r for r in res if abs(r[0])>=20]
held=all(abs(r[4])<6 for r in res)
working=all(r[3]>0.02 for r in far)   # uzak acida duty != 0 -> aktif
PASS=held and working
print("\n"+"="*56)
print(f"  Komutlara TUTTU (|hata|<6): {'EVET' if held else 'HAYIR (sarkti/droop)'}")
print(f"  Uzak acida motor IS yapti (duty>0): {'EVET' if working else 'HAYIR'}")
print(f"  >>> {'PASS — AKTIF kontrol KANITLI (gravite uzak-aciyi tutamaz)' if PASS else 'FAIL — gravite-FF/cascade yetersiz, tutamadi'}")
print("="*56)
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_pos_hold/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/hold.csv","w",newline="")); w.writerow(["tgt","t","theta_out","fp","u2"])
for r in rows: w.writerow([r[0],f"{r[1]:.3f}",f"{r[2]:.2f}",f"{r[3]:.2f}",f"{r[4]:.3f}"])
json.dump({"test_id":"5.loaded-pos-hold","timestamp":ts,"commit":commit(),"status":"PASS" if PASS else "FAIL",
    "results":[{"tgt":t,"theta_out":round(th,1),"fp":round(fp,1),"duty":round(u,3),"err":round(e,1)} for t,th,fp,u,e in res]},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 5.loaded-pos-hold — Yuklu AKTIF pozisyon-hold check

- **Test ID:** 5.loaded-pos-hold
- **Tarih:** {ts}
- **Commit:** {commit()}
- **Hedef:** Yuklu LP ekseni komut acilarini gravite'ye karsi tutabiliyor mu (AKTIF kontrol kaniti) olcer.
- **Komut:** `python3 scripts/loaded_pos_hold_check.py`

## Sonuc (sayisal)
| Komut θ_out (°) | Ulasti (°) | Hata (°) | |duty| |
|---|---|---|---|
""")
    for t,th,fp,u,e in res:
        f.write(f"| {t:+d} | {th:+.1f} | {e:+.1f} | {u:.3f} |\n")
    f.write(f"""
- Komutlara TUTTU (|hata|<6): {'EVET' if held else 'HAYIR (sarkti/droop)'}
- Uzak acida motor IS yapti (duty>0): {'EVET' if working else 'HAYIR'}

## Durum / gerekce
{'PASS' if PASS else 'FAIL'} — {'AKTIF kontrol kanitli: motor uzak komut acilarini gravite-FF + cascade ile tuttu (gravite uzak-aciyi tutamaz).' if PASS else 'Gravite-FF/cascade yetersiz: komut acilari tutulamadi (sarkti) veya uzak acida duty sustained olmadi.'}

## Artifacts
- raw/hold.csv
""")
print(f"Artifact: {d}/")
