#!/usr/bin/env python3
"""Encoder idle-drift teşhis — MOTOR KAPALIYKEN EC/EC2 kendiliğinden yarışıyor mu?

Ayırt edici: LP encoder garabeti (EC2 ~60000 cnt/s) motor-PWM gürültüsü mü,
yoksa hat/floating-input gürültüsü mü?
  · Motor OFF'ta EC2 SABİT kalırsa → garabet motor-anahtarlama gürültüsü kaynaklı.
  · Motor OFF'ta EC2 yine YARIŞIRSA → encoder hattı floating/kopuk (hat gürültüsü),
    motordan bağımsız → A/B kablo veya encoder-GND/VCC kopuk.

Hiçbir DUTY komutu yok — yalnız PING (watchdog). 3 sn izle.
"""
import serial, time, re

PORT = "/dev/ttyACM0"
ser = serial.Serial(PORT, 115200, timeout=0.05); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c + "\n").encode()); ser.flush()

send("STOP"); send("DUTY:0.0"); send("DUTY2:0.0"); time.sleep(0.3); ser.reset_input_buffer()
print("=== Encoder idle-drift (MOTOR KAPALI, 3 sn) ===")
ec_first = ec2_first = None
ec_last = ec2_last = None
n = 0
t0 = time.time(); lp = 0
while time.time() - t0 < 3.0:
    if time.time() - lp > 0.25: send("PING"); lp = time.time()
    ln = ser.readline().decode(errors="ignore").strip()
    mec  = re.search(r"(?:^|,)EC:(-?\d+)",  ln)
    mec2 = re.search(r"(?:^|,)EC2:(-?\d+)", ln)
    if mec and mec2:
        ec, ec2 = int(mec.group(1)), int(mec2.group(1))
        if ec_first is None: ec_first, ec2_first = ec, ec2
        ec_last, ec2_last = ec, ec2; n += 1

send("PING")
if n < 3:
    print(f"  YETERSİZ telemetri ({n})")
else:
    dt = time.time() - t0
    dEC, dEC2 = ec_last - ec_first, ec2_last - ec2_first
    print(f"  Süre ~{dt:.1f}s, {n} örnek (motor KAPALI)")
    print(f"  EC  (motor1): {ec_first} → {ec_last}   ΔEC ={dEC:+d}   ({dEC/dt:+.0f} cnt/s)")
    print(f"  EC2 (motor2): {ec2_first} → {ec2_last}   ΔEC2={dEC2:+d}   ({dEC2/dt:+.0f} cnt/s)")
    print()
    if abs(dEC2/dt) > 500:
        print("  → EC2 motor KAPALIYKEN yarışıyor: LP encoder hattı FLOATING/KOPUK")
        print("    (motor gürültüsü DEĞİL). A/B sinyal veya encoder GND/VCC kontrol et.")
    else:
        print("  → EC2 motor kapalıyken SABİT: garabet yalnız motor sürülünce → PWM gürültü kuplajı.")
    if abs(dEC/dt) > 500:
        print("  → DİKKAT: EC (motor1) da kapalıyken yarışıyor — motor1 encoder hattı da gürültülü.")
ser.close()
