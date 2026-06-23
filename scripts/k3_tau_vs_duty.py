#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""K3 keşif — HP τ-vs-duty: gain scheduling GEREKLİ mi?

Farklı çalışma-noktalarında (base duty) küçük step → τ63 ölç. τ duty ile belirgin değişiyorsa K3
(gain scheduling) gerekçeli; ~sabitse tek-kazanç yeterli. Aşama-1 NRMSE U-eğrisi (43→134ms) duty-bağımlılık
sezdirmişti — bu rijit-mengene doğrudan testi. HP, OMEGA (rad/s), DUTYR. Çıktı: artifacts/3/k3_tau_duty/<ts>/
"""
import serial, time, re, os, json, subprocess, datetime

PORT, BAUD = "/dev/ttyACM0", 115200
BASES = [0.15, 0.25, 0.35, 0.45]
STEP = 0.05

def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"

ser = serial.Serial(PORT, BAUD, timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush()
Or = re.compile(r"OMEGA:(-?[\d.]+)")

def collect(duty, secs):
    rows=[]; t0=time.time(); lp=0.0
    while time.time()-t0 < secs:
        if time.time()-lp>0.10: send(f"DUTYR:{duty}"); send("PING"); lp=time.time()
        line=ser.readline().decode("utf-8","replace").strip()
        if line.startswith("T_US"):
            m=Or.search(line)
            if m: rows.append((time.time()-t0, abs(float(m.group(1)))))
    return rows

def steady(rows, frac=0.4):
    if len(rows)<4: return None
    n=max(3,int(len(rows)*frac)); return sum(v for _,v in rows[-n:])/n

def tau_at(base):
    send(f"DUTYR:{0.45}"); t=time.time()
    while time.time()-t<0.8: send("DUTYR:0.45"); send("PING"); time.sleep(0.1)
    b=collect(base, 1.2); bw=steady(b)
    s=collect(base+STEP, 1.4); nw=steady(s)
    # smooth + 63% crossing
    sm=[]
    for i in range(len(s)):
        a=max(0,i-2); seg=[s[k][1] for k in range(a,min(len(s),i+3))]; sm.append((s[i][0],sum(seg)/len(seg)))
    tau=None
    if bw and nw and nw>bw:
        tgt=bw+0.632*(nw-bw)
        for tt,ww in sm:
            if ww>=tgt: tau=tt; break
    return bw, nw, tau

print("="*60); print(" K3 — HP τ-vs-duty (gain scheduling gerekli mi?)"); print("="*60)
send("STOP"); time.sleep(0.3); send("MODE:DUTY"); time.sleep(0.2); send("STALLEN:0"); time.sleep(0.2)
res=[]
for base in BASES:
    bw,nw,tau = tau_at(base)
    res.append({"base":base,"bw":round(bw,1) if bw else None,"nw":round(nw,1) if nw else None,
                "tau_ms":round(tau*1000,1) if tau else None})
    print(f"   base={base:.2f}→{base+STEP:.2f}  ω {bw:.0f}→{nw:.0f} rad/s  τ63={tau*1000:.0f}ms" if tau else f"   base={base:.2f}  τ ölçülemedi")
send("DUTYR:0.0"); send("STOP"); ser.close()

taus=[r["tau_ms"] for r in res if r["tau_ms"]]
spread = (max(taus)-min(taus)) if taus else 0
ratio = (max(taus)/min(taus)) if (taus and min(taus)>0) else 0
verdict = "K3 GEREKÇELİ (τ duty ile belirgin değişiyor)" if ratio>1.5 else "tek-kazanç YETERLİ (τ ~sabit) → K3 gereksiz"
print("\n"+"="*60)
print(f"  τ aralığı: {min(taus) if taus else '?'}–{max(taus) if taus else '?'} ms  (oran {ratio:.2f}×)")
print(f"  → {verdict}")
print("="*60)

ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/3/k3_tau_duty/{ts}"; os.makedirs(d,exist_ok=True)
json.dump({"test_id":"3.K3-tau-duty","timestamp":ts,"commit":commit(),"status":"DONE",
    "key_metrics":{"points":res,"tau_spread_ms":round(spread,1),"tau_ratio":round(ratio,2),"verdict":verdict}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 3.K3-tau-duty — HP τ-vs-duty (gain scheduling gerekli mi?)

- **Tarih:** {ts} · **Commit:** {commit()} · **Hüküm:** {verdict}
- **Hedef:** HP τ farklı çalışma-noktalarında değişiyor mu → K3 (gain scheduling) gerekçeli mi.
- **Donanım:** HP serbest mil, mengeneli, loop 8ms.

## Sonuç
| base→step | ω (rad/s) | τ63 (ms) |
|---|---|---|
""")
    for r in res:
        f.write(f"| {r['base']:.2f}→{r['base']+STEP:.2f} | {r['bw']}→{r['nw']} | {r['tau_ms']} |\n")
    f.write(f"""
- τ aralığı: {min(taus) if taus else '?'}–{max(taus) if taus else '?'} ms (oran {ratio:.2f}×)
- **Hüküm:** {verdict}

## Yorum
τ ~sabitse tek-kazanç cascade tüm çalışma-aralığında yeterli (K3 gereksiz). Belirgin değişiyorsa çalışma-
noktası kazanç tablosu (K3). Bu rijit-mengene ölçümü Aşama-1 U-eğrisi sezgisini doğrudan test eder.

## Üreten: `scripts/k3_tau_vs_duty.py`
""")
print(f"Artifact: {d}/")
