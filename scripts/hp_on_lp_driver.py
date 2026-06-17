#!/usr/bin/env python3
"""HP motoru SAĞLIK testi — LP'nin (sağlam) TB6612-2 sürücüsünde, KORUMALI.

Amaç: HP'nin TB6612'si AO1↔GND kısasıyla öldü. HP MOTORU sağlam mı?
  → HP motor gücü TB6612-2'ye (DUTY2 sürer) taşınır, hareket EC'den okunur.
  → İki yönde de dönerse: motor sağlam, arıza yalnız HP-TB6612 modülüydü.

⚠️ KORUMA (son sağlam TB6612'yi yakmamak için):
  · KALKIŞ-KICK YOK (FET'i bu zorluyordu)
  · duty ≤ 0.15, serbest mil, TEK kanal (paralel yok)
  · BENCH AKIM LİMİTİ 1.0A'E DÜŞÜRÜLMÜŞ olmalı (TB6612 1.2A sürekli altında)
  · kısa hold; düşük dutyde serbest milde akım limite vurursa kullanıcı DURDURUR

Çıktı: ΔEC (HP encoder PA15/PB3) + ΔEC2 (her ihtimale karşı) iki yön.
"""
import serial, time, re, math
import numpy as np

PORT = "/dev/ttyACM0"
CPR_MOTOR = 48.0
DUTY = 0.15
HOLD = 1.2
ser = serial.Serial(PORT, 115200, timeout=0.05); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c + "\n").encode()); ser.flush()

def hold_and_measure(name, cmd, dur=HOLD):
    send(cmd)
    rows = []   # (t, ec, ec2)
    t0 = time.time(); lp = 0
    while time.time() - t0 < dur:
        if time.time() - lp > 0.25: send("PING"); lp = time.time()
        ln = ser.readline().decode(errors="ignore").strip()
        mec  = re.search(r"(?:^|,)EC:(-?\d+)",  ln)
        mec2 = re.search(r"(?:^|,)EC2:(-?\d+)", ln)
        if mec and mec2:
            rows.append((time.time() - t0, int(mec.group(1)), int(mec2.group(1))))
    send("DUTY2:0.0"); send("PING")
    if len(rows) < 3:
        print(f"  {name}: YETERSİZ telemetri ({len(rows)})"); return None
    t = np.array([r[0] for r in rows])
    ec = np.array([r[1] for r in rows]); ec2 = np.array([r[2] for r in rows])
    dEC, dEC2 = int(ec[-1]-ec[0]), int(ec2[-1]-ec2[0])
    cps = float(np.polyfit(t, ec, 1)[0]); cps2 = float(np.polyfit(t, ec2, 1)[0])
    print(f"  {name}: ΔEC={dEC:+d} ({cps:+.0f} c/s, ω={cps/CPR_MOTOR*2*math.pi:+.1f} rad/s)  |  "
          f"ΔEC2={dEC2:+d} ({cps2:+.0f} c/s)")
    return dEC, dEC2

print("=== HP MOTOR sağlık testi — LP TB6612-2 sürücüsünde (KORUMALI, kick YOK, ±0.15) ===")
print("    [Bench akım limiti 1.0A olmalı; serbest mil; akımı izle]")
send("STOP"); time.sleep(0.3)
send("MODE2:DUTY"); time.sleep(0.2)
send("STALLEN:0"); send("STALLEN2:0"); time.sleep(0.2); ser.reset_input_buffer()

print(f"[1] forward  (DUTY2:+{DUTY}):")
fwd = hold_and_measure("HPmotor fwd", f"DUTY2:{DUTY}")
time.sleep(0.6); send("PING")
print(f"[2] reverse  (DUTY2:-{DUTY}):")
rev = hold_and_measure("HPmotor rev", f"DUTY2:-{DUTY}")
send("STOP"); send("DUTY2:0.0"); send("PING")

print("\n=== SONUÇ ===")
if fwd and rev:
    # HP encoder hangi pinde? EC veya EC2 hareket eden hangisiyse onu kullan
    f_ec, f_ec2 = fwd; r_ec, r_ec2 = rev
    use_ec = abs(f_ec) + abs(r_ec) >= abs(f_ec2) + abs(r_ec2)
    f, r = (f_ec, r_ec) if use_ec else (f_ec2, r_ec2)
    tag = "EC (PA15/PB3)" if use_ec else "EC2 (PA8/PA9)"
    print(f"  HP encoder = {tag}; forward Δ={f:+d}, reverse Δ={r:+d}")
    if abs(f) > 50 and abs(r) > 50 and (f > 0) != (r > 0):
        print("  → HP MOTOR SAĞLAM: iki yönde de döndü → arıza yalnız HP-TB6612 modülüydü (FET kısası).")
    elif abs(f) > 50 or abs(r) > 50:
        print("  → KISMİ: bir yön döndü. Diğer yön ölüyse bu sürücüde de sorun başlıyor olabilir — DUR, akımı kontrol et.")
    else:
        print("  → HİÇ dönmedi: ya duty çok düşük (limit?) ya da motor da etkilenmiş. Akım/limit kontrol.")
ser.close()
print("Bitti — bench akımının her yönde ne gösterdiğini söyle.")
