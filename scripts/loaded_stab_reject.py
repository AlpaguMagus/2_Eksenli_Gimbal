#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded STAB base-REDDİ testi (asıl hedef) — off-hanging tut + base eğ, stand sabit kalıyor mu?
Sen stand'ı off-hanging tut → STAB o açıyı yakalar (encoder reset = giriş tut) + FF açık (gravite+Coulomb,
yüklü değerler). Birak → tutar. Sonra SEN base'i yavaşça eğ. Stand eğik açıda KALIRSA = base reddi (stabilizasyon).
Base'le birlikte GİDERSE = reddetmiyor. YARGI: ham FP izi (giriş-rel sapma) + θ_out (kompanze etti mi).
Güvenlik: |FP|>80 -> STOP. Cikti: artifacts/5/loaded_stab_reject/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime, sys, atexit
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC=360.0/466.0; DUR=14.0
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
    except Exception: return "nogit"
ser=serial.Serial(PORT,BAUD,timeout=0.02); time.sleep(0.5); ser.reset_input_buffer()
def send(c): ser.write((c+"\n").encode()); ser.flush(); time.sleep(0.05)
def _safe_stop():
    try:
        if ser.is_open:
            ser.write(b"STOP\n"); ser.flush(); ser.close()
    except Exception:
        pass
atexit.register(_safe_stop)
FPr=re.compile(r"FP:(-?[\d.]+)"); ECr=re.compile(r"EC2:(-?\d+)"); Ur=re.compile(r"U2:(-?[\d.]+)")

print("=== Loaded STAB base-REDDİ testi ===")
print(">>> Stand'ı off-hanging (~35° eğik) TUT. STAB şimdi açıyı yakalayacak (FF açık: gravite+Coulomb).")
send("STOP"); send("STALLEN2:0"); send("STABDIR2:1"); send("LFF2:1"); send("KFF2:0")
ser.reset_input_buffer(); send("MODE2:STAB")
print(f">>> STAB AKTİF. ~2 sn say, YAVAŞÇA bırak (stand açıda kalır). SONRA base'i yavaşça EĞ. {DUR:.0f} sn.")
t0=time.time(); lp=0; lpr=0; T=[]; FP=[]; TH=[]; U=[]; FP0=None; stopped=False
while time.time()-t0<DUR:
    if time.time()-lp>0.2: send("PING"); lp=time.time()
    ln=ser.readline().decode("utf-8","replace").strip()
    if not ln.startswith("T_US"): continue
    mf=FPr.search(ln); me=ECr.search(ln); mu=Ur.search(ln)
    if not mf: continue
    fp=float(mf.group(1)); th=int(me.group(1))*LP_DPC if me else 0; u=float(mu.group(1)) if mu else 0
    if FP0 is None: FP0=fp
    T.append(time.time()-t0); FP.append(fp); TH.append(th); U.append(u)
    if abs(fp)>80 and not stopped: send("STOP"); stopped=True; print("  !! |FP|>80 GUVENLIK STOP")
    if time.time()-lpr>0.7:
        lpr=time.time(); print(f"   t={T[-1]:4.1f}  FP={fp:+6.1f} (giriş={FP0:+.0f}, sapma={fp-FP0:+5.1f})  θ_out={th:+6.1f}  duty={u:+.3f}")
send("STOP"); ser.close()
import statistics
if not FP or FP0 is None:
    print("!! UYARI: telemetri BOŞ — FP verisi yok (cihaz/port/MODE2 sorunu?). NO_DATA yazılıyor.")
    ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    d=f"artifacts/5/loaded_stab_reject/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
    json.dump({"test_id":"5.loaded-stab-reject","timestamp":ts,"commit":commit(),
        "status":"NO_DATA","key_metrics":{}},
        open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
    print(f"Artifact: {d}/")
    sys.exit(0)
dev=[f-FP0 for f in FP]; dmax=max(abs(x) for x in dev); dstd=statistics.stdev(FP) if len(FP)>1 else 0
thr=max(TH)-min(TH)   # θ_out base'i kompanze etmek için oynadı mı
print("\n"+"="*58)
print(f"  Giriş FP0={FP0:+.1f}°  FP sapma max={dmax:.1f}°  std={dstd:.1f}°")
print(f"  θ_out aralığı={thr:.1f}°  (base'i kompanze için motor oynadıysa BÜYÜK)")
# reddi: FP sabit (sapma küçük) AMA θ_out oynadı (kompanze) = gerçek reddi
verdict = ("[CONFOUND'lu metrik — kesin değil] REDDİ VAR? — FP sabit kaldı, θ_out oynadı (ama θ_out hareketi pasif gravite-creep/motor-drift ile ŞİŞER — gerçek reddi KANITI DEĞİL)" if dmax<12 and thr>8
           else "[CONFOUND'lu metrik — kesin değil] REDDİ ZAYIF/YOK? — FP base'le kaydı (θ_out kompanze etmedi)" if dmax>=12
           else "[CONFOUND'lu metrik — kesin değil] BELİRSİZ — base yeterince eğilmedi (θ_out az oynadı)")
print(f"  >>> {verdict}")
print("  (ASIL yargı SENİN gözün: base'i eğince stand açıda KALDI mı, base'le mi GİTTİ?)")
print("="*58)
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_stab_reject/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/reject.csv","w",newline="")); w.writerow(["t","fp","theta_out","u2"])
for t,fp,th,u in zip(T,FP,TH,U): w.writerow([f"{t:.3f}",f"{fp:.2f}",f"{th:.2f}",f"{u:.3f}"])
json.dump({"test_id":"5.loaded-stab-reject","timestamp":ts,"commit":commit(),
    "status":"INCONCLUSIVE",
    "key_metrics":{"fp0":round(FP0,1),"fp_dev_max":round(dmax,1),"fp_std":round(dstd,1),"theta_out_range":round(thr,1)}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 5.loaded-stab-reject — Yüklü STAB base-REDDİ testi

- **Test ID:** 5.loaded-stab-reject
- **Tarih:** {ts}
- **Commit:** {commit()}
- **Hedef:** Off-hanging tutulan stand'a STAB kilitlenip base eğilince stand açıda kalıyor mu (base reddi) ölçmek.
- **Komut:** `python3 scripts/loaded_stab_reject.py`

## Sonuç (sayısal)
| Metric | Değer |
|---|---|
| Giriş FP0 | {round(FP0,1)}° |
| FP sapma max | {round(dmax,1)}° |
| FP std | {round(dstd,1)}° |
| θ_out aralığı | {round(thr,1)}° |

## Durum / gerekçe
**status: INCONCLUSIVE** — Otomatik yargı CONFOUND'ludur: θ_out hareketi (theta_out_range) pasif
gravite-creep / motor-drift ile şişer, gerçek base-reddinin KANITI DEĞİL. Auto-verdict: {verdict}

> ⚠ ASIL yargı SENİN gözün: base'i eğince stand açıda KALDI mı, base'le mi GİTTİ?
> Kesin sonuç için OFF-vs-ON hızlı-bozucu (fast-disturbance) kıyası gerekir; bu tek-koşu kanıt değildir.

## Artifacts
- raw/reject.csv
""")
print(f"Artifact: {d}/")
