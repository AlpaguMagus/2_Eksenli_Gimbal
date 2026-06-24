#!/usr/bin/env python3
"""HP-on-TB6612 forward/reverse + LP encoder teşhis — BENCH SUPPLY (12V, 5A/%75).

Tek-adaptör → bench-supply geçişi sonrası ayırt edici test:
  · HP forward zayıf (468) / reverse güçlü (8027) asimetrisi DÜZELDİ mi?
      - DÜZELDİYSE → besleme/sag/ortak-GND kaynaklıydı.
      - DÜZELMEDİYSE → AIN1═BIN1 kablo/köprü (besleme-bağımsız) kesin.
  · LP encoder garabeti (56000 cnt/s, imkânsız) DÜZELDİ mi?
      - DÜZELDİYSE → tek-adaptör ortak-GND gürültüsüydü (bench izole etti).
      - DÜZELMEDİYSE → GND-bütünlüğü/kablo, besleme değil.

Serbest mil (kullanıcı tutuyor), duty-cap %50 firmware, STALLEN:0, PING watchdog 1s.
Çıktı: artifacts/3/hp_tb6612_diag/<ts>/raw/data.csv + stdout özet.
"""
import serial, time, re, math, datetime, os, subprocess
import numpy as np

PORT = "/dev/ttyACM0"
CPR_MOTOR = 48.0
ser = serial.Serial(PORT, 115200, timeout=0.05); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c + "\n").encode()); ser.flush()

allrows = []  # (phase, t, ec, ec2, omega, omega2)

def idle(dur, phase="idle"):
    t0 = time.time(); lp = 0
    while time.time() - t0 < dur:
        if time.time() - lp > 0.25: send("PING"); lp = time.time()
        _read(phase, t0)

def _read(phase, t0):
    ln = ser.readline().decode(errors="ignore").strip()
    ec  = re.search(r"(?:^|,)EC:(-?\d+)",  ln)
    ec2 = re.search(r"(?:^|,)EC2:(-?\d+)", ln)
    om  = re.search(r"(?:^|,)OMEGA:(-?[\d.]+)",  ln)
    om2 = re.search(r"(?:^|,)OMEGA2:(-?[\d.]+)", ln)
    if ec or ec2:
        allrows.append((phase, time.time() - t0,
                        int(ec.group(1))  if ec  else None,
                        int(ec2.group(1)) if ec2 else None,
                        float(om.group(1))  if om  else float("nan"),
                        float(om2.group(1)) if om2 else float("nan")))
    return ln

def run_phase(name, cmd, ec_idx, dur=1.2, kick=None):
    """ec_idx: 2=EC (motor1), 3=EC2 (motor2). Returns (dEC, cps, n)."""
    if kick:
        send(kick[0]); t0 = time.time()
        while time.time() - t0 < kick[1]:
            send("PING"); ser.readline()
    send(cmd)
    rows = []
    t0 = time.time(); lp = 0
    while time.time() - t0 < dur:
        if time.time() - lp > 0.25: send("PING"); lp = time.time()
        _read(name, t0)
        if allrows and allrows[-1][0] == name:
            r = allrows[-1]
            if r[ec_idx] is not None: rows.append((r[1], r[ec_idx]))
    send("DUTY:0.0"); send("DUTY2:0.0"); send("PING")
    if len(rows) < 3:
        print(f"  {name}: YETERSİZ telemetri ({len(rows)} örnek)")
        return None
    t = np.array([r[0] for r in rows]); ec = np.array([r[1] for r in rows])
    dec = int(ec[-1] - ec[0]); cps = float(np.polyfit(t, ec, 1)[0])
    omega = cps / CPR_MOTOR * 2 * math.pi
    print(f"  {name}: ΔEC={dec:+d}  ({cps:+.0f} cnt/s, ω_motor={omega:+.1f} rad/s)  "
          f"[{len(rows)} örnek, EC {int(ec[0])}→{int(ec[-1])}]")
    return dec, cps, len(rows)

print("=== HP-on-TB6612 + LP encoder teşhis (BENCH 12V) ===")
send("STOP"); time.sleep(0.3)
send("MODE:DUTY"); send("MODE2:DUTY"); time.sleep(0.2)
send("STALLEN:0"); send("STALLEN2:0"); time.sleep(0.2); ser.reset_input_buffer()

print("[1] HP forward (DUTY:0.50, kick'li):")
hp_fwd = run_phase("HP_fwd", "DUTY:0.50", 2, kick=("DUTY:0.48", 0.12))
idle(0.8)
print("[2] HP reverse (DUTY:-0.50, kick'li):")
hp_rev = run_phase("HP_rev", "DUTY:-0.50", 2, kick=("DUTY:-0.48", 0.12))
idle(0.8)
print("[3] LP (DUTY2:0.25) — encoder temiz mi:")
lp = run_phase("LP", "DUTY2:0.25", 3)
send("STOP"); send("DUTY2:0.0"); send("PING")

# ── Ayırt edici yorum ──
print("\n=== AYIRT EDİCİ ANALİZ ===")
if hp_fwd and hp_rev:
    fdec, _, _ = hp_fwd; rdec, _, _ = hp_rev
    ratio = abs(rdec) / max(abs(fdec), 1)
    print(f"  HP fwd/rev simetri: |fwd|={abs(fdec)}, |rev|={abs(rdec)}, oran rev/fwd={ratio:.1f}× (1.0 ideal)")
    if ratio > 3:
        print("  → HÂLÂ ASİMETRİK: besleme/sag DEĞİL → AIN1═BIN1 kablo/köprü kesin şüpheli.")
    elif ratio < 1.8:
        print("  → SİMETRİK oldu: forward düzeldi → tek-adaptör/sag/ortak-GND kaynaklıymış.")
    else:
        print("  → KISMİ: hafif asimetri kaldı, hem besleme hem kablo katkısı olabilir.")
if lp:
    ldec, lcps, _ = lp
    print(f"  LP encoder: {abs(lcps):.0f} cnt/s (DUTY2:0.25). Beklenen ~birkaç bin cnt/s.")
    if abs(lcps) > 30000:
        print("  → HÂLÂ GARABET: bench izole etmedi → GND-bütünlüğü/kablo, besleme değil.")
    else:
        print("  → TEMİZ: encoder düzeldi → tek-adaptör ortak-GND gürültüsüydü.")

# ── Artifact (raw) ──
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d = f"artifacts/3/hp_tb6612_diag/{ts}"; os.makedirs(f"{d}/raw", exist_ok=True)
with open(f"{d}/raw/data.csv", "w") as f:
    f.write("phase,t_s,ec,ec2,omega,omega2\n")
    for r in allrows:
        f.write(f"{r[0]},{r[1]:.4f},{r[2] if r[2] is not None else ''},"
                f"{r[3] if r[3] is not None else ''},{r[4]:.2f},{r[5]:.2f}\n")
print(f"\nArtifact raw: {d}/raw/data.csv  ({len(allrows)} satır)")
ser.close()
print("Bitti — bench akım okumalarını söyle (her fazda ekran kaç A gösterdi), kıyaslarım.")
