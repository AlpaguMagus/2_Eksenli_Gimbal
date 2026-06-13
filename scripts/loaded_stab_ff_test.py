#!/usr/bin/env python3
"""Aşama 3 — YÜKLÜ stabilizasyon (STAB) + sürtünme FF aç/kapa A/B (motor-2).

ASIL HEDEF: Stabilizasyon — motor base eğimine TERS döner (gerçek gimbalda payload sabit).
Bu test YÜK altında STAB'ı sürtünme FF AÇIK vs KAPALI kıyaslar: yük altında stick-slip,
stabilizasyon düzeltmelerini SIÇRAMALI mı yapıyor (FF yok) yoksa PÜRÜZSÜZ mü (FF var)?

⚠ KAPSAM/SINIR (dürüst):
  - IMU base'de (payload'da DEĞİL) → bu, stabilizasyon YASASININ yük-altı demosu;
    "payload gerçekten level kaldı mı" inertial doğrulaması = Aşama 5 (IMU payload'a).
  - El-eğmesi tekrarlanamaz → yarı-nicel. Bu yüzden tek oturumda FF off/on/off/on
    DÖNÜŞÜMLÜ (interleaved) → el hareketi + sıra/ısınma etkisi ortalanır; off-toplam
    vs on-toplam kıyaslanır.
  - Rig dengesiz sarkaç = stres senaryosu (gerçek gimbal dengeli olmalı).

YÖNTEM: MODE2:STAB. 4 segment (off,on,off,on) × ~10s. Sen board'u (IMU) TÜM segmentlerde
AYNI ŞEKİLDE yavaş pitch ±~25° ileri-geri eğ. Stall kapalı (yük yanlış-pozitifi), watchdog
heartbeat. Metrik per segment: takip RMS (θ−ref) + pürüzlülük (jerk = θ'nın 2. farkı RMS).

Kullanım: python3 scripts/loaded_stab_ff_test.py            (4 seg × 10s)
          python3 scripts/loaded_stab_ff_test.py --reanalyze artifacts/3/stab_ff_m2/<id>
Çıktı: artifacts/3/stab_ff_m2/<test_id>/ (summary + meta + plot; raw gitignored)
"""
import serial, time, csv, re, math, argparse, datetime as dt, json, subprocess
from pathlib import Path

DEG_PER_COUNT = 360.0 / 466.0
EC2 = re.compile(r"EC2:(-?\d+)")
FP  = re.compile(r"FP:(-?[\d.]+)")
TR2 = re.compile(r"TR2:(-?[\d.]+)")
HEARTBEAT_S = 0.25

# FF segment planı (dönüşümlü — el hareketi/sıra etkisini ortala)
SEG_PLAN = ["off", "on", "off", "on"]
FF_ON  = ["LFFG2:0.097", "LFFC2:0.090", "LFFDB2:0.34", "LFF2:1"]   # db (firmware default) yapı
FF_OFF = ["LFF2:0"]

def send(ser, c): ser.write((c + "\n").encode())
def ts(): return dt.datetime.now().strftime("%H:%M:%S")
def rms(x): return (sum(v*v for v in x)/len(x))**0.5 if x else 0.0
def commit():
    try: return subprocess.check_output(["git","rev-parse","--short","HEAD"],stderr=subprocess.DEVNULL).decode().strip()
    except Exception: return "?"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--seg-dur", type=float, default=10.0, help="her segment süresi (s)")
    ap.add_argument("--test-id", default=None)
    ap.add_argument("--reanalyze", default=None, help="kayıtlı dizini donanımsız yeniden analiz et")
    args = ap.parse_args()

    if args.reanalyze:
        d = Path(args.reanalyze); rows=[]
        with open(d/"raw"/"data.csv") as fh:
            rd=csv.reader(fh); next(rd,None)
            for r in rd:
                if len(r)<6: continue
                rows.append((float(r[0]),float(r[1]),float(r[2]),float(r[3]),float(r[4]),r[5]))
        print(f"[{ts()}] REANALYZE {d} ({len(rows)} satır)")
        analyze(d, d.name, args, rows); return 0

    tid = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path("artifacts/3/stab_ff_m2") / tid
    (out/"raw").mkdir(parents=True, exist_ok=True)

    print(f"[{ts()}] YÜKLÜ STAB + sürtünme-FF A/B — motor-2, {len(SEG_PLAN)} seg × {args.seg_dur:.0f}s")
    print(f"[{ts()}] ⚠ Board'u (IMU) TÜM segmentlerde AYNI yavaş pitch ±~25° ileri-geri eğ.")
    print(f"[{ts()}] Motor base'e TERS döner (stabilizasyon). FF off/on otomatik dönüşür.\n")
    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port: {e}"); return 2

    rows = []   # (t, fp, tr, theta, err, seg_label)  seg_label='off'/'on'
    try:
        ser.reset_input_buffer()
        send(ser,"PING"); time.sleep(0.3)
        send(ser,"STALLEN2:0"); time.sleep(0.1)        # yük stick-slip stall yanlış-pozitifi
        send(ser,"LFF2:0"); time.sleep(0.05)
        send(ser,"MODE2:STAB"); time.sleep(0.15)       # enc 0°=geçiş anı, pitch0 alınır
        ser.reset_input_buffer()
        t0=time.time(); last_hb=t0; last_p=t0
        for si, ff in enumerate(SEG_PLAN):
            # FF yapısını kur
            for c in (FF_ON if ff=="on" else FF_OFF): send(ser, c); time.sleep(0.04)
            print(f"[{ts()}] ── Segment {si+1}/{len(SEG_PLAN)}: FF {ff.upper()} — eğmeye DEVAM ET (aynı şekilde) ──")
            seg_end = time.time() + args.seg_dur
            while time.time() < seg_end:
                now=time.time()
                if now-last_hb>=HEARTBEAT_S: send(ser,"PING"); last_hb=now
                line=ser.readline().decode("utf-8","ignore").strip()
                mE=EC2.search(line); mF=FP.search(line); mT=TR2.search(line)
                if not (mE and mF and mT): continue
                ec=int(mE.group(1)); fp=float(mF.group(1)); tr=float(mT.group(1))
                theta=ec*DEG_PER_COUNT; err=theta-tr; t=now-t0
                rows.append((round(t,3),round(fp,2),round(tr,2),round(theta,2),round(err,2),ff))
                if now-last_p>=1.0:
                    print(f"    t={t:4.1f}s [{ff}] FP={fp:+6.1f}° ref={tr:+6.1f}° θ={theta:+6.1f}° hata={err:+5.1f}°")
                    last_p=now
        send(ser,"STALLEN2:1"); send(ser,"LFF2:0"); send(ser,"STOP"); send(ser,"MODE2:DUTY"); time.sleep(0.2)
        print(f"\n[{ts()}] tamam — durduruldu (stall + FF emniyet geri).")
    except KeyboardInterrupt:
        send(ser,"STALLEN2:1"); send(ser,"LFF2:0"); send(ser,"STOP"); print("\nCtrl-C — STOP")
    finally:
        try: ser.write(b"STALLEN2:1\nLFF2:0\nSTOP\n"); time.sleep(0.1); ser.close()
        except Exception: pass

    with open(out/"raw"/"data.csv","w",newline="") as fh:
        w=csv.writer(fh); w.writerow(["t","fp","tr","theta_deg","err","seg"]); w.writerows(rows)
    analyze(out, tid, args, rows)
    return 0

def seg_metrics(rows, label):
    """Bir FF durumunun (off/on) TÜM segmentlerini topla → metrikler."""
    sub=[r for r in rows if r[5]==label]
    if len(sub)<20: return None
    fp=[r[1] for r in sub]
    mov=[r[4] for r in sub if abs(r[2])>3.0]          # hareketli pencere (|ref|>3)
    track_rms = rms(mov) if mov else rms([r[4] for r in sub])
    # pürüzlülük: θ'nın 2. farkı (≈ivme) RMS — stick-slip sıçramaları yükseltir.
    # HIZA NORMALİZE: norm = jerk_rms / vel_rms → motion-amplitude/hız confound'unu giderir
    # (stick-slip yüksek-frekans jerk ekler; düz takip düşük tutar). Daha temiz FF göstergesi.
    th=[r[3] for r in sub]
    d1=[th[i]-th[i-1] for i in range(1,len(th))]
    d2=[th[i]-2*th[i-1]+th[i-2] for i in range(2,len(th))]
    rough=rms(d2); vel=rms(d1)
    norm_rough = rough/vel if vel>1e-6 else 0.0
    return {"n":len(sub),"fp_range":round(max(fp)-min(fp),1),
            "track_rms":round(track_rms,2),"roughness":round(rough,3),
            "norm_rough":round(norm_rough,3),
            "max_err":round(max((abs(r[4]) for r in sub),default=0),1)}

def analyze(out, tid, args, rows):
    m_off=seg_metrics(rows,"off"); m_on=seg_metrics(rows,"on")
    print(f"\n[{ts()}] ── YÜKLÜ STAB FF A/B SONUÇ ──")
    print(f"    {'durum':5s} {'n':>5s} {'FP-aralık':>10s} {'takip-RMS':>10s} {'norm-jerk':>10s} {'max|hata|':>10s}")
    for lbl,m in (("FF-OFF",m_off),("FF-ON",m_on)):
        if m: print(f"    {lbl:6s} {m['n']:5d} {m['fp_range']:9.1f}° {m['track_rms']:9.2f}° {m['norm_rough']:10.3f} {m['max_err']:9.1f}°")
        else: print(f"    {lbl:6s}  yetersiz veri")
    # değerlendirme — birincil: takip-RMS + hıza-normalize jerk (ham pürüzlülük motion ile confound)
    status="REVIEW"; note=""
    if m_off and m_on:
        if min(m_off['fp_range'],m_on['fp_range'])<15:
            status="NO_MOTION"; note="board yeterince eğilmedi (FP aralığı <15°) — tekrar"
        else:
            d_nrough = m_off['norm_rough']-m_on['norm_rough']    # >0 = FF daha pürüzsüz
            d_rms    = m_off['track_rms']-m_on['track_rms']      # >0 = FF daha iyi takip
            if d_rms>0 and d_nrough>=0:   status="FF_IMPROVES"
            elif d_rms>0 or d_nrough>0:   status="FF_MIXED"
            else:                          status="FF_NO_BENEFIT"
            note=(f"FF açık vs kapalı (birincil metrikler): takip-RMS {m_off['track_rms']:.2f}→{m_on['track_rms']:.2f}° "
                  f"(Δ{d_rms:+.2f}°, >0=iyi), norm-jerk {m_off['norm_rough']:.3f}→{m_on['norm_rough']:.3f} (Δ{d_nrough:+.3f}, >0=pürüzsüz). "
                  f"max|hata| {m_off['max_err']:.1f}→{m_on['max_err']:.1f}°. FF-ON eğme genliği {m_on['fp_range']:.0f}° vs "
                  f"OFF {m_off['fp_range']:.0f}° (daha zor koşul). ⚠ base-IMU yasa demosu; inertial doğrulama Aşama 5; el-eğmesi yarı-nicel.")
    print(f"    → {status}: {note}")

    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        t=[r[0] for r in rows]; fp=[r[1] for r in rows]; tr=[r[2] for r in rows]; th=[r[3] for r in rows]
        fig,ax=plt.subplots(2,1,figsize=(12,7),sharex=True)
        ax[0].plot(t,fp,color="0.6",lw=1.0,label="FP (IMU base pitch)")
        ax[0].plot(t,tr,"r--",lw=1.0,label="ref (STAB hedef = −rel)")
        ax[0].plot(t,th,"b",lw=1.3,label="θ_motor")
        # FF-on segmentlerini SÜREKLİ bölge olarak gölgele
        i=0; first=True
        while i < len(rows):
            if rows[i][5]=="on":
                j=i
                while j<len(rows) and rows[j][5]=="on": j+=1
                ax[0].axvspan(rows[i][0], rows[j-1][0], color="green", alpha=0.12, lw=0,
                              label="FF AÇIK" if first else None); first=False
                i=j
            else: i+=1
        ax[0].set_ylabel("açı (°)"); ax[0].legend(loc="best",fontsize=8); ax[0].grid(alpha=0.3)
        ax[0].set_title(f"Yüklü STAB + sürtünme-FF A/B (motor-2) — yeşil bölge=FF AÇIK")
        er=[r[4] for r in rows]
        ax[1].plot(t,er,"k",lw=0.8); ax[1].axhline(0,color="r",ls=":",lw=0.8)
        ax[1].set_ylabel("takip hatası θ−ref (°)"); ax[1].set_xlabel("t (s)"); ax[1].grid(alpha=0.3)
        fig.tight_layout(); p=out/"stab_ff_plot.png"; fig.savefig(p,dpi=130); plt.close(fig)
        print(f"    Plot: {p}")
    except Exception as e:
        print(f"    [plot atlandı: {e}]")

    with open(out/"summary.md","w") as f:
        f.write(f"# Yüklü STAB + sürtünme-FF A/B (motor-2) — {tid}\n\n")
        f.write(f"- **Tarih:** {dt.datetime.now():%Y-%m-%d %H:%M} · **Commit:** `{commit()}` · **Durum:** {status}\n")
        f.write(f"- **Hedef:** ASIL amaç stabilizasyon — yük altında sürtünme FF düzeltmeleri pürüzsüzleştiriyor mu?\n")
        f.write(f"- **Yöntem:** MODE2:STAB, FF off/on/off/on dönüşümlü ({args.seg_dur:.0f}s/seg), el ile yavaş base eğme\n")
        f.write(f"- **⚠ Sınır:** IMU base'de (payload değil) → stabilizasyon YASASI demosu; inertial doğrulama Aşama 5. El-eğmesi tekrarlanamaz → yarı-nicel.\n\n")
        f.write("## Sonuç (FF kapalı vs açık, segmentler toplandı)\n\n"
                "> Birincil metrikler: **takip-RMS** (θ−ref) + **norm-jerk** (jerk/hız — ham pürüzlülük "
                "eğme-hızıyla confound olduğu için hıza normalize). >0 Δ = FF iyileştirir.\n\n"
                "| Durum | n | FP-aralık | takip-RMS | norm-jerk | ham-jerk | max\\|hata\\| |\n|---|---|---|---|---|---|---|\n")
        for lbl,m in (("FF-OFF",m_off),("FF-ON",m_on)):
            if m: f.write(f"| {lbl} | {m['n']} | {m['fp_range']:.1f}° | {m['track_rms']:.2f}° | {m['norm_rough']:.3f} | {m['roughness']:.3f} | {m['max_err']:.1f}° |\n")
        f.write(f"\n## Değerlendirme\n{note or 'yetersiz veri'}\n")
        f.write(f"\n## Artifacts\n- raw/data.csv\n- stab_ff_plot.png\n")
    with open(out/"meta.json","w") as f:
        json.dump({"test_id":tid,"timestamp":dt.datetime.now().isoformat(),"commit":commit(),
                   "status":status,"mode":"STAB loaded friction-FF A/B (interleaved)",
                   "scope":"base-IMU law demo (payload inertial validation = Asama 5); hand-tilt semi-quantitative",
                   "ff_off":m_off,"ff_on":m_on,"seg_plan":SEG_PLAN,"seg_dur_s":args.seg_dur,
                   "artifacts":["raw/data.csv","stab_ff_plot.png"]}, f, indent=2, ensure_ascii=False)
    print(f"[{ts()}] Artifact: {out}/  (durum: {status})")

if __name__ == "__main__":
    raise SystemExit(main())
