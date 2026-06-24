#!/usr/bin/env python3
"""Statik yön-tut (multimetre probe için) — AIN1/AIN2'yi sabit HIGH tutar.

Kullanım:  python3 scripts/hold_dir.py fwd 25     # forward (AIN1=HIGH), 25 sn
           python3 scripts/hold_dir.py rev 25     # reverse (AIN2=HIGH), kıyas

Forward'da AIN1 (PB12) statik HIGH; multimetre ile PB12 ve TB6612 AIN1 pinini ölç.
STALLEN:0 (forward ölüyken stall yanlış-pozitifi AIN'i düşürmesin). Düşük duty (0.25)
→ AIN1 yine HIGH ama akım düşük. PING watchdog (1s) sürekli beslenir.
"""
import serial, time, sys

PORT = "/dev/ttyACM0"
direction = sys.argv[1] if len(sys.argv) > 1 else "fwd"
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 25.0
duty = 0.25 if direction == "fwd" else -0.25
pin = "AIN1 (PB12) = forward" if direction == "fwd" else "AIN2 (PB13) = reverse"

ser = serial.Serial(PORT, 115200, timeout=0.05); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c + "\n").encode()); ser.flush()

send("STOP"); time.sleep(0.2); send("MODE:DUTY"); time.sleep(0.2)
send("STALLEN:0"); time.sleep(0.2)
print(f"=== STATİK TUT: {pin} HIGH, {secs:.0f} sn — ŞİMDİ multimetre ile ölç ===")
send(f"DUTY:{duty}")
t0 = time.time(); lp = 0; last_print = 0
while time.time() - t0 < secs:
    if time.time() - lp > 0.20:
        send("PING"); send(f"DUTY:{duty}"); lp = time.time()   # dir+watchdog taze
    rem = secs - (time.time() - t0)
    if time.time() - last_print > 1.0:
        print(f"  ... kalan {rem:4.0f} sn  ({pin} HIGH tutuluyor)")
        last_print = time.time()
    ser.readline()
send("STOP"); send("DUTY:0.0"); send("PING")
print("Bitti — STOP. Ölçtüğün değerleri söyle (PB12 ve AIN1 pini, V).")
ser.close()
