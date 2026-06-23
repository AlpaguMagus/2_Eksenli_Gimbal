#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LP step-ID — Kg (rad/s/duty) + tau63, iki yön. OMEGA2 (rad/s, firmware) doğrudan.

HP §12.13.5 rijit re-char'ın LP eşleniği. LP=Motor2/TB6612/9.7:1, eksen-1 (DUTY2/OMEGA2).
  [Kg]  çok-duty sweep [0.15..0.50] her yön → steady OMEGA2 → en-küçük-kareler ω=Kg·(duty-duty0)
  [tau] base 0.30 → step 0.50, OMEGA2 trajektoride %63.2 geçişi (5-nokta smooth)
Eski Aşama-1 LP modeli (K=53.89 rad/s/V, τ=60.5 ms) ile kıyas → not: K rad/s/V, Kg rad/s/duty (×12V≈).
⚠ FİZİKSEL, mil serbest, mengeneli. Çıktı: artifacts/3/lp_stepid/<ts>/
"""
import serial, time, sys, os, json, subprocess, datetime, re

PORT, BAUD = "/dev/ttyACM0", 115200
DUTIES = [0.15, 0.20, 0.25, 0.30, 0.40, 0.50]
KICK = 0.45

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"

ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
def stop(): send("DUTY2:0.0"); time.sleep(0.05); send("STOP")

def drive_collect(duty, secs):
    rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0 < secs:
        if time.time()-lp > 0.10: send(f"DUTY2:{duty}"); send("PING"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            d=dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
            if "OMEGA2" in d: rows.append((time.time()-t0, float(d["OMEGA2"])))
    return rows

def steady(rows, frac=0.5):
    if len(rows)<4: return None
    n=max(3,int(len(rows)*frac)); seg=[r[1] for r in rows[-n:]]
    return sum(seg)/len(seg)

def lsq(xs, ys):   # ω = m·duty + b  → Kg=m, duty0=-b/m
    n=len(xs); sx=sum(xs); sy=sum(ys); sxx=sum(x*x for x in xs); sxy=sum(x*y for x,y in zip(xs,ys))
    den=n*sxx-sx*sx
    if abs(den)<1e-12: return None,None
    m=(n*sxy-sx*sy)/den; b=(sy-m*sx)/n; return m,b

print("="*60); print(" LP step-ID — Kg + tau (OMEGA2 rad/s)"); print("="*60)
send("STOP"); time.sleep(0.3); send("MODE2:DUTY"); time.sleep(0.2); send("STALLEN:0"); time.sleep(0.2)

result={}
for sign, lab in [(+1,"FWD"), (-1,"REV")]:
    print(f"\n[{lab}] Kg sweep:")
    send(f"DUTY2:{sign*KICK}"); t=time.time()
    while time.time()-t<0.8: send(f"DUTY2:{sign*KICK}"); send("PING"); time.sleep(0.1)
    duty_pts=[]; om_pts=[]
    for du in DUTIES:
        rows=drive_collect(sign*du, 1.0); w=steady(rows)
        if w is not None: duty_pts.append(du); om_pts.append(abs(w))
        print(f"    duty={du:.2f}  ω={abs(w):.1f} rad/s" if w is not None else f"    duty={du:.2f}  ω=?")
    Kg, b = lsq(duty_pts, om_pts)
    duty0 = (-b/Kg) if (Kg and abs(Kg)>1e-9) else None
    # tau: base 0.30 → step 0.50
    print(f"[{lab}] tau (0.30→0.50 step):")
    base=drive_collect(sign*0.30, 1.3); base_w=steady(base)
    step=drive_collect(sign*0.50, 1.5)
    stop(); time.sleep(0.5)
    # smooth OMEGA2 trajectory (5-nokta MA), %63.2 geçişi
    sm=[]
    for i in range(len(step)):
        a=max(0,i-2); seg=[abs(step[k][1]) for k in range(a,min(len(step),i+3))]
        sm.append((step[i][0], sum(seg)/len(seg)))
    new_w=steady(step)
    tau=None
    if base_w and new_w:
        bw=abs(base_w); nw=abs(new_w); dw=nw-bw
        if abs(dw)>0.5:
            tgt=bw+0.632*dw
            for tt,ww in sm:
                if (dw>0 and ww>=tgt) or (dw<0 and ww<=tgt): tau=tt; break
    result[lab]={"Kg":Kg,"duty0":duty0,"tau_ms":(tau*1000 if tau else None),
                 "base_w":abs(base_w) if base_w else None,"new_w":abs(new_w) if new_w else None}
    print(f"    Kg={Kg:.1f} rad/s/duty  duty0(Coulomb)={duty0:.3f}  τ63={tau*1000:.0f}ms" if (Kg and tau) else f"    Kg={Kg}  duty0={duty0}  τ={tau}")
stop(); ser.close()

print("\n"+"="*60)
f,r=result.get("FWD",{}),result.get("REV",{})
print(f"  Kg   : fwd={f.get('Kg')} / rev={r.get('Kg')}  rad/s/duty")
print(f"  duty0: fwd={f.get('duty0')} / rev={r.get('duty0')}  (Coulomb ofset)")
print(f"  τ63  : fwd={f.get('tau_ms')} / rev={r.get('tau_ms')}  ms")
print(f"  (eski Aşama-1 LP: K=53.89 rad/s/V → ×12V≈647 rad/s/duty nominal; τ=60.5 ms)")
print("="*60)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/lp_stepid/{ts}"; os.makedirs(d,exist_ok=True)
def rnd(x,n=1): return round(x,n) if isinstance(x,(int,float)) else x
status="PASS" if (f.get("Kg") and f.get("tau_ms") and r.get("Kg")) else "PARTIAL"
json.dump({"test_id":"3.LP-stepid","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":{k:{kk:rnd(vv,3) for kk,vv in v.items()} for k,v in result.items()}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as fp:
    fp.write(f"""# 3.LP-stepid — Kg + tau, iki yön

- **Tarih:** {ts} · **Commit:** {commit()} · **Durum:** {status}
- **Hedef:** LP plant — Kg (rad/s/duty), Coulomb ofset, τ63; iki yön; eski Aşama-1 LP modeliyle kıyas.
- **Donanım:** LP Motor2/TB6612/9.7:1, mil serbest, mengeneli.

## Sonuç
| | Kg (rad/s/duty) | duty0 (Coulomb) | τ63 (ms) |
|---|---|---|---|
| **FWD** | {rnd(f.get('Kg'))} | {rnd(f.get('duty0'),3)} | {rnd(f.get('tau_ms'))} |
| **REV** | {rnd(r.get('Kg'))} | {rnd(r.get('duty0'),3)} | {rnd(r.get('tau_ms'))} |

## Kıyas
- Eski Aşama-1 LP: K=53.89 rad/s/V, τ=60.5 ms (×12V nominal ≈ 647 rad/s/duty).
- HP rijit §12.13.5: Kg~974/897, τ~72 ms, Coulomb 0.14/0.20 (asimetrik).
- LP dead-band (3.LP-deadband): breakaway ~0.05, simetrik, stiction yok.

## Üreten: `scripts/lp_stepid.py`
""")
print(f"Artifact: {d}/")
