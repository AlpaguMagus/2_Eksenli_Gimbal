#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP FF deneyi (Madde 3) — pozisyon cascade'de Coulomb-FF, HP'nin ss_err'ini azaltıyor mu?

K1'de HP 2/6 (hedefi ~6° aşıp stiction-hold). §12.13.4: yön-bağımlı FF limit-cycle'ı ÇÖZMEDİ — ama o
LIMIT-CYCLE içindi; bu test STATİK-OFFSET'e (stiction near-target küçük düzeltmeyi kıramıyor) FF etkisini ölçer.
⚠ Serbest mil → GRAVİTE-FF KAPATILIR (LFFG:0; HP kff_grav=0.097 LP-placeholder, serbest-milde yanlış tork).
Yalnız Coulomb-FF (0.14 fwd/0.20 rev) açılır. FF-OFF vs FF-ON ss_err + θ_std kıyas.
θ_hp=EC×360/960. Çıktı: artifacts/3/hp_ff_compare/<ts>/
"""
import serial, time, re, os, json, subprocess, datetime

PORT, BAUD = "/dev/ttyACM0", 115200
HP_DPC = 360.0/960.0
TARGETS = [30, 90, -45, 60, 0]
HOLD = 3.5

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
def mean(x): return sum(x)/len(x) if x else 0.0
def std(x):
    if len(x)<2: return 0.0
    m=mean(x); return (sum((v-m)**2 for v in x)/len(x))**0.5

ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
ECr=re.compile(r"EC:(-?\d+)")

def seg(target):
    send(f"POS_DEG:{target}"); t0=time.time(); lp=0; th=[]
    while time.time()-t0<HOLD:
        if time.time()-lp>0.2: send("PING"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            m=ECr.search(line)
            if m: th.append((time.time()-t0, int(m.group(1))*HP_DPC))
    ss=[v for t,v in th if t>HOLD-1.2]
    return {"ss":mean(ss),"err":abs(mean(ss)-target),"std":std(ss)}

def run_pass(ff_on, label):
    print(f"\n=== {label} ===")
    send("STOP"); time.sleep(0.3); send("MODE:POS"); time.sleep(0.15); send("STALLEN:0"); time.sleep(0.2)
    if ff_on:
        send("LFFG:0"); time.sleep(0.1)     # serbest mil → gravite-FF KAPAT (placeholder yanlış)
        send("LFF:1");  time.sleep(0.1)      # Coulomb-FF AÇ (0.14/0.20)
    else:
        send("LFF:0");  time.sleep(0.1)
    ser.reset_input_buffer()
    out=[]
    for tg in TARGETS:
        m=seg(tg); out.append((tg,m))
        print(f"   HP→{tg:+d}°  θ_ss={m['ss']:+6.2f}°  err={m['err']:.2f}°  std={m['std']:.2f}°")
    send("POS_DEG:0"); send("LFF:0"); time.sleep(0.4)
    return out

print("="*64); print(" HP FF DENEYİ — Coulomb-FF ss_err'i azaltıyor mu (serbest mil, gravite-FF kapalı)"); print("="*64)
off = run_pass(False, "FF-OFF (baseline)")
on  = run_pass(True,  "FF-ON (Coulomb 0.14/0.20, gravite kapalı)")
send("STOP"); ser.close()

print("\n"+"="*64); print(" KIYAS (FF-OFF → FF-ON)")
rows=[]
for (tg,mo),(_,mn) in zip(off,on):
    d_err=mn["err"]-mo["err"]; verdict = "↓ iyileşti" if d_err<-0.5 else ("↑ kötüleşti" if d_err>0.5 else "≈ aynı")
    print(f"   HP→{tg:+d}°  err {mo['err']:.2f}→{mn['err']:.2f}  ({d_err:+.2f})  std {mo['std']:.2f}→{mn['std']:.2f}  {verdict}")
    rows.append({"tgt":tg,"err_off":round(mo["err"],2),"err_on":round(mn["err"],2),
                 "std_off":round(mo["std"],2),"std_on":round(mn["std"],2)})
err_off=mean([mo["err"] for _,mo in off]); err_on=mean([mn["err"] for _,mn in on])
print(f"\n   ORTALAMA ss_err: FF-OFF {err_off:.2f}° → FF-ON {err_on:.2f}°  ({err_on-err_off:+.2f}°)")
hukum = "Coulomb-FF HP statik-offset'i AZALTIYOR" if err_on<err_off-0.5 else \
        ("FF FARK ETMEDİ (residual yapısal, K7)" if abs(err_on-err_off)<=0.5 else "FF KÖTÜLEŞTİRDİ")
print(f"   → HÜKÜM: {hukum}")
print("="*64)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/hp_ff_compare/{ts}"; os.makedirs(d,exist_ok=True)
json.dump({"test_id":"3.HP-FF-compare","timestamp":ts,"commit":commit(),
    "status":"DONE","key_metrics":{"err_off_avg":round(err_off,2),"err_on_avg":round(err_on,2),
        "delta":round(err_on-err_off,2),"verdict":hukum,"segments":rows}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 3.HP-FF-compare — Coulomb-FF HP statik-offset'i azaltıyor mu

- **Tarih:** {ts} · **Commit:** {commit()} · **Hüküm:** {hukum}
- **Hedef:** K1'de HP 2/6 (hedefi ~6° aşıp stiction-hold). Coulomb-FF (yön-bağımlı 0.14/0.20) bu STATİK offset'i azaltır mı? (§12.13.4 FF'i limit-cycle için denemişti.)
- **Donanım:** HP serbest mil, mengeneli. ⚠ Gravite-FF KAPALI (LFFG:0; kff_grav=0.097 LP-placeholder serbest-milde yanlış). Yalnız Coulomb-FF.

## Sonuç
| HP hedef | err OFF | err ON | Δ | std OFF | std ON |
|---|---|---|---|---|---|
""")
    for r in rows:
        f.write(f"| {r['tgt']:+d}° | {r['err_off']}° | {r['err_on']}° | {r['err_on']-r['err_off']:+.2f}° | {r['std_off']}° | {r['std_on']}° |\n")
    f.write(f"""
- **Ortalama ss_err:** FF-OFF {err_off:.2f}° → FF-ON {err_on:.2f}° ({err_on-err_off:+.2f}°)
- **Hüküm:** {hukum}

## Yorum
§12.13.4 FF'i LIMIT-CYCLE için denedi (çözmedi). Bu test STATİK-OFFSET'e etkisini ayırır. {'Coulomb-FF near-target stiction kırmaya yardım edip ss_err düşürdü' if err_on<err_off-0.5 else 'FF statik-offset'+chr(39)+'i de düzeltmedi → residual yapısal, temiz fix K7 (Kalman)'}.

## Üreten: `scripts/hp_ff_compare.py`
""")
print(f"Artifact: {d}/")
