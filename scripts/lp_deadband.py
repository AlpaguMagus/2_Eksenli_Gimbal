#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LP dead-band — STATİK kopma vs KİNETİK dropout (iki yön, ≤0.5 cap).

HP §12.13.5 rijit re-char'ın LP eşleniği. LP = Motor2/TB6612/9.7:1, eksen-1 (EC2, DUTY2).
  • STATİK kopma  : dinlenmeden yukarı step → ilk hareket duty'si (breakaway, stiction)
  • KİNETİK dropout: kick ile döndür → aşağı ramp → hareketin durduğu duty (Coulomb/kinetik)
Stiction ≫ kinetik = stick-slip; cascade dead-band telafisi + FF için kritik.
⚠ FİZİKSEL, mil serbest, mengeneli. Çıktı: artifacts/3/lp_deadband/<ts>/
"""
import serial, time, os, json, subprocess, datetime, re

PORT, BAUD = "/dev/ttyACM0", 115200
DUTY_CAP = 0.50
MOVE_THRESH = 200   # cnt/s

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
def clamp(d): return max(-DUTY_CAP, min(DUTY_CAP, d))

ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
def stop(): send("DUTY2:0.0"); time.sleep(0.05); send("STOP")

def omega(duty, secs):
    duty=clamp(duty); rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0 < secs:
        if time.time()-lp > 0.10: send("PING"); send(f"DUTY2:{duty}"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            d=dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
            if "EC2" in d: rows.append((time.time()-t0,int(d["EC2"])))
    if len(rows)<4: return None
    seg=rows[len(rows)//2:]; dt=seg[-1][0]-seg[0][0]
    return (seg[-1][1]-seg[0][1])/dt if dt>1e-6 else None

print("="*60); print(" LP DEAD-BAND — statik kopma vs kinetik dropout"); print("="*60)
send("STOP"); time.sleep(0.3); send("MODE2:DUTY"); time.sleep(0.2); send("STALLEN:0"); time.sleep(0.2)
res={"static":{}, "kinetic":{}}

def static_breakaway(sign, lab):
    print(f"\n[STATİK] {lab} — dinlenmeden yukarı step:")
    vb=None
    for k in range(8,35):            # 0.08 .. 0.34 (LP breakaway HP'den düşük olabilir)
        d=sign*(0.01*k); w=omega(d,0.55)
        mv = w is not None and abs(w)>MOVE_THRESH
        print(f"    duty={d:+.2f}  ω={('%+.0f'%w) if w is not None else '?':>7}  {'← KOPMA' if mv else ''}")
        stop(); time.sleep(0.35)
        if mv: vb=abs(d); break
    return vb

def kinetic_dropout(sign, lab):
    print(f"\n[KİNETİK] {lab} — kick sonrası aşağı ramp:")
    send(f"DUTY2:{clamp(sign*0.45)}"); t=time.time()
    while time.time()-t<1.2: send("PING"); send(f"DUTY2:{clamp(sign*0.45)}"); time.sleep(0.1)
    vd=None
    for k in range(30,3,-2):          # 0.30 → 0.04 aşağı
        d=sign*(0.01*k); w=omega(d,0.6)
        mv = w is not None and abs(w)>MOVE_THRESH
        print(f"    duty={d:+.2f}  ω={('%+.0f'%w) if w is not None else '?':>7}  {'döner' if mv else '← DURDU'}")
        if not mv: vd=abs(sign*(0.01*(k+2))); break   # bir önceki hâlâ dönüyordu
    stop(); time.sleep(0.4)
    return vd

res["static"]["fwd"]=static_breakaway(+1,"FWD")
res["static"]["rev"]=static_breakaway(-1,"REV")
res["kinetic"]["fwd"]=kinetic_dropout(+1,"FWD")
res["kinetic"]["rev"]=kinetic_dropout(-1,"REV")
stop()

print("\n"+"="*60)
sf,sr=res["static"]["fwd"],res["static"]["rev"]
kf,kr=res["kinetic"]["fwd"],res["kinetic"]["rev"]
print(f"  STATİK kopma : fwd={sf}  rev={sr}")
print(f"  KİNETİK drop : fwd={kf}  rev={kr}")
if sf and kf: print(f"  → stiction/kinetik oranı fwd ≈ {sf/kf:.1f}×  ({'STICK-SLIP riski' if sf/kf>1.8 else 'makul'})")
print("="*60)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/lp_deadband/{ts}"; os.makedirs(d,exist_ok=True)
status="PASS" if (sf and sr and kf and kr) else "PARTIAL"
json.dump({"test_id":"3.LP-deadband","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":{"static_fwd":sf,"static_rev":sr,"kinetic_fwd":kf,"kinetic_rev":kr,
        "stiction_ratio_fwd":round(sf/kf,2) if (sf and kf) else None}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 3.LP-deadband — statik kopma vs kinetik dropout

- **Tarih:** {ts} · **Commit:** {commit()} · **Durum:** {status}
- **Hedef:** LP dead-band'ı ayır — statik kopma (breakaway/stiction) vs kinetik dropout (Coulomb). Eski Aşama-1 LP modeliyle kıyas + cascade dead-band telafisi.
- **Donanım:** LP Motor2/TB6612/9.7:1, mil serbest, mengeneli, duty cap {DUTY_CAP}.

## Sonuç
| | fwd | rev |
|---|---|---|
| **Statik kopma** (breakaway) | {sf} | {sr} |
| **Kinetik dropout** (sustain min) | {kf} | {kr} |
| stiction/kinetik oranı | {('%.1f×'%(sf/kf)) if (sf and kf) else '?'} | {('%.1f×'%(sr/kr)) if (sr and kr) else '?'} |

## Yorum
Statik ≫ kinetik → stick-slip eğilimi. HP rijit (§12.13.5: statik 0.22/0.25, kinetik 0.14/0.20) ile kıyasla.

## Üreten: `scripts/lp_deadband.py`
""")
print(f"Artifact: {d}/")
ser.close()
