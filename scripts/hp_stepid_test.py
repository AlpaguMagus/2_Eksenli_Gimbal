#!/usr/bin/env python3
"""HP step-ID karakterizasyonu — eksen-0 (HW-039/BTS7960, 20 kHz, 20:1 redüktör). SERBEST MİL.

Aşama-1 LP metodunun (matlab/asama_1_model) HP karşılığı. Açık-döngü duty step → kararlı-hal
hız → birinci-mertebe plant G(s)=Kg/(τs+1) (duty-domeni) + V_dead.

- ω MOTOR ŞAFTI: ham EC (48 CPR motor, 4× decoded) eğiminden hesaplanır → REDÜKTÖR-BAĞIMSIZ
  (encoder gearbox'tan ÖNCE). Firmware OMEGA çapraz-kontrol için loglanır.
- Kalkış-KICK (0.48, ~120ms) her step başında → BTS7960 startup-stiction'ı kır → ölü-bölge
  altındaki KİNETİK çalışma rejimini de karakterize et (cascade plant'ı için doğru olan bu).
- Güvenli: duty-cap %50 firmware, PING heartbeat (watchdog 1s), STALLEN:0, serbest mil (kullanıcı tutuyor).

Çıktı: artifacts/3/hp_stepid/<ts>/{raw/data.csv, summary.md, meta.json}
"""
import serial, time, re, math, datetime, json, os, subprocess
import numpy as np

PORT      = "/dev/ttyACM0"
CPR_MOTOR = 48.0     # Pololu 25D motor şaftı (4× decoded), redüktör-bağımsız
VS        = 12.15    # Aşama-1 ölçülen supply (V); duty-domeni Kg Vs'siz, V-domeni K=Kg/Vs
KICK_DUTY = 0.48
KICK_S    = 0.12

ser = serial.Serial(PORT, 115200, timeout=0.05); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c + "\n").encode()); ser.flush()

t0_glob = time.time()
samples = []   # (t, cmd_duty, ec, omega_fw)
def collect(dur, cmd_duty):
    t0 = time.time(); lp = 0
    while time.time() - t0 < dur:
        if time.time() - lp > 0.25: send("PING"); lp = time.time()
        ln = ser.readline().decode(errors="ignore").strip()
        m = re.search(r"EC:(-?\d+)", ln); mo = re.search(r"OMEGA:(-?[\d.]+)", ln)
        if m:
            om = float(mo.group(1)) if mo else float("nan")
            samples.append((time.time() - t0_glob, cmd_duty, int(m.group(1)), om))

def omega_ec(seg):
    """seg: [(t,ec)] → EC eğimi (counts/s) → ω motor rad/s."""
    if len(seg) < 3: return float("nan")
    t = np.array([s[0] for s in seg]); ec = np.array([s[1] for s in seg])
    cps = np.polyfit(t, ec, 1)[0]
    return cps / CPR_MOTOR * 2 * math.pi

print("=== HP step-ID (eksen-0, serbest mil, kick'li) ===")
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2)
send("STALLEN:0"); time.sleep(0.2); ser.reset_input_buffer()

# ── Test A: kararlı-hal sweep (her step kick + hedef) ──
ss = []   # (duty, omega_ss)
def steady(D, hold=1.6, win=0.6):
    send("PING"); send(f"DUTY:{KICK_DUTY}"); collect(KICK_S, KICK_DUTY)
    send(f"DUTY:{D}"); collect(hold, D)
    tnow = time.time() - t0_glob
    seg = [(s[0], s[2]) for s in samples if abs(s[1] - D) < 1e-6 and s[0] > tnow - win]
    w = omega_ec(seg); ss.append((D, w))
    print(f"  duty={D:+.2f} → ω_ss={w:8.1f} rad/s")
    send("DUTY:0.0"); send("PING"); time.sleep(0.7)
    return w

print("[Test A] ileri kararlı-hal sweep:")
for D in [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50]:
    steady(D)
print("[Test A] geri (simetri kontrolü):")
for D in [-0.25, -0.35, -0.50]:
    steady(D)

# ── Test B: τ için temiz step transient (0.30→0.50, motor zaten dönüyor) ──
print("[Test B] τ step transient (0.30→0.50):")
tau_seg_start = len(samples)
send("PING"); send(f"DUTY:{KICK_DUTY}"); collect(KICK_S, KICK_DUTY)
send("DUTY:0.30"); collect(1.2, 0.30)         # 0.30'da otur
tau_step_t = time.time() - t0_glob
send("DUTY:0.50"); collect(1.2, 0.50)         # STEP → transient
send("DUTY:0.0"); send("STOP")

# ── τ kestirimi: 0.30→0.50 geçişinde ω(t)'nin %63 yükseliş zamanı ──
trans = [s for s in samples if s[0] >= tau_step_t and abs(s[1] - 0.50) < 1e-6]
tau_est = float("nan")
if len(trans) > 5:
    tt = np.array([s[0] for s in trans]) - tau_step_t
    ec = np.array([s[2] for s in trans])
    # kayan-pencere anlık ω (3-nokta merkezi fark)
    w_inst = []
    for i in range(1, len(ec) - 1):
        dw = (ec[i+1] - ec[i-1]) / (tt[i+1] - tt[i-1]) / CPR_MOTOR * 2 * math.pi
        w_inst.append((tt[i], dw))
    if w_inst:
        wt = np.array([x[0] for x in w_inst]); wv = np.array([x[1] for x in w_inst])
        w0 = wv[0]; wf = np.median(wv[-3:]); target = w0 + 0.632 * (wf - w0)
        for i in range(len(wv)):
            if (wf > w0 and wv[i] >= target) or (wf < w0 and wv[i] <= target):
                tau_est = wt[i]; break

# ── Lineer fit: ω_ss = Kg·duty + b → Kg (slope), V_dead = -b/Kg ──
fwd = [(d, w) for d, w in ss if d > 0 and np.isfinite(w) and w > 5]
Kg = Vdead = K_V = float("nan")
if len(fwd) >= 3:
    d = np.array([x[0] for x in fwd]); w = np.array([x[1] for x in fwd])
    Kg, b = np.polyfit(d, w, 1)        # rad/s per duty, intercept
    Vdead = -b / Kg                    # duty cinsinden ölü-bölge (kinetik)
    K_V = Kg / VS                      # rad/s/V (motor şaftı)
    r2 = 1 - np.sum((w - (Kg*d+b))**2) / np.sum((w - w.mean())**2)
else:
    r2 = float("nan")

rev = [(abs(d), abs(w)) for d, w in ss if d < 0 and np.isfinite(w) and abs(w) > 5]
Kg_rev = float("nan")
if len(rev) >= 2:
    dr = np.array([x[0] for x in rev]); wr = np.array([x[1] for x in rev])
    Kg_rev = np.polyfit(dr, wr, 1)[0]

print("\n=== HP KARAKTERİZASYON SONUÇLARI ===")
print(f"  Kg (duty-domeni)  = {Kg:8.1f} rad/s/duty   (LP: 654.8)")
print(f"  K  (V-domeni)     = {K_V:8.2f} rad/s/V      (LP: 53.89)")
print(f"  V_dead (kinetik)  = {Vdead:8.3f} duty")
print(f"  τ (0.30→0.50)     = {tau_est*1000:8.1f} ms       (LP: ~60.5)")
print(f"  fit R²            = {r2:8.3f}")
print(f"  Kg_geri / Kg_ileri= {Kg_rev/Kg:8.3f}  (simetri; 1.0 ideal)")

# ── Artifact ──
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except: return "nogit"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d = f"artifacts/3/hp_stepid/{ts}"; os.makedirs(f"{d}/raw", exist_ok=True)
with open(f"{d}/raw/data.csv", "w") as f:
    f.write("t_s,cmd_duty,ec,omega_fw\n")
    for s in samples: f.write(f"{s[0]:.4f},{s[1]:.3f},{s[2]},{s[3]:.2f}\n")
ststr = "\n".join(f"| {dd:+.2f} | {ww:.1f} |" for dd, ww in ss)
status = "PASS" if (np.isfinite(Kg) and Kg > 100 and r2 > 0.9) else "REVIEW"
with open(f"{d}/summary.md", "w") as f:
    f.write(f"""# HP step-ID karakterizasyonu — eksen-0 (HW-039/BTS7960, 20 kHz, 20:1)

- **Test ID:** hp_stepid_{ts}
- **Tarih:** {datetime.datetime.now():%Y-%m-%d %H:%M}
- **Commit:** `{commit()}`
- **Hedef:** HP plant kimliği (Kg, K, τ, V_dead) — firmware LP paramıyla sürüyordu (cascade YANLIŞ)
- **Komut:** `python3 scripts/hp_stepid_test.py`
- **Koşul:** serbest mil (kullanıcı tutuyor), kalkış-kick'li, ω = EC(48 CPR motor) eğimi

## Sonuç (sayısal)
| Metric | HP | LP (Aşama-1) | Durum |
|---|---|---|---|
| Kg [rad/s/duty] | {Kg:.1f} | 654.8 | {'✓' if Kg>100 else '✗'} |
| K [rad/s/V] | {K_V:.2f} | 53.89 | — |
| τ [ms] (0.30→0.50) | {tau_est*1000:.1f} | ~60.5 | — |
| V_dead [duty] | {Vdead:.3f} | ~0 | — |
| fit R² | {r2:.3f} | — | {'✓' if r2>0.9 else '✗'} |
| Kg_geri/Kg_ileri | {Kg_rev/Kg:.3f} | (CW/CCW ~%1) | — |

## Kararlı-hal (duty → ω_ss motor rad/s)
| duty | ω_ss |
|---|---|
{ststr}

## Durum: **{status}**

## Not
ω motor-şaftı (EC 48 CPR, redüktör-bağımsız). HP/LP K oranı ≈ {K_V/53.89:.2f} (no-load hız oranı ~1.65 ile uyumlu).
Ölü-bölge KİNETİK (kick sonrası); STARTING stiction ~0.30 duty (ayrı, dead-band telafisi gerek).
MATLAB fit + plot: matlab/asama_3_mimo_model/ (Aşama-1 disipliniyle).
""")
meta = {"test_id": f"hp_stepid_{ts}", "timestamp": datetime.datetime.now().isoformat(timespec="seconds"),
        "commit": commit(), "status": status, "axis": 0, "driver": "HW-039/BTS7960", "gearbox": "20:1", "pwm_khz": 20,
        "key_metrics": {"Kg_duty": round(Kg,1), "K_V": round(K_V,2), "tau_ms": round(tau_est*1000,1),
                        "V_dead_duty": round(Vdead,3), "fit_r2": round(r2,3), "Kg_rev_over_fwd": round(Kg_rev/Kg,3)},
        "steady_state": [[round(dd,2), round(ww,1)] for dd, ww in ss],
        "artifacts": ["raw/data.csv"]}
json.dump(meta, open(f"{d}/meta.json", "w"), indent=2, ensure_ascii=False)
print(f"\nArtifact: {d}/  (status={status})")
ser.close()
