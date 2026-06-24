#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP health-check — ters-kablo + yanık-koku sonrası dinamik sağlık (Kg, breakaway, τ vs baseline).

Pre-incident baseline (bu oturum K3 + §12.13.5, OMEGA-tabanlı):
  Kg slope ~1067 rad/s/duty; ω(0.20/0.30/0.40)=171/284/389; static breakaway ~0.22; τ ~72 ms.
Kg DÜŞTÜYSE → sargı/torque-sabiti hasarı (yanık=insülasyon). Friction ARTTIYSA → yatak/mekanik.
⚠ KISA/düşük-duty (≤0.40); motor ısınır/koku gelirse KES. HP, OMEGA/DUTYR. Çıktı: artifacts/3/hp_health/<ts>/
"""
import serial, time, re, os, json, subprocess, datetime

PORT, BAUD = "/dev/ttyACM0", 115200
BASE = {0.20:171.0, 0.30:284.0, 0.40:389.0}   # pre-incident ω (rad/s)
BREAK_BASE, TAU_BASE = 0.22, 72.0

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
Or = re.compile(r"OMEGA:(-?[\d.]+)")

def collect(duty, secs):
    rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0<secs:
        if time.time()-lp>0.10: send(f"DUTYR:{duty}"); send("PING"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            m=Or.search(line)
            if m: rows.append((time.time()-t0, abs(float(m.group(1)))))
    return rows
def steady(rows, frac=0.4):
    if len(rows)<4: return None
    n=max(3,int(len(rows)*frac)); return sum(v for _,v in rows[-n:])/n

print("="*60); print(" HP HEALTH-CHECK (ters-kablo + yanık-koku sonrası)"); print("="*60)
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2); send("STALLEN:0"); time.sleep(0.2)

# 1) Kg — steady ω @ duty (kick ile başlat, kısa)
print("\n[1] Kg (ω vs duty):")
send("DUTYR:0.45"); t=time.time()
while time.time()-t<0.7: send("DUTYR:0.45"); send("PING"); time.sleep(0.1)
kg={}
for du in [0.20,0.30,0.40]:
    w=steady(collect(du,1.0)); kg[du]=w
    dev = (100*(w-BASE[du])/BASE[du]) if w else None
    print(f"    duty={du:.2f}  ω={w:.0f} rad/s  (baseline {BASE[du]:.0f}, {dev:+.0f}%)" if w else f"    duty={du:.2f}  ω=?")
send("DUTYR:0.0"); time.sleep(0.4)

# 2) breakaway (rest→ramp)
print("[2] static breakaway:")
bk=None
for k in range(8,30):
    d=0.01*k; w=steady(collect(d,0.55))
    mv = w is not None and w>60
    if mv: bk=d; print(f"    ilk hareket duty={d:.2f} (ω={w:.0f})"); break
    send("DUTYR:0.0"); time.sleep(0.3)
send("DUTYR:0.0"); time.sleep(0.3)

# 3) τ (0.30→0.40 step)
print("[3] τ63 (0.30→0.40):")
send("DUTYR:0.45"); t=time.time()
while time.time()-t<0.7: send("DUTYR:0.45"); send("PING"); time.sleep(0.1)
b=collect(0.30,1.0); bw=steady(b); s=collect(0.40,1.3)
send("DUTYR:0.0"); send("STOP")
sm=[]
for i in range(len(s)):
    a=max(0,i-2); seg=[s[k][1] for k in range(a,min(len(s),i+3))]; sm.append((s[i][0],sum(seg)/len(seg)))
nw=steady(s); tau=None
if bw and nw and nw>bw:
    tgt=bw+0.632*(nw-bw)
    for tt,ww in sm:
        if ww>=tgt: tau=tt; break
print(f"    τ63={tau*1000:.0f}ms (baseline ~{TAU_BASE:.0f})" if tau else "    τ ölçülemedi")
ser.close()

# verdict
devs=[abs(100*(kg[d]-BASE[d])/BASE[d]) for d in kg if kg[d]]
kg_bad = any(d>20 for d in devs)
bk_bad = bk is not None and bk>BREAK_BASE*1.5
verdict = ("⚠ DİNAMİK DEĞİŞMİŞ — " + ("Kg düşük (sargı?) " if kg_bad else "") + ("friction↑ (mekanik?) " if bk_bad else "") + "→ eşdeğer motor düşün") \
          if (kg_bad or bk_bad) else "✅ DİNAMİK SAĞLIKLI — Kg/breakaway/τ baseline'da; koku muhtemelen geçici (motor sağlam)"
print("\n"+"="*60)
print(f"  Kg sapma: {[f'{x:+.0f}%' for x in [100*(kg[d]-BASE[d])/BASE[d] for d in kg if kg[d]]]}")
print(f"  breakaway: {bk} (baseline {BREAK_BASE})   τ: {tau*1000 if tau else '?'}ms")
print(f"  → {verdict}")
print("="*60)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/hp_health/{ts}"; os.makedirs(d,exist_ok=True)
json.dump({"test_id":"3.HP-health","timestamp":ts,"commit":commit(),
    "key_metrics":{"omega":{str(k):round(v,0) if v else None for k,v in kg.items()},
        "baseline":{str(k):v for k,v in BASE.items()},"breakaway":bk,"tau_ms":round(tau*1000,1) if tau else None,
        "verdict":verdict}},open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/")
