#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Loaded İNCE POS testi — Coulomb-FF ölü-bölgeyi geçiyor mu? (FF OFF vs ON, A/B).
Sistematik ID: + yön stiction ölü-bölgesi → küçük POS adımları FF'siz TAKILIR (ulaşamaz).
Coulomb-FF (kff_coul 0.09 / rev 0.05 + gravite 0.21) ölü-bölgeyi besleme-ileri geçer → küçük adımlar ulaşır.
Faz A: FF KAPALI -> küçük adım hatası (ölü-bölge). Faz B: FF AÇIK -> hata küçülmeli.
Motor kendi gider (küçük adımlar ±10°). Sen İZLE. Cikti: artifacts/5/loaded_fine_pos/<ts>/
"""
import serial, time, re, os, csv, json, subprocess, datetime, atexit
PORT, BAUD = "/dev/ttyACM0", 115200
LP_DPC=360.0/466.0
STEPS=[0, 5, 10, 5, 0, -5, -10, -5, 0]; HOLD=2.2
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
ECr=re.compile(r"EC2:(-?\d+)"); Ur=re.compile(r"U2:(-?[\d.]+)")

def run_phase(ff):
    lbl = "FF AÇIK (Coulomb+gravite)" if ff else "FF KAPALI (saf cascade)"
    print(f"\n>>> {lbl}: ince POS adımları (±10°), izle")
    send("STOP"); send("STALLEN2:0"); time.sleep(0.3)
    send("MODE2:POS"); send(f"LFF2:{1 if ff else 0}"); time.sleep(0.2); ser.reset_input_buffer()
    errs=[]; rows=[]
    for tg in STEPS:
        send(f"POS_DEG2:{tg}")
        t0=time.time(); lp=0; seg=[]
        while time.time()-t0<HOLD:
            if time.time()-lp>0.2: send("PING"); lp=time.time()
            ln=ser.readline().decode("utf-8","replace").strip()
            if not ln.startswith("T_US"): continue
            me=ECr.search(ln); mu=Ur.search(ln)
            if me: seg.append((time.time()-t0, int(me.group(1))*LP_DPC, float(mu.group(1)) if mu else 0))
        ss=[s for s in seg if s[0]>HOLD-0.8]
        th=sum(s[1] for s in ss)/len(ss) if ss else 0; u=sum(abs(s[2]) for s in ss)/len(ss) if ss else 0
        err=th-tg; errs.append(abs(err)); rows.append((1 if ff else 0,tg,round(th,1),round(err,1),round(u,3)))
        print(f"    hedef={tg:+3d}° -> ulaştı={th:+6.1f}° (hata {err:+5.1f})  |duty|={u:.3f}")
    send("POS_DEG2:0"); time.sleep(0.8); send("STOP")
    mae=sum(errs)/len(errs)
    print(f"    >>> ORTALAMA MUTLAK HATA = {mae:.1f}°")
    return mae, rows

print("=== Loaded İNCE POS testi: Coulomb-FF ölü-bölge geçiyor mu (FF OFF vs ON) ===")
mae_off, r_off = run_phase(False)
mae_on,  r_on  = run_phase(True)
send("STOP"); ser.close()
print("\n"+"="*56)
print(f"  FF KAPALI ortalama hata = {mae_off:.1f}°  (ölü-bölge → küçük adımlar takılır)")
print(f"  FF AÇIK   ortalama hata = {mae_on:.1f}°  (Coulomb-FF ölü-bölge geçer)")
imp = (1-mae_on/mae_off)*100 if mae_off>0.1 else 0
print(f"  >>> İYİLEŞME: %{imp:.0f}   {'COULOMB-FF ÖLÜ-BÖLGEYİ GEÇİYOR' if mae_on<mae_off*0.6 else 'belirgin fark yok — değer/yön ayarı gerek'}")
print("="*56)
ts=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
d=f"artifacts/5/loaded_fine_pos/{ts}"; os.makedirs(f"{d}/raw",exist_ok=True)
w=csv.writer(open(f"{d}/raw/finepos.csv","w",newline="")); w.writerow(["ff","tgt","theta_out","err","u2"])
for r in r_off+r_on: w.writerow(r)
status = "PASS" if (mae_off>0.1 and mae_on < mae_off*0.6) else "INCONCLUSIVE"
json.dump({"test_id":"5.loaded-fine-pos","timestamp":ts,"commit":commit(),"status":status,
    "key_metrics":{"mae_ff_off":round(mae_off,2),"mae_ff_on":round(mae_on,2),"improvement_pct":round(imp,0)}},
    open(f"{d}/meta.json","w"),ensure_ascii=False,indent=2)
with open(f"{d}/summary.md","w") as f:
    f.write(f"""# 5.loaded-fine-pos — Yüklü ince POS: Coulomb-FF ölü-bölge geçiyor mu?

- **Test ID:** 5.loaded-fine-pos
- **Tarih:** {ts}
- **Commit:** {commit()}
- **Hedef:** Yüklü LP ekseninde küçük POS adımlarında (±10°) Coulomb-FF'in stiction ölü-bölgesini geçip geçmediğini FF OFF vs ON kıyasıyla ölç.
- **Komut:** `python3 scripts/loaded_fine_pos_test.py`

## Sonuç (sayısal)
| Metric | Değer |
|---|---|
| mae_ff_off | {mae_off:.2f}° |
| mae_ff_on | {mae_on:.2f}° |
| improvement_pct | %{imp:.0f} |
| status | {status} |

## Durum / gerekçe
{status} — PASS ölçütü: mae_off>0.1 ve mae_on < mae_off*0.6 (FF açıkken ortalama mutlak hata, FF kapalıya göre en az %40 düşmeli). FF KAPALI hata {mae_off:.1f}°, FF AÇIK hata {mae_on:.1f}°.

## Artifacts
- raw/finepos.csv
""")
print(f"Artifact: {d}/")
