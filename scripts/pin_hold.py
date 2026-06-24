#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Pin-hold — bir çıkış durumunu SEN 'tamam' diyene (script kill edilene) kadar TUTAR.

Motor BAĞLI DEĞİLKEN MCU çıkış pinlerini multimetre ile rahat ölçmek için: durum
basılı kalır, sen ölçersin, ben kapatınca GÜVENLE durur (STOP + DUTY 0).

Kullanım:
  python3 scripts/pin_hold.py DUTY2:0.4    # LP (eksen-1) forward → PB4/PB5 (yön) + PB1 (PWM)
  python3 scripts/pin_hold.py DUTY2:-0.4   # LP reverse → PB4/PB5 yer değiştirir
  python3 scripts/pin_hold.py DUTY:0.4     # HP (eksen-0) forward → PB8 (RPWM) + PB9 + PB14 (EN)
  python3 scripts/pin_hold.py DUTY:-0.4    # HP reverse → PB8/PB9 yer değiştirir
  python3 scripts/pin_hold.py MONITOR      # sürmeden sadece telemetri (encoder elle-çevir → EC/EC2)

Güvenlik: PING watchdog 0.2s'de beslenir (kesilirse firmware ~1s'de zaten durur);
SIGINT/SIGTERM'de güvenli kapanış. Duty heartbeat olarak tazelenir.
Notlar (global CLAUDE.md logging disiplini): ISO-benzeri zaman damgası + seviye + güvenli-fail.
"""
import serial, time, sys, signal, datetime, re

PORT, BAUD = "/dev/ttyACM0", 115200
cmd = (sys.argv[1] if len(sys.argv) > 1 else "MONITOR").upper()

# ── eksen + ölçülecek pin tespiti ───────────────────────────────────────────
if cmd.startswith("DUTY2"):
    mode_cmd, drive = "MODE2:DUTY", True
    pins = "PB4/PB5 (yön = TB6612 AIN1/AIN2: biri ~3.3V biri ~0V)  +  PB1 (PWM, DMM avg ~|duty|x3.3)"
elif cmd.startswith("DUTY"):
    mode_cmd, drive = "MODE:DUTY", True
    pins = "PB8 (RPWM) / PB9 (LPWM): forward→PB8 PWM, PB9~0  +  PB14 (BTS7960 EN = HIGH)"
else:
    cmd, mode_cmd, drive = "(sürmüyor)", None, False
    pins = "encoder'ı elle çevir → telemetride EC (eksen-0) / EC2 (eksen-1) sayacı değişmeli"

ts = lambda: datetime.datetime.now().strftime("%H:%M:%S")

try:
    ser = serial.Serial(PORT, BAUD, timeout=0.05)
except Exception as e:
    print(f"[{ts()}] [ERROR] {PORT} açılamadı: {e}  → board USB'de mi? (ls /dev/ttyACM*)")
    sys.exit(1)

time.sleep(0.5); ser.reset_input_buffer()
send = lambda c: (ser.write((c + "\n").encode()), ser.flush())

running = True
def _stop(*_):
    global running; running = False
signal.signal(signal.SIGINT,  _stop)
signal.signal(signal.SIGTERM, _stop)

# ── kurulum: dur, latched stall-lockout temizle, stall kesmesini kapat, modu kur ──
send("STOP");      time.sleep(0.2)
send("RESET");     time.sleep(0.3)   # latched stall_active'i temizle (HP önceki stall'dan kilitli kalmış olabilir)
send("STALLEN:0"); send("STALLEN2:0"); time.sleep(0.2)
if mode_cmd: send(mode_cmd); time.sleep(0.2)

print(f"[{ts()}] [INFO] === TUT: {cmd} ===")
print(f"[{ts()}] [INFO] ÖLÇ → {pins}")
print(f"[{ts()}] [INFO] Durum basılı tutuluyor. Ölçtükten sonra bana 'tamam' de — kapatınca güvenle durur.")
if drive:
    print(f"[{ts()}] [INFO] Duty-cap 0.50 → PWM pinleri DMM'de max ~1.65V (3.3V GÖRMEZSİN, normal). "
          f"Asıl net test = yön pinleri.")

last_hb = last_print = 0.0
while running:
    now = time.time()
    if now - last_hb > 0.2:                      # watchdog + duty heartbeat taze
        send("PING")
        if drive: send(cmd)
        last_hb = now
    line = ser.readline().decode("utf-8", "replace").strip()
    if line.startswith("T_US") and now - last_print > 1.0:
        d = dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
        print(f"[{ts()}] [DATA] EC={d.get('EC','?'):>8} EC2={d.get('EC2','?'):>8}  "
              f"U={d.get('U','?')} U2={d.get('U2','?')}  "
              f"OMEGA={d.get('OMEGA','?')} OMEGA2={d.get('OMEGA2','?')}")
        last_print = now

# ── güvenli kapanış ──────────────────────────────────────────────────────────
send("STOP"); send("DUTY:0.0"); send("DUTY2:0.0"); send("PING")
print(f"[{ts()}] [INFO] KAPANDI — STOP + DUTY 0 (güvenli). Ölçtüğün değerleri söyle.")
ser.close()
