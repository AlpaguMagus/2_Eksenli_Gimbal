#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP step-ID A/B — RAMPALI vs RAMPASIZ adım → firmware-ramp confound'unu izole eder.

Hipotez (2026-06-20 teşhisi): §12.10'un ölçtüğü τ_eff≈450ms, firmware rampasıyla
(MOTOR_RAMP_STEP=0.01/tick, ~7ms döngü) ŞİŞMİŞ olabilir. motor.c MOTOR_DEAD_THRESHOLD=0.10:
|Δduty|>0.10 → RAMPALI, ≤0.10 → DİREKT. İki adımı kıyaslarız:

  A (RAMPALI):  0.30 → 0.50  (Δ=0.20 > 0.10 → ~140ms rampa)   [§12.10'u tekrarlar]
  B (RAMPASIZ): 0.40 → 0.50  (Δ=0.10 ≤ 0.10 → DİREKT, rampa YOK)

τ_B << τ_A (≈30-60ms) → 450ms firmware-ramp artefaktıydı, HW-039 aslında hızlı.
τ_B hâlâ ~300ms+ → sürücü gerçekten yavaş (modül-domeni; DFR0601 haklı).

⚠ FİZİKSEL TEST — HP motor HW-039'a bağlı + mil serbest dönebilir olmalı. Kullanıcı "hazırım" demeden çalıştırma.
Kullanım: python3 scripts/hp_stepid_rampasiz.py
Çıktı: artifacts/3/hp_stepid_rampasiz/<ts>/ (raw CSV + summary.md + meta.json)
"""
import serial, time, sys, os, json, subprocess, datetime, re

PORT, BAUD = "/dev/ttyACM0", 115200
KICK_DUTY, KICK_S = 0.48, 0.35    # stiction kırma (hp_stepid_test.py ile aynı)
SETTLE_S, REC_S = 1.2, 1.5        # oturma + kayıt süresi

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"

try:
    ser = serial.Serial(PORT, BAUD, timeout=0.02)
except Exception as e:
    print(f"[ERROR] {PORT} açılamadı: {e} — board USB'de mi?"); sys.exit(1)
time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()

def collect(secs, label):
    """T_US, EC(axis-0), cmd, OMEGA yakala; PING heartbeat besle."""
    rows = []; t0 = time.time(); lp = 0
    while time.time() - t0 < secs:
        if time.time() - lp > 0.15: send("PING"); lp = time.time()
        line = ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            d = dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
            if "T_US" in d and "EC" in d:
                rows.append((float(d["T_US"])*1e-6, int(d["EC"]), float(d.get("OMEGA","0"))))
    return rows

def run_step(base, target, ramped_label):
    """kick → base'de otur → target'a adım; kayıt = adım anından itibaren."""
    send("STOP"); time.sleep(0.4)
    send("PING"); send(f"DUTY:{KICK_DUTY}"); time.sleep(KICK_S)   # stiction kick
    send(f"DUTY:{base}");
    t=time.time()                                                 # base'de otur (kayıtsız)
    while time.time()-t < SETTLE_S: send("PING"); send(f"DUTY:{base}"); time.sleep(0.12)
    send(f"DUTY:{target}")                                        # ← ADIM
    rows = collect(REC_S, ramped_label)
    send("DUTY:0.0"); send("STOP"); time.sleep(0.6)
    return rows

def tau63(rows):
    """ω = ΔEC/Δt (count/s); steady = son %20 ortalama; τ = %63'e ulaşma süresi."""
    if len(rows) < 8: return None, None, None
    t0 = rows[0][0]
    t = [r[0]-t0 for r in rows]; ec = [r[1] for r in rows]
    # kayan ω (3-nokta merkezi fark)
    w = []
    for i in range(1,len(rows)):
        dt = t[i]-t[i-1]
        w.append((t[i], (ec[i]-ec[i-1])/dt if dt>0 else 0.0))
    if len(w) < 6: return None, None, None
    w0 = sum(x[1] for x in w[:3])/3.0
    wss = sum(x[1] for x in w[-max(3,len(w)//5):])/max(3,len(w)//5)
    dw = wss - w0
    if abs(dw) < 1e-6: return None, w0, wss
    target = w0 + 0.632*dw
    for tt, ww in w:
        if (dw>0 and ww>=target) or (dw<0 and ww<=target):
            return tt, w0, wss
    return None, w0, wss

print("="*60)
print("HP step-ID A/B — RAMPALI vs RAMPASIZ (firmware-ramp confound testi)")
print("⚠ HP motor HW-039'a bağlı + mil serbest olmalı.")
print("="*60)
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2)
send("STALLEN:0"); time.sleep(0.2); ser.reset_input_buffer()

print("\n[A] RAMPALI: 0.30 → 0.50 (Δ0.20, firmware rampası devrede)...")
rowsA = run_step(0.30, 0.50, "RAMPALI")
tauA, w0A, wssA = tau63(rowsA)

print("[B] RAMPASIZ: 0.40 → 0.50 (Δ0.10, DİREKT — rampa yok)...")
rowsB = run_step(0.40, 0.50, "RAMPASIZ")
tauB, w0B, wssB = tau63(rowsB)

# ── sonuç ───────────────────────────────────────────────────────────────────
ms = lambda x: f"{x*1000:.0f}ms" if x else "?"
print("\n" + "="*60)
print(f"  A RAMPALI  (Δ0.20): τ63 = {ms(tauA)}   (ω {w0A:.0f}→{wssA:.0f} cnt/s)")
print(f"  B RAMPASIZ (Δ0.10): τ63 = {ms(tauB)}   (ω {w0B:.0f}→{wssB:.0f} cnt/s)")
if tauA and tauB:
    print(f"  ORAN A/B = {tauA/tauB:.1f}×")
    if tauB < 0.10:
        print("  → HÜKÜM: τ_B çok küçük → 450ms FIRMWARE RAMP artefaktıydı. HW-039 hızlı.")
    elif tauB < 0.20:
        print("  → HÜKÜM: τ_B orta → ramp büyük confound'du; sürücü makul, DFR0601 hız için gereksiz olabilir.")
    else:
        print("  → HÜKÜM: τ_B hâlâ büyük → sürücü gerçekten yavaş (modül-domeni).")
print("="*60)

# ── artifact (global CLAUDE.md test-artifact disiplini) ──────────────────────
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d = f"artifacts/3/hp_stepid_rampasiz/{ts}"; os.makedirs(f"{d}/raw", exist_ok=True)
for name, rows in [("A_rampali", rowsA), ("B_rampasiz", rowsB)]:
    with open(f"{d}/raw/{name}.csv","w") as f:
        f.write("t_s,ec,omega_fw\n")
        for r in rows: f.write(f"{r[0]:.6f},{r[1]},{r[2]:.2f}\n")
meta = {"test_id":"3.HP-rampasiz","timestamp":ts,"commit":commit(),
        "status":"PASS" if (tauB is not None) else "FAIL",
        "key_metrics":{"tauA_ramped_ms":round(tauA*1000,1) if tauA else None,
                       "tauB_direct_ms":round(tauB*1000,1) if tauB else None,
                       "ratio_AB":round(tauA/tauB,2) if (tauA and tauB) else None},
        "artifacts":["raw/A_rampali.csv","raw/B_rampasiz.csv"]}
json.dump(meta, open(f"{d}/meta.json","w"), ensure_ascii=False, indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# HP step-ID A/B — RAMPALI vs RAMPASIZ (firmware-ramp confound)
- **Tarih:** {ts}  · **Commit:** {commit()}
- **Hedef:** §12.10 τ_eff≈450ms firmware-rampası mı, sürücü mü ayır.
## Sonuç
| Adım | Δduty | yol | τ63 |
|---|---|---|---|
| A | 0.20 | RAMPALI | {ms(tauA)} |
| B | 0.10 | DİREKT | {ms(tauB)} |
Oran A/B = {f'{tauA/tauB:.1f}×' if (tauA and tauB) else '?'}
## Hüküm
τ_B < 100ms → 450ms firmware-ramp artefaktı (HW-039 hızlı). τ_B > 200ms → sürücü gerçekten yavaş.
""")
print(f"\nArtifact: {d}/  (raw CSV + summary.md + meta.json)")
ser.close()
