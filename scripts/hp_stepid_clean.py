#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP step-ID TEMİZ — DUTYR (rampasız) ile gerçek sürücü+motor τ'su.

Önceki rampasız.py firmware rampasıyla sabote oldu (kick yenmiş → motor base'de stall →
0→stiction-startup ölçtü). Bu sürüm DUTYR (SetDutySigned, rampa YOK) kullanır:
  [1] DUTYR:0.48 kick (2s, ETKİLİ) → motor spin-up
  [2] DUTYR:0.40 base → settle + base ω kaydı (motor RUNNING olduğunu doğrula)
  [3] DUTYR:0.50 STEP (Δ0.10) → τ63 ölç (running base'den temiz adım, stiction yok)

Host-time (T_US wrap yok). τ63 < 100ms → HW-039 hızlı (450ms ramp artefaktıydı).
⚠ FİZİKSEL — HP motor HW-039'da, mil serbest. Akım limiti yok → kısa (~6s sürüş, motor döner ~1A).
Çıktı: artifacts/3/hp_stepid_clean/<ts>/
"""
import serial, time, sys, os, json, subprocess, datetime, re

PORT, BAUD = "/dev/ttyACM0", 115200
KICK, KICK_S = 0.48, 2.0
BASE, TARGET = 0.40, 0.50
SETTLE_S, REC_S = 1.5, 2.0
WIN = 0.03   # ω penceresi (s)

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"

try:
    ser = serial.Serial(PORT, BAUD, timeout=0.02)
except Exception as e:
    print(f"[ERROR] {PORT}: {e}"); sys.exit(1)
time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()

def collect(secs):
    rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0 < secs:
        if time.time()-lp > 0.12: send("PING"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            d=dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
            if "EC" in d: rows.append((time.time()-t0, int(d["EC"])))
    return rows

def omega(rows, win=WIN):
    out=[]; i=0
    while i < len(rows)-1:
        j=i+1
        while j < len(rows) and rows[j][0]-rows[i][0] < win: j+=1
        if j>=len(rows): break
        dt=rows[j][0]-rows[i][0]
        if dt>0: out.append((rows[j][0], (rows[j][1]-rows[i][1])/dt))
        i=j
    return out

def steady(rows, frac=0.35):
    w=omega(rows)
    if len(w)<4: return None
    n=max(2,int(len(w)*frac)); return sum(x[1] for x in w[-n:])/n

print("="*60); print("HP step-ID TEMİZ (DUTYR rampasız)"); print("="*60)
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2)
send("STALLEN:0"); time.sleep(0.2); ser.reset_input_buffer()

print(f"[1] kick DUTYR:{KICK} → spin-up ({KICK_S}s)...")
send(f"DUTYR:{KICK}"); t=time.time()
while time.time()-t < KICK_S: send("PING"); send(f"DUTYR:{KICK}"); time.sleep(0.1)

print(f"[2] base DUTYR:{BASE} → settle ({SETTLE_S}s)...")
send(f"DUTYR:{BASE}"); base_rows=collect(SETTLE_S)

print(f"[3] STEP DUTYR:{TARGET} (Δ{TARGET-BASE:.2f}) → record ({REC_S}s)...")
send(f"DUTYR:{TARGET}"); step_rows=collect(REC_S)
send("DUTYR:0.0"); time.sleep(0.1); send("STOP")

base_w=steady(base_rows); new_w=steady(step_rows)
ws=omega(step_rows); tau=None
if base_w and new_w and ws:
    dw=new_w-base_w
    if abs(dw)>1e-6:
        tgt=base_w+0.632*dw
        for tt,ww in ws:
            if (dw>0 and ww>=tgt) or (dw<0 and ww<=tgt): tau=tt; break

ms=lambda x:f"{x*1000:.0f}ms" if x else "?"
running = (base_w is not None and base_w > 400)
print("\n"+"="*60)
if base_w is not None:
    print(f"  base ω (DUTYR:{BASE}) = {base_w:.0f} cnt/s  {'✓ RUNNING' if running else '✗ STALL — base düşük, 0.45 dene'}")
if running and tau and new_w:
    print(f"  STEP {BASE}→{TARGET}: τ63 = {ms(tau)}   (ω {base_w:.0f}→{new_w:.0f} cnt/s)")
    if tau<0.10:   print("  → HÜKÜM: τ KÜÇÜK → HW-039 HIZLI; 450ms firmware-ramp artefaktıydı (DFR0601 hız için gereksiz).")
    elif tau<0.20: print("  → HÜKÜM: τ orta → sürücü makul; ramp büyük confound'du.")
    else:          print("  → HÜKÜM: τ BÜYÜK → sürücü/modül gerçekten yavaş (DFR0601 haklı).")
else:
    print("  → STEP ölçülemedi (base stall veya dropout). Aşağıdaki ham veriye bak.")
print("="*60)

# artifact
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/hp_stepid_clean/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
for nm,rs in [("base",base_rows),("step",step_rows)]:
    with open(f"{d}/raw/{nm}.csv","w") as f:
        f.write("t_s,ec\n"); [f.write(f"{r[0]:.5f},{r[1]}\n") for r in rs]
json.dump({"test_id":"3.HP-clean-DUTYR","timestamp":ts,"commit":commit(),
    "status":"PASS" if (running and tau) else "FAIL",
    "key_metrics":{"base_omega_cps":round(base_w,0) if base_w else None,
        "new_omega_cps":round(new_w,0) if new_w else None,
        "tau63_ms":round(tau*1000,1) if tau else None,"base_duty":BASE,"step_duty":TARGET}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
print(f"Artifact: {d}/")
ser.close()
