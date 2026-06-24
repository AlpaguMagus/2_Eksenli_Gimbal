#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP dropout gözlem — DUTYR:0.40 (4s) → DUTYR:0.50 (4s). KULLANICI MOTORA BAKAR.
Step'te motor fiziksel DURUYOR (besleme/UVLO) mu yoksa DÖNMEYE DEVAM (encoder EMI) mı?
EC ayrıca loglanır (dropout = EC donması)."""
import serial, time, re
ser = serial.Serial("/dev/ttyACM0", 115200, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2); send("STALLEN:0"); time.sleep(0.2)
def drive(duty, secs, label):
    print(f">>> {label}: DUTYR:{duty} — {secs:.0f}s");
    t=time.time(); lp=0.0; last=0.0; ec0=None; ecN=None
    while time.time()-t < secs:
        if time.time()-lp > 0.1: send("PING"); send(f"DUTYR:{duty}"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            d=dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
            if "EC" in d:
                ec=int(d["EC"]); ec0 = ec if ec0 is None else ec0; ecN=ec
                if time.time()-last > 0.5:
                    print(f"    EC={ec:>8}  (Δ from start: {ec-ec0:+d})"); last=time.time()
    print(f"    → {label} ΔEC toplam = {ecN-ec0:+d}  ({'DÖNDÜ' if abs(ecN-ec0)>500 else 'DURGUN/dondu'})")
drive(0.40, 4, "BASE")
drive(0.50, 4, "STEP ⟵ MOTORA BAK")
send("DUTYR:0.0"); send("STOP"); ser.close()
print("\nBitti. Motor 0.50 step'te ne yaptı? (fiziksel durdu / hızlandı / aynı kaldı)")
