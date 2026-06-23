#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HP sürekli-takip testi (Faz 3b) — stick-slip sürekli harekette baypas oluyor mu?

ANALİTİK ÖNGÖRÜ (deneyden ÖNCE, §12.12.5 dersi): stick-slip motor DURUNCA olur; sürekli
takipte motor durmazsa lurch yok (kinetik sürtünmeyi PI sürekli halleder). Takip hızı ölçülü
(sinüs A=40°/f=0.2Hz → tepe 50°/s → 32ms loop'ta 1.6°, kontrol edilebilir; breakaway lurch
573°/s'in aksine). → Pürüzsüz takip BEKLENİR, yalnız hız-tersinme (tepe, v=0) noktalarında kısa
takılma olabilir. Bu test öngörüyü DOĞRULAR/ÇÜRÜTÜR.

Referans: θ_ref(t) = A·sin(2πft) — POS_DEG ~25Hz güncellenir (sürekli hareketli hedef). FF YOK
(§12.12.4: bipolar sign-FF limit-cycle pompalıyor). Gerçek STAB için proxy (IMU yerine sentetik
ref → senin elin gerekmez; gerçek STAB base-tilt sonra).
⚠ FİZİKSEL — HP HW-039, mil serbest, duty ±0.5 cap. Çıktı: artifacts/3/hp_track/<ts>/
"""
import argparse, csv, math, os, re, subprocess, sys, time, datetime as dt
import serial

EC_RE=re.compile(r",EC:(-?\d+)"); OM_RE=re.compile(r",OMEGA:(-?[\d.]+)")
U_RE=re.compile(r",U:(-?[\d.]+)"); SP_RE=re.compile(r",SP:(-?[\d.]+)")
CPR=960.0; DPC=360.0/CPR
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "?"
def send(ser,c): ser.write((c+"\n").encode())
def mean(x): return sum(x)/len(x) if x else 0.0
def rms(x): return (sum(v*v for v in x)/len(x))**0.5 if x else 0.0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--port",default="/dev/ttyACM0"); ap.add_argument("--amp",type=float,default=40.0)
    ap.add_argument("--freq",type=float,default=0.2); ap.add_argument("--dur",type=float,default=20.0)
    ap.add_argument("--kpp",type=float,default=2.0)
    a=ap.parse_args()
    vpk=a.amp*2*math.pi*a.freq
    print(f"HP sürekli-takip: sinüs A={a.amp}° f={a.freq}Hz → tepe hız {vpk:.0f}°/s, {a.dur:.0f}s. DOKUNMA (mil serbest).")
    try: ser=serial.Serial(a.port,115200,timeout=0.05)
    except serial.SerialException as e: print(f"[ERR] {e}"); return 2
    out=os.path.join("artifacts","3","hp_track",dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
    os.makedirs(os.path.join(out,"raw"),exist_ok=True)
    rows=[]
    try:
        ser.reset_input_buffer(); send(ser,"PING"); time.sleep(0.3)
        send(ser,"MODE:POS"); time.sleep(0.1); send(ser,f"KPP:{a.kpp}"); time.sleep(0.05)
        send(ser,"LFF:0"); time.sleep(0.05)   # FF KAPALI (§12.12.4)
        ser.reset_input_buffer()
        t0=time.time(); last_ref=0.0; last_p=0.0
        while time.time()-t0 < a.dur:
            now=time.time(); t=now-t0
            if now-last_ref>0.04:    # ~25Hz ref güncelle
                ref=a.amp*math.sin(2*math.pi*a.freq*t); send(ser,f"POS_DEG:{ref:.2f}"); last_ref=now
            line=ser.readline().decode("utf-8","ignore").strip()
            mec=EC_RE.search(line)
            if not mec: continue
            theta=int(mec.group(1))*DPC
            mo=OM_RE.search(line); mu=U_RE.search(line)
            om=float(mo.group(1)) if mo else 0.0; u=float(mu.group(1)) if mu else 0.0
            ref=a.amp*math.sin(2*math.pi*a.freq*t)
            rows.append((t,ref,theta,om,u))
            if now-last_p>0.5:
                print(f"  t={t:4.1f}s ref={ref:+6.1f}° θ={theta:+6.1f}° err={theta-ref:+5.1f}° ω={om:+6.0f} u={u:+.3f}"); last_p=now
        send(ser,"STOP"); send(ser,"MODE:DUTY")
    finally:
        try: ser.write(b"STOP\nMODE:DUTY\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    # metrikler — başlangıç geçici (ilk %15) atla
    n0=int(len(rows)*0.15); seg=rows[n0:]
    errs=[r[2]-r[1] for r in seg]
    rms_e=rms(errs); max_e=max(abs(e) for e in errs) if errs else 0
    # stick-slip dedektörü: |ref hızı| anlamlıyken motor durmuş (|ω|<20) fraksiyonu
    stuck=0; movecmd=0
    for i in range(1,len(seg)):
        dref=abs(seg[i][1]-seg[i-1][1])/max(1e-3,seg[i][0]-seg[i-1][0])  # °/s ref hızı
        if dref>10:   # ref anlamlı hareket emrediyor
            movecmd+=1
            if abs(seg[i][3])<20: stuck+=1
        # lurch dedektörü: |ω| spike (>150 rad/s, breakaway imzası)
    lurch=sum(1 for r in seg if abs(r[3])>150)
    stuck_frac=stuck/movecmd if movecmd else 0
    smooth = stuck_frac<0.15 and lurch<len(seg)*0.02 and max_e<a.amp*0.5
    verdict = "PÜRÜZSÜZ — sürekli takip stick-slip'i BAYPAS ediyor (öngörü doğrulandı)" if smooth else \
              "STICK-SLIP DEVAM — sürekli takipte de takılıyor (öngörü çürüdü → loop-rate fix gerek)"
    print("\n"+"="*60)
    print(f"  RMS takip hatası = {rms_e:.1f}°   max = {max_e:.1f}°  (genlik {a.amp}°)")
    print(f"  stuck-fraksiyon (ref hareketliyken ω≈0) = %{stuck_frac*100:.0f}   lurch-spike = {lurch}")
    print(f"  → {verdict}")
    print("="*60)

    # plot + artifact
    plot=None
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        tg=[r[0] for r in rows]
        f,ax=plt.subplots(3,1,figsize=(11,8),sharex=True)
        ax[0].plot(tg,[r[1] for r in rows],'r--',lw=1.1,label='ref'); ax[0].plot(tg,[r[2] for r in rows],'b',lw=1.3,label='θ ölçülen')
        ax[0].set_ylabel('θ (°)'); ax[0].legend(); ax[0].grid(alpha=0.3)
        ax[0].set_title(f'HP sürekli-takip — sinüs A={a.amp}° f={a.freq}Hz (FF kapalı)')
        ax[1].plot(tg,[r[2]-r[1] for r in rows],'m',lw=1.0); ax[1].set_ylabel('takip hatası (°)'); ax[1].grid(alpha=0.3)
        ax[2].plot(tg,[r[4] for r in rows],'k',lw=0.8); ax[2].axhline(0.5,ls=':',c='r'); ax[2].axhline(-0.5,ls=':',c='r')
        ax[2].set_ylabel('duty u'); ax[2].set_xlabel('t (s)'); ax[2].set_ylim(-0.58,0.58); ax[2].grid(alpha=0.3)
        f.tight_layout(); plot=os.path.join(out,"hp_track_plot.png"); f.savefig(plot,dpi=130); plt.close(f)
    except Exception as e: print(f"[plot skip] {e}")
    with open(os.path.join(out,"raw","data.csv"),"w",newline="") as fh:
        w=csv.writer(fh); w.writerow(["t","ref","theta","omega","u"]); w.writerows(rows)
    status="PASS" if smooth else "STICK_SLIP"
    import json
    json.dump({"test_id":"3.HP-track-sin","timestamp":dt.datetime.now().isoformat(timespec="seconds"),
        "commit":commit(),"status":status,"amp_deg":a.amp,"freq_hz":a.freq,"kpp":a.kpp,"ff":False,
        "key_metrics":{"rms_err_deg":round(rms_e,2),"max_err_deg":round(max_e,2),
            "stuck_frac":round(stuck_frac,3),"lurch_spikes":lurch,"peak_vel_degps":round(vpk,1)}},
        open(os.path.join(out,"meta.json"),"w"),ensure_ascii=False,indent=2)
    with open(os.path.join(out,"summary.md"),"w") as f:
        f.write(f"""# Faz 3b — HP sürekli-takip (sinüs, stick-slip baypas testi)

- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M} · **Commit:** `{commit()}` · **Durum:** {status}
- **Hipotez:** sürekli hareket stick-slip'i baypas eder (§12.12.5 öngörüsü). FF KAPALI, mil serbest.
- **Referans:** sinüs A={a.amp}° f={a.freq}Hz (tepe {vpk:.0f}°/s) · Kp_pos={a.kpp} · cpr=960

## Sonuç
| Metrik | Değer | Yorum |
|---|---|---|
| RMS takip hatası | {rms_e:.1f}° | genlik {a.amp}° |
| max hata | {max_e:.1f}° | |
| stuck-fraksiyon | %{stuck_frac*100:.0f} | ref hareketliyken ω≈0 |
| lurch-spike | {lurch} | breakaway imzası |

**Hüküm:** {verdict}

## Artifacts
- raw/data.csv{(' · '+os.path.basename(plot)) if plot else ''}
## Üreten: `scripts/hp_track_test.py`
""")
    print(f"Artifact: {out}/")
    if plot: print(f"Plot: {plot}")
    return 0

if __name__=="__main__": sys.exit(main())
