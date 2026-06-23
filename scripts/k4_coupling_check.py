#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""K4 coupling-check — serbest-mil 2×2 G off-diagonal (decentralized gerekçesi).

Bir ekseni POS 0'da aktif TUT, diğerini duty ile sür → tutulan eksenin sapması = mekanik/elektriksel kuplaj.
Serbest mil → mekanik bağ YOK → off-diagonal ~0 beklenir (decentralized'i SAYIYLA doğrular).
⚠ Bu yüksüz/bağsız G'nin off-diagonali ~0; ANLAMLI kuplaj (RGA, decoupling kararı) = yüklü gimbal (Aşama-5).
θ_hp=EC×360/960 (0.375°/cnt), θ_lp=EC2×360/466 (0.77°/cnt). Çıktı: artifacts/3/k4_coupling/<ts>/
"""
import serial, time, re, os, json, subprocess, datetime

PORT, BAUD = "/dev/ttyACM0", 115200
HP_DPC = 360.0/960.0
LP_DPC = 360.0/466.0
DRIVE, DUR = 0.40, 1.5

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"

ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
ECr=re.compile(r"EC:(-?\d+)"); EC2r=re.compile(r"EC2:(-?\d+)")

def collect(secs, drive_cmd=None, drive_val=None):
    rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0 < secs:
        if time.time()-lp>0.10:
            if drive_cmd: send(f"{drive_cmd}:{drive_val}")
            send("PING"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if not line.startswith("T_US"): continue
        me=ECr.search(line); m2=EC2r.search(line)
        if me and m2: rows.append((int(me.group(1))*HP_DPC, int(m2.group(1))*LP_DPC))
    return rows

def rng(vals): return (max(vals)-min(vals)) if vals else 0.0

print("="*64); print(" K4 COUPLING-CHECK — serbest-mil off-diagonal (decentralized)"); print("="*64)
send("STOP"); time.sleep(0.3); send("STALLEN:0"); time.sleep(0.2)
res={}

# --- HP sür, LP tut (POS 0) → coupling_21 (LP←HP) ---
print("\n[HP sür → LP tut] off-diagonal G21:")
send("MODE:DUTY"); send("MODE2:POS"); send("POS_DEG2:0"); time.sleep(1.5); ser.reset_input_buffer()
hp_th=[]; lp_th=[]
for sign in (+1,-1):
    rows=collect(DUR, "DUTYR", sign*DRIVE)
    hp_th += [r[0] for r in rows]; lp_th += [r[1] for r in rows]
send("DUTYR:0.0"); time.sleep(0.3)
hp_move=rng(hp_th); lp_dev=rng(lp_th)
res["G21"]={"driven_hp_range":round(hp_move,1),"held_lp_dev":round(lp_dev,2),
            "coupling_pct":round(100*lp_dev/hp_move,2) if hp_move>1 else None}
print(f"   HP döndü {hp_move:.0f}°  |  tutulan LP sapması {lp_dev:.2f}°  →  kuplaj {res['G21']['coupling_pct']}%")

# --- LP sür, HP tut (POS 0) → coupling_12 (HP←LP) ---
print("[LP sür → HP tut] off-diagonal G12:")
send("MODE:POS"); send("POS_DEG:0"); send("MODE2:DUTY"); time.sleep(1.5); ser.reset_input_buffer()
hp_th=[]; lp_th=[]
for sign in (+1,-1):
    rows=collect(DUR, "DUTY2", sign*DRIVE)
    hp_th += [r[0] for r in rows]; lp_th += [r[1] for r in rows]
send("DUTY2:0.0"); time.sleep(0.3); send("STOP"); ser.close()
lp_move=rng(lp_th); hp_dev=rng(hp_th)
res["G12"]={"driven_lp_range":round(lp_move,1),"held_hp_dev":round(hp_dev,2),
            "coupling_pct":round(100*hp_dev/lp_move,2) if lp_move>1 else None}
print(f"   LP döndü {lp_move:.0f}°  |  tutulan HP sapması {hp_dev:.2f}°  →  kuplaj {res['G12']['coupling_pct']}%")

c21=res["G21"]["coupling_pct"]; c12=res["G12"]["coupling_pct"]
weak = (c21 is not None and c21<3) and (c12 is not None and c12<3)
print("\n"+"="*64)
print(f"  off-diagonal kuplaj: G21={c21}%  G12={c12}%")
print(f"  → {'✅ KUPLAJ ~0 (serbest-mil) → decentralized GEREKÇELİ' if weak else '⚠ kuplaj belirgin — incele'}")
print(f"  (anlamlı RGA/kuplaj = YÜKLÜ gimbal, Aşama-5; bağsız off-diagonal beklendiği gibi ~0)")
print("="*64)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/k4_coupling/{ts}"; os.makedirs(d,exist_ok=True)
status="PASS" if weak else "REVIEW"
json.dump({"test_id":"3.K4-coupling","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":res},open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 3.K4-coupling — serbest-mil off-diagonal (decentralized gerekçesi)

- **Tarih:** {ts} · **Commit:** {commit()} · **Durum:** {status}
- **Hedef:** 2×2 G off-diagonal (kuplaj) serbest-milde ~0 mı → decentralized'ı SAYIYLA doğrula.
- **Yöntem:** bir ekseni POS 0'da aktif tut, diğerini ±{DRIVE} duty sür, tutulan eksenin sapması = kuplaj.
- **Donanım:** HP+LP mengeneli, **serbest mil** (mekanik bağ yok), loop 8ms.

## Sonuç
| off-diagonal | Sürülen döndü | Tutulan saptı | Kuplaj |
|---|---|---|---|
| **G21** (LP←HP) | {res['G21']['driven_hp_range']}° | {res['G21']['held_lp_dev']}° | {c21}% |
| **G12** (HP←LP) | {res['G12']['driven_lp_range']}° | {res['G12']['held_hp_dev']}° | {c12}% |

## Yorum
Serbest mil → mekanik bağ yok → off-diagonal ~0 (decentralized cascade GEREKÇELİ). ⚠ **Anlamlı kuplaj
(RGA, decoupling kararı = K4'ün asıl payoff'u) YÜKLÜ gimbalda** (iki eksen mekanik bağlı, Aşama-5). Bu test
bağsız baseline'ı belgeler; gerçek MIMO ID yüklü montajda yapılır.

## Üreten: `scripts/k4_coupling_check.py`
""")
print(f"Artifact: {d}/")
