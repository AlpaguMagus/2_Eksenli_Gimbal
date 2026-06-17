#!/usr/bin/env python3
"""LP encoder garabet RE-CHECK — HP TB6612 devre dışı kaldıktan sonra GND gürültüsü değişti mi?

Ayırt edici: LP'yi iki dutyde sür (0.15, 0.30). EC2 cnt/s ~2× ölçeklenirse GERÇEK dönüş
(duty-orantılı). Devasa/sabit (~60000) kalırsa hâlâ PWM-gürültü kuplajı.
Beklenen gerçek (LP Kg=654.8): 0.15→~750, 0.30→~1500 cnt/s. Garabet eskiden ~60000.
"""
import serial, time, re, math
import numpy as np

PORT = "/dev/ttyACM0"
CPR_MOTOR = 48.0
ser = serial.Serial(PORT, 115200, timeout=0.05); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c + "\n").encode()); ser.flush()

def measure(name, cmd, dur=1.3, drive=True):
    if drive: send(cmd)
    rows = []
    t0 = time.time(); lp = 0
    while time.time() - t0 < dur:
        if time.time() - lp > 0.25: send("PING"); lp = time.time()
        ln = ser.readline().decode(errors="ignore").strip()
        m2 = re.search(r"(?:^|,)EC2:(-?\d+)", ln)
        if m2: rows.append((time.time() - t0, int(m2.group(1))))
    if drive: send("DUTY2:0.0"); send("PING")
    if len(rows) < 3:
        print(f"  {name}: YETERSİZ ({len(rows)})"); return None
    t = np.array([r[0] for r in rows]); ec2 = np.array([r[1] for r in rows])
    cps = float(np.polyfit(t, ec2, 1)[0])
    print(f"  {name}: {cps:+.0f} cnt/s  (ΔEC2={int(ec2[-1]-ec2[0]):+d}, {len(rows)} örnek)")
    return abs(cps)

print("=== LP encoder garabet RE-CHECK (mevcut wiring, HP TB6612 devre dışı) ===")
send("STOP"); time.sleep(0.3); send("MODE2:DUTY"); time.sleep(0.2)
send("STALLEN2:0"); time.sleep(0.2); ser.reset_input_buffer()

print("[0] idle (motor KAPALI):")
idle = measure("idle", None, dur=1.5, drive=False)
print("[1] LP forward DUTY2:0.15:")
c15 = measure("d=0.15", "DUTY2:0.15")
time.sleep(0.5); send("PING")
print("[2] LP forward DUTY2:0.30:")
c30 = measure("d=0.30", "DUTY2:0.30")
send("STOP"); send("DUTY2:0.0"); send("PING")

print("\n=== VERDİCT ===")
if c15 and c30:
    ratio = c30 / max(c15, 1)
    print(f"  0.15→{c15:.0f}, 0.30→{c30:.0f} cnt/s, oran={ratio:.2f}× (gerçek dönüş ~2.0 beklenir)")
    if c30 < 5000 and 1.4 < ratio < 2.8:
        print("  → ✅ TEMİZ: EC2 makul + duty-orantılı → encoder DÜZELDİ, gürültü gitti.")
    elif c30 > 20000:
        print("  → ❌ HÂLÂ GARABET: EC2 devasa → PWM-gürültü kuplajı sürüyor (encoder GND/kablo).")
    else:
        print("  → KISMİ/belirsiz: ne tam temiz ne tam garabet — ham veriye bak, akım/şaft gözlemle.")
print("Bitti — LP mili fiziksel dönüyor muydu (gözlem)? Ona göre teyit ederiz.")
ser.close()
