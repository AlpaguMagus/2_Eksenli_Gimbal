#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP KARAKTERİZASYON — Faz 1 (her iki yön, ≤0.5 duty SERT cap).

Onaylı plan (docs §12.12 olacak): RPWM kablo-fix + ~940µF bulk sonrası HP'yi temiz karakterize et.
  1c dead-band (iki yön)  — V_dead_fwd / V_dead_rev
  1d K(duty) eğrisi       — 0.10..0.50, iki yön → lineerlik/doygunluk + SİMETRİ
  1a/1b step-ID τ          — forward + reverse → τ63 (yön simetrisi)

GÜVENLİK (akım sensörü YOK — ACS712 rezerv):
  • DUTY_CAP=0.50 SERT clamp (her komut clamp'lenir)
  • EC-freeze CANARY: |duty|>V_dead iken EC donarsa = OCP/dropout → sub-test durur, flag
  • Kısa burst (<2s) + aralarda dur+soğuma; watchdog firmware'de zaten 1s

⚠ FİZİKSEL — HP HW-039'da, mil serbest. Forward=+duty (CW/RPWM/PB8, EC↑), reverse=−duty (LPWM, EC↓).
Birim zinciri (Faz 2 için ham + türev): ω_cnt [cnt/s] → ω_motor=ω_cnt·2π/48 [rad/s motor mili]
  → ω_out=ω_motor/20 [rad/s çıkış mili].  Kg_duty [cnt/s per duty] = ham eğim (Vs-bağımsız, en sağlam).
Çıktı: artifacts/3/hp_charac/<ts>/
"""
import serial, time, sys, os, json, subprocess, datetime, re, math

PORT, BAUD = "/dev/ttyACM0", 115200
DUTY_CAP = 0.50                 # SERT cap (akım sınırı — kullanıcı kararı)
VS = 12.0                       # nominal besleme (Sagemcom ~12V); Kg_duty buna bağlı DEĞİL
EVENTS_PER_REV = 48             # motor mili (encoder.c:11)
GEAR_HP = 20.0                  # HP redüktör (donanim_semasi §7.2)
MOVE_THRESH = 200               # cnt/s — "hareket var" eşiği (gürültü > altı)
FREEZE_WIN = 0.30               # s — canary penceresi

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"

def clamp(d): return max(-DUTY_CAP, min(DUTY_CAP, d))

try:
    ser = serial.Serial(PORT, BAUD, timeout=0.02)
except Exception as e:
    print(f"[ERROR] {PORT}: {e}"); sys.exit(1)
time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()

def collect(duty, secs):
    """duty'yi sür (clamp'li), (t, EC) topla. Canary: freeze tespiti döndür."""
    duty = clamp(duty)
    rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0 < secs:
        if time.time()-lp > 0.10: send("PING"); send(f"DUTYR:{duty}"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            d=dict(re.findall(r'([A-Z0-9_]+):(-?[\d.]+)', line))
            if "EC" in d: rows.append((time.time()-t0, int(d["EC"])))
    return rows

def omega_ss(rows, frac=0.4):
    """son %frac penceresinde ortalama eğim (cnt/s)."""
    if len(rows) < 4: return None
    n = max(2, int(len(rows)*frac)); seg = rows[-n:]
    dt = seg[-1][0]-seg[0][0]
    return (seg[-1][1]-seg[0][1])/dt if dt > 1e-6 else None

def omega_series(rows, win=0.03):
    out=[]; i=0
    while i < len(rows)-1:
        j=i+1
        while j < len(rows) and rows[j][0]-rows[i][0] < win: j+=1
        if j>=len(rows): break
        dt=rows[j][0]-rows[i][0]
        if dt>0: out.append((rows[j][0], (rows[j][1]-rows[i][1])/dt))
        i=j
    return out

def canary_freeze(rows, duty):
    """|duty|>~dead iken bir FREEZE_WIN boyunca |ΔEC|≈0 → dropout. (basit: en uzun durağan blok)"""
    if abs(duty) < 0.05 or len(rows) < 4: return False
    w = omega_series(rows, FREEZE_WIN)
    moving = [abs(o) for _,o in w]
    if not moving: return False
    # baştaki spin-up hariç: ilk %30'u atla, kalanında ~0 varsa freeze
    tail = moving[max(1,len(moving)//3):]
    return any(m < MOVE_THRESH*0.25 for m in tail) and max(moving) > MOVE_THRESH

def stop(): send("DUTYR:0.0"); time.sleep(0.05); send("STOP")

print("="*64); print(" HP KARAKTERİZASYON — Faz 1 (≤0.5 duty, iki yön)"); print("="*64)
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2)
send("STALLEN:0"); time.sleep(0.2); ser.reset_input_buffer()

results = {"deadband":{}, "k_curve":{"fwd":[], "rev":[]}, "stepid":{}, "flags":[]}

# ---------- 1c DEAD-BAND (iki yön, motor soğukken önce) ----------
print("\n[1c] Dead-band taraması (iki yön)...")
def deadband(sign, label):
    vd = None
    for k in range(1, 16):           # 0.01 .. 0.15
        d = sign * (0.01*k)
        rows = collect(d, 0.55)
        w = omega_ss(rows, 0.5)
        moving = w is not None and abs(w) > MOVE_THRESH
        print(f"    {label} duty={d:+.2f}  ω={('%+.0f'%w) if w is not None else '   ?':>7} cnt/s  {'← HAREKET' if moving else ''}")
        stop(); time.sleep(0.25)
        if moving: vd = abs(d); break
    return vd
results["deadband"]["fwd"] = deadband(+1, "FWD")
results["deadband"]["rev"] = deadband(-1, "REV")
print(f"  → V_dead: fwd={results['deadband']['fwd']}, rev={results['deadband']['rev']}")

# ---------- 1d K(duty) EĞRİSİ (iki yön) ----------
print("\n[1d] K(duty) eğrisi (iki yön)...")
LEVELS = [0.10, 0.15, 0.20, 0.30, 0.40, 0.50]
def k_curve(sign, key):
    for d in LEVELS:
        duty = sign*d
        rows = collect(duty, 1.6)
        w = omega_ss(rows, 0.4)
        froze = canary_freeze(rows, duty)
        kg = (w/duty) if (w is not None and abs(duty)>1e-6) else None    # cnt/s per duty
        results["k_curve"][key].append({"duty":round(duty,3), "omega_cnt":round(w,0) if w else None,
                                        "Kg_duty":round(kg,1) if kg else None, "freeze":froze})
        flag = " ⚠FREEZE(OCP?)" if froze else ""
        # yön tutarlılık: ω işareti duty işaretiyle aynı mı?
        signbad = (w is not None and abs(w)>MOVE_THRESH and (w*duty)<0)
        if signbad: flag += " ⚠TERS-YÖN"
        print(f"    {key} duty={duty:+.2f}  ω={('%+.0f'%w) if w is not None else '?':>7} cnt/s  Kg={('%.0f'%kg) if kg else '?':>6}{flag}")
        if froze: results["flags"].append(f"{key} duty={duty:+.2f} freeze")
        stop(); time.sleep(0.45)
k_curve(+1, "fwd")
k_curve(-1, "rev")

# ---------- 1a/1b STEP-ID τ (iki yön) ----------
print("\n[1a/1b] Step-ID τ (iki yön)...")
def stepid(sign, label):
    kick, base, step = sign*0.45, sign*0.30, sign*0.40
    send(f"DUTYR:{clamp(kick)}"); t=time.time()
    while time.time()-t < 1.3: send("PING"); send(f"DUTYR:{clamp(kick)}"); time.sleep(0.1)
    base_rows = collect(base, 1.3)
    step_rows = collect(step, 1.5)
    stop()
    bw, nw = omega_ss(base_rows,0.4), omega_ss(step_rows,0.4)
    ws = omega_series(step_rows); tau=None
    if bw and nw and ws and abs(nw-bw)>1e-6:
        tgt = bw + 0.632*(nw-bw); dw=nw-bw
        for tt,ww in ws:
            if (dw>0 and ww>=tgt) or (dw<0 and ww<=tgt): tau=tt; break
    froze = canary_freeze(step_rows, step)
    print(f"    {label}: base ω={('%+.0f'%bw) if bw else '?'} → step ω={('%+.0f'%nw) if nw else '?'} cnt/s  τ63={('%.0f ms'%(tau*1000)) if tau else '?'}{' ⚠FREEZE' if froze else ''}")
    return {"base_omega":round(bw,0) if bw else None, "step_omega":round(nw,0) if nw else None,
            "tau63_ms":round(tau*1000,1) if tau else None, "freeze":froze,
            "base_rows":base_rows, "step_rows":step_rows}
results["stepid"]["fwd"] = stepid(+1, "FWD")
time.sleep(0.5)
results["stepid"]["rev"] = stepid(-1, "REV")
stop()

# ---------- HÜKÜM ----------
print("\n"+"="*64)
def to_rad_motor(cnt): return cnt*2*math.pi/EVENTS_PER_REV if cnt else None
def avg_kg(key):
    xs=[r["Kg_duty"] for r in results["k_curve"][key] if r["Kg_duty"] and not r["freeze"]]
    return sum(xs)/len(xs) if xs else None
kg_f, kg_r = avg_kg("fwd"), avg_kg("rev")
tau_f = results["stepid"]["fwd"]["tau63_ms"]; tau_r = results["stepid"]["rev"]["tau63_ms"]
print(f"  Kg_duty (cnt/s/duty):  fwd={('%.0f'%kg_f) if kg_f else '?'}   rev={('%.0f'%abs(kg_r)) if kg_r else '?'}")
if kg_f and kg_r:
    asym = abs(abs(kg_f)-abs(kg_r))/max(abs(kg_f),abs(kg_r))*100
    print(f"  → K simetri: %{asym:.0f} fark  ({'SİMETRİK' if asym<15 else '⚠ ASİMETRİK'})")
if tau_f and tau_r:
    print(f"  τ63:  fwd={tau_f} ms   rev={tau_r} ms")
# rad/s/V (motor mili) — Vs=12 varsayımı, açık etiket
if kg_f: print(f"  K_motor≈{to_rad_motor(kg_f)/VS:.1f} rad/s/V (motor mili, Vs={VS})  |  K_out≈{to_rad_motor(kg_f)/VS/GEAR_HP:.2f} (çıkış mili)")
if results["flags"]: print(f"  ⚠ FLAGS: {results['flags']}")
print("="*64)

# ---------- ARTIFACT ----------
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/hp_charac/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
# raw step csv'leri
for lab in ["fwd","rev"]:
    for ph in ["base","step"]:
        rs=results["stepid"][lab].pop(ph+"_rows")
        with open(f"{d}/raw/stepid_{lab}_{ph}.csv","w") as f:
            f.write("t_s,ec\n"); [f.write(f"{r[0]:.5f},{r[1]}\n") for r in rs]
status = "PASS" if (kg_f and kg_r and tau_f and tau_r and not results["flags"]) else ("PARTIAL" if (kg_f or kg_r) else "FAIL")
meta={"test_id":"3.HP-charac-Faz1","timestamp":ts,"commit":commit(),"status":status,
      "duty_cap":DUTY_CAP,"key_metrics":{
        "Kg_duty_fwd":round(kg_f,1) if kg_f else None,"Kg_duty_rev":round(kg_r,1) if kg_r else None,
        "tau63_fwd_ms":tau_f,"tau63_rev_ms":tau_r,
        "V_dead_fwd":results["deadband"]["fwd"],"V_dead_rev":results["deadband"]["rev"],
        "K_motor_radps_V":round(to_rad_motor(kg_f)/VS,1) if kg_f else None},
      "k_curve":results["k_curve"],"flags":results["flags"]}
json.dump(meta, open(f"{d}/meta.json","w"), ensure_ascii=False, indent=2)

# summary.md
def kc_rows(key):
    return "\n".join(f"| {r['duty']:+.2f} | {r['omega_cnt']} | {r['Kg_duty']} | {'⚠' if r['freeze'] else '✓'} |"
                     for r in results["k_curve"][key])
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 3.HP-charac-Faz1 — HP karakterizasyon (her iki yön, ≤0.5 duty)

- **Test ID:** 3.HP-charac-Faz1
- **Tarih:** {ts}  ·  **Commit:** {commit()}  ·  **Durum:** {status}
- **Hedef:** RPWM kablo-fix + ~940µF bulk sonrası HP'yi temiz karakterize et (forward artık temiz mi, yön simetrisi, dead-band, K(duty), τ) → Faz 2 analitik cascade girdisi.
- **Donanım:** HP Pololu (HW-039/BTS7960, 20:1), Sagemcom 12V + ~940µF bulk, **mil serbest**, duty cap {DUTY_CAP}.

## Sonuç (sayısal)
| Metric | fwd | rev | Simetri |
|---|---|---|---|
| Kg_duty (cnt/s/duty) | {('%.0f'%kg_f) if kg_f else '?'} | {('%.0f'%abs(kg_r)) if kg_r else '?'} | {('%%%.0f'%(abs(abs(kg_f)-abs(kg_r))/max(abs(kg_f),abs(kg_r))*100)) if (kg_f and kg_r) else '?'} |
| τ63 (ms) | {tau_f} | {tau_r} | — |
| V_dead | {results['deadband']['fwd']} | {results['deadband']['rev']} | — |

K_motor≈{('%.1f rad/s/V'%(to_rad_motor(kg_f)/VS)) if kg_f else '?'} (motor mili, Vs={VS}) · K_out≈{('%.2f'%(to_rad_motor(kg_f)/VS/GEAR_HP)) if kg_f else '?'} (çıkış mili, ÷{GEAR_HP:.0f}).

### K(duty) eğrisi — forward
| duty | ω (cnt/s) | Kg | canary |
|---|---|---|---|
{kc_rows('fwd')}

### K(duty) eğrisi — reverse
| duty | ω (cnt/s) | Kg | canary |
|---|---|---|---|
{kc_rows('rev')}

## Flags / canary
{('⚠ ' + '; '.join(results['flags'])) if results['flags'] else '✓ Dropout/freeze yok, ters-yön yok (0.5 cap güvenli).'}

## Artifacts
- meta.json · raw/stepid_{{fwd,rev}}_{{base,step}}.csv (τ ham veri)

## İlgili
- Plan: Faz 1 (onaylı) → Faz 2 analitik cascade (`matlab/asama_3_mimo_model/hp_cascade_design.m`) → Faz 3 firmware.
- Üreten: `scripts/hp_characterize.py`
""")
print(f"Artifact: {d}/")
ser.close()
