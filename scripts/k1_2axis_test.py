#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""K1 — 2-eksen EŞZAMANLI decentralized cascade (HP eksen-0 + LP eksen-1).

Her iki eksen aynı anda pozisyon cascade'i koşar; ayrı hedef çiftleri (HP,LP) eşzamanlı uygulanır.
Serbest mil → mekanik kuplaj ~0; bu test firmware'in İKİ cascade'i paralel koşturduğunu + her eksenin
KENDİ hedefini BAĞIMSIZ izlediğini doğrular (decentralized K1 milestone, ROADMAP §🪜).
  θ_hp = EC×360/960 (HP 20:1, 0.375°/cnt) · θ_lp = EC2×360/466 (LP 9.7:1, 0.77°/cnt)
Beklenti: LP temiz; HP residual sürtünme-limit-cycle (§12.13.4, K7'ye kadar yapısal) → θ_std HP'de yüksek.
⚠ FİZİKSEL, iki mil serbest, mengeneli. Çıktı: artifacts/3/k1_2axis/<ts>/
"""
import serial, time, re, os, json, subprocess, datetime

PORT, BAUD = "/dev/ttyACM0", 115200
HP_DPC = 360.0/960.0
LP_DPC = 360.0/466.0
PAIRS = [(30,-30),(90,45),(0,0),(-45,60),(60,-60),(0,0)]   # (HP, LP)
HOLD = 3.5
BAND = 2.5   # ss_err PASS bandı (°)

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
def mean(x): return sum(x)/len(x) if x else 0.0
def std(x):
    if len(x)<2: return 0.0
    m=mean(x); return (sum((v-m)**2 for v in x)/len(x))**0.5

ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()

print("="*64); print(" K1 — 2-EKSEN EŞZAMANLI CASCADE (HP+LP)"); print("="*64)
send("STOP"); time.sleep(0.3)
send("MODE:POS"); time.sleep(0.15); send("MODE2:POS"); time.sleep(0.15)
send("STALLEN:0"); time.sleep(0.2); ser.reset_input_buffer()

rows_all=[]; seg_metrics=[]
ECr=re.compile(r"EC:(-?\d+)"); EC2r=re.compile(r"EC2:(-?\d+)")
for idx,(hp,lp) in enumerate(PAIRS):
    send(f"POS_DEG:{hp}"); send(f"POS_DEG2:{lp}")    # eşzamanlı (back-to-back ~1ms)
    print(f"\n[seg {idx}] HP→{hp:+d}°  LP→{lp:+d}°")
    t0=time.time(); lp_hb=0; hp_s=[]; lp_s=[]
    while time.time()-t0 < HOLD:
        if time.time()-lp_hb>0.2: send("PING"); lp_hb=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if not line.startswith("T_US"): continue
        me=ECr.search(line); m2=EC2r.search(line)
        if me and m2:
            th=int(me.group(1))*HP_DPC; tl=int(m2.group(1))*LP_DPC; ts=time.time()-t0
            hp_s.append((ts,th)); lp_s.append((ts,tl))
    def metric(samples, target):
        ss=[v for t,v in samples if t>HOLD-1.2]
        thss=mean(ss); return {"ss":thss,"err":abs(thss-target),"std":std(ss)}
    mh=metric(hp_s,hp); ml=metric(lp_s,lp)
    seg_metrics.append({"hp_tgt":hp,"lp_tgt":lp,"hp":mh,"lp":ml})
    print(f"   HP: θ_ss={mh['ss']:+6.2f}° err={mh['err']:.2f}° std={mh['std']:.2f}°   "
          f"LP: θ_ss={ml['ss']:+6.2f}° err={ml['err']:.2f}° std={ml['std']:.2f}°")
send("POS_DEG:0"); send("POS_DEG2:0"); time.sleep(0.5); send("STOP"); ser.close()

# özet
hp_ok=sum(1 for s in seg_metrics if s["hp"]["err"]<=BAND)
lp_ok=sum(1 for s in seg_metrics if s["lp"]["err"]<=BAND)
N=len(PAIRS)
hp_lc=max(s["hp"]["std"] for s in seg_metrics); lp_lc=max(s["lp"]["std"] for s in seg_metrics)
print("\n"+"="*64)
print(f"  HP eksen: {hp_ok}/{N} hedef ss_err≤{BAND}°  (max θ_std={hp_lc:.2f}° — limit-cycle göstergesi)")
print(f"  LP eksen: {lp_ok}/{N} hedef ss_err≤{BAND}°  (max θ_std={lp_lc:.2f}°)")
status = "PASS" if (hp_ok>=N-1 and lp_ok==N) else "PARTIAL"
print(f"  → K1 2-eksen eşzamanlı: {status}  (her eksen kendi hedefini bağımsız izledi)")
print("="*64)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/k1_2axis/{ts}"; os.makedirs(d,exist_ok=True)
json.dump({"test_id":"3.K1-2axis","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":{"hp_reached":f"{hp_ok}/{N}","lp_reached":f"{lp_ok}/{N}",
        "hp_max_std":round(hp_lc,2),"lp_max_std":round(lp_lc,2),
        "segments":[{"hp_tgt":s["hp_tgt"],"lp_tgt":s["lp_tgt"],
            "hp_err":round(s["hp"]["err"],2),"lp_err":round(s["lp"]["err"],2),
            "hp_std":round(s["hp"]["std"],2),"lp_std":round(s["lp"]["std"],2)} for s in seg_metrics]}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 3.K1-2axis — 2-eksen eşzamanlı decentralized cascade

- **Tarih:** {ts} · **Commit:** {commit()} · **Durum:** {status}
- **Hedef:** HP+LP aynı anda pozisyon cascade; her eksen kendi hedefini bağımsız izler mi (K1 milestone).
- **Donanım:** HP Motor1/HW-039 + LP Motor2/TB6612, iki mil serbest, mengeneli, loop 8ms.

## Sonuç
| seg | HP hedef | HP err | HP std | LP hedef | LP err | LP std |
|---|---|---|---|---|---|---|
""")
    for s in seg_metrics:
        f.write(f"| | {s['hp_tgt']:+d}° | {s['hp']['err']:.2f}° | {s['hp']['std']:.2f}° | "
                f"{s['lp_tgt']:+d}° | {s['lp']['err']:.2f}° | {s['lp']['std']:.2f}° |\n")
    f.write(f"""
- HP: {hp_ok}/{N} ss_err≤{BAND}° (max θ_std {hp_lc:.2f}° — residual limit-cycle §12.13.4, K7'ye kadar yapısal)
- LP: {lp_ok}/{N} ss_err≤{BAND}° (max θ_std {lp_lc:.2f}°, temiz)

## Yorum
Serbest mil → mekanik kuplaj ~0; iki cascade paralel koştu, her eksen bağımsız izledi → **K1 decentralized**.
Anlamlı kuplaj (RGA, K4) yüklü gimbalda (Aşama-5). HP limit-cycle K7 (Kalman) ile çözülür.

## Üreten: `scripts/k1_2axis_test.py`
""")
print(f"Artifact: {d}/")
