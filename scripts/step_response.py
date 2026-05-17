#!/usr/bin/env python3
"""
Aşama 1.1 — Tek motor step response veri toplama.

Plan (ROADMAP §1 + CLAUDE.md Project Logging Discipline):
  - 9 duty × 2 yön = 18 step (Soru 2 önerisi B: dead-band çevresinde yoğun)
  - Default duties: 0.12, 0.14, 0.16, 0.18, 0.20, 0.25, 0.30, 0.40, 0.45
  - Her step: 5 sn sürüş + 2 sn coast (cooldown)
  - 250 ms heartbeat (watchdog 1 sn'e 4× marj)
  - Firmware T_US (DWT cycle counter / 96) zaman damgası ile fit precision

Çıktı:
  artifacts/1/step_response/<test_id>/
    ├── raw/data.csv.gz   ← (gzipli, gitignored)
    ├── summary.md         ← (insan okur, repo'ya girer)
    └── meta.json          ← (makine okur, repo'ya girer)

Kullanım:
    python3 scripts/step_response.py
    python3 scripts/step_response.py --port /dev/ttyACM1 --test-id deneme_1
    python3 scripts/step_response.py --duties 0.20 0.30 0.45  # özel set
    python3 scripts/step_response.py --dry-run                 # bağlantı + handshake testi

Kaynaklar (KAYNAKCA.md):
  [Ljung1999] §3 — step response veri toplama
  [Soderstrom1989] §4 — sample frequency vs dinamik
  [ARM_DWT] — Cortex-M4 DWT.CYCCNT mikrosaniye timestamp
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import gzip
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

import serial


# ── Sabit konfig ───────────────────────────────────────────────────
DEFAULT_DUTIES = [0.12, 0.14, 0.16, 0.18, 0.20, 0.25, 0.30, 0.40, 0.45]
STEP_DURATION_S = 5.0
COAST_DURATION_S = 2.0
HEARTBEAT_S = 0.25
HANDSHAKE_TIMEOUT_S = 1.0
GZIP_THRESHOLD_BYTES = 50 * 1024  # 50 KB üstü ham log gzip

# Firmware TX formatı:
#   T_US:<u32>,P:<f>,R:<f>,GX:<f>,GY:<f>,FP:<f>,FR:<f>,EC:<i32>,OMEGA:<f>
LINE_RE = re.compile(
    r"T_US:(\d+),"
    r"P:([-\d.]+),R:([-\d.]+),GX:([-\d.]+),GY:([-\d.]+),"
    r"FP:([-\d.]+),FR:([-\d.]+),"
    r"EC:(-?\d+),OMEGA:([-\d.]+)"
)


# ── Yardımcılar ─────────────────────────────────────────────────────
def ts() -> str:
    return time.strftime("%H:%M:%S")


def commit_hash() -> str:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], stderr=subprocess.DEVNULL
        )
        return out.decode().strip()
    except Exception:
        return "UNKNOWN"


def handshake(ser: serial.Serial) -> float:
    """PING gönder, 1 sn içinde PONG bekle. RTT'yi ms olarak döndür."""
    ser.reset_input_buffer()
    ser.write(b"PING\n")
    t0 = time.time()
    while time.time() - t0 < HANDSHAKE_TIMEOUT_S:
        line = ser.readline().decode("utf-8", errors="ignore").strip()
        if "PONG" in line:
            return (time.time() - t0) * 1000.0
    raise RuntimeError(f"Handshake timeout ({HANDSHAKE_TIMEOUT_S}s) — firmware uyanık mı?")


def run_step(ser: serial.Serial, duty: float, writer: csv.writer,
             phase: str, step_idx: int) -> dict:
    """Tek bir step çalıştır. CSV'ye satır satır yaz, özet sayıları döndür."""
    sign = "+" if duty >= 0 else ""
    cmd = f"DUTY:{sign}{duty:.3f}".encode() + b"\n"
    print(f"[{ts()}] step {step_idx:2d}  DUTY:{sign}{duty:.3f}  ({phase})", flush=True)

    ser.reset_input_buffer()
    ser.write(cmd)
    t_start = time.time()
    last_hb = t_start
    omegas: list[float] = []
    n_samples = 0
    duration_s = STEP_DURATION_S if phase == "drive" else COAST_DURATION_S
    if phase == "coast":
        ser.write(b"STOP\n")

    while True:
        now = time.time()
        elapsed = now - t_start
        if elapsed >= duration_s:
            break

        if now - last_hb >= HEARTBEAT_S:
            ser.write(b"PING\n")
            last_hb = now

        while ser.in_waiting:
            line = ser.readline().decode("utf-8", errors="ignore").strip()
            m = LINE_RE.search(line)
            if not m:
                continue
            t_us_fw = int(m.group(1))
            p, r, gx, gy = (float(m.group(i)) for i in (2, 3, 4, 5))
            fp, fr = float(m.group(6)), float(m.group(7))
            ec, omega = int(m.group(8)), float(m.group(9))

            writer.writerow([
                t_us_fw, f"{now:.6f}", phase, step_idx,
                f"{duty:.4f}", f"{omega:.3f}", ec,
                f"{p:.2f}", f"{r:.2f}", f"{gx:.3f}", f"{gy:.3f}",
                f"{fp:.2f}", f"{fr:.2f}",
            ])
            omegas.append(omega)
            n_samples += 1

        time.sleep(0.005)

    summary = {"n_samples": n_samples}
    if omegas:
        steady = omegas[len(omegas) // 2:]
        summary["omega_steady_mean"] = sum(steady) / len(steady)
        summary["omega_steady_max"] = max(steady)
        summary["omega_steady_min"] = min(steady)
        print(f"          → n={n_samples}, ω_steady = {summary['omega_steady_mean']:+7.2f} rad/s")
    else:
        summary["omega_steady_mean"] = None
        print("          → ÖRNEKLEM YOK (USB sorunu?)")
    return summary


# ── Artifact üretimi ────────────────────────────────────────────────
def write_summary(out_dir: Path, test_id: str, duties: list[float],
                  step_summaries: list[dict], rtt_ms: float,
                  raw_path: Path, status: str) -> None:
    """summary.md — insan okur."""
    with (out_dir / "summary.md").open("w") as f:
        f.write(f"# Aşama 1.1 — Step Response Veri Toplama\n\n")
        f.write(f"- **Test ID:** {test_id}\n")
        f.write(f"- **Tarih:** {dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"- **Commit:** `{commit_hash()}`\n")
        f.write(f"- **Hedef:** Tek motor 1. dereceden + dead-band fit için step response veri seti\n")
        f.write(f"- **Komut:** `python3 scripts/step_response.py --test-id {test_id}`\n")
        f.write(f"- **Handshake RTT:** {rtt_ms:.1f} ms\n\n")

        f.write("## Step Listesi\n\n")
        f.write("| # | Yön | Duty | Faz | ω_steady (rad/s) | Örnekler |\n")
        f.write("|---|---|---|---|---|---|\n")
        for i, (duty, summ) in enumerate(zip(duties, step_summaries)):
            yon = "CW" if duty > 0 else "CCW"
            faz = "drive" if (i % 2 == 0) else "coast"
            mean = summ.get("omega_steady_mean")
            mean_s = f"{mean:+7.2f}" if mean is not None else "  N/A"
            f.write(f"| {i+1} | {yon} | {duty:+.3f} | {faz} | {mean_s} | {summ['n_samples']} |\n")

        f.write(f"\n## Durum\n\n**{status}**\n\n")
        f.write("## Artifacts\n\n")
        f.write(f"- `{raw_path.name}` (ham CSV, gzipli)\n")


def write_meta(out_dir: Path, test_id: str, duties: list[float],
               step_summaries: list[dict], rtt_ms: float,
               raw_path: Path, status: str) -> None:
    """meta.json — makine okur."""
    key_metrics: dict[str, float | None] = {
        "handshake_rtt_ms": rtt_ms,
        "n_steps": len(step_summaries),
        "total_samples": sum(s.get("n_samples", 0) for s in step_summaries),
    }
    for i, (duty, summ) in enumerate(zip(duties, step_summaries)):
        mean = summ.get("omega_steady_mean")
        if mean is not None:
            key_metrics[f"omega_steady_d{duty:+.3f}"] = round(mean, 3)

    meta = {
        "test_id": test_id,
        "title": "Tek motor step response — 1.1 veri toplama",
        "timestamp": dt.datetime.now().isoformat(timespec="seconds"),
        "commit": commit_hash(),
        "status": status,
        "duties": duties,
        "step_duration_s": STEP_DURATION_S,
        "coast_duration_s": COAST_DURATION_S,
        "key_metrics": key_metrics,
        "artifacts": [raw_path.name],
    }
    with (out_dir / "meta.json").open("w") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)


def gzip_if_large(path: Path) -> Path:
    """50 KB üstü dosyaları gzipler; final dosya yolunu döndür."""
    if path.stat().st_size < GZIP_THRESHOLD_BYTES:
        return path
    gz = path.with_suffix(path.suffix + ".gz")
    with path.open("rb") as fi, gzip.open(gz, "wb") as fo:
        shutil.copyfileobj(fi, fo)
    path.unlink()
    return gz


# ── Ana akış ─────────────────────────────────────────────────────────
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--port", default="/dev/ttyACM0")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--duties", type=float, nargs="+", default=DEFAULT_DUTIES,
                        help="duty seviyeleri (mutlak değer; her biri için CW + CCW)")
    parser.add_argument("--test-id", default=None,
                        help="artifacts/1/step_response/<id>/ klasör adı (default: ts damgası)")
    parser.add_argument("--dry-run", action="store_true",
                        help="sadece bağlantı + handshake, step çalıştırma")
    args = parser.parse_args()

    test_id = args.test_id or dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = Path("artifacts/1/step_response") / test_id
    raw_dir = out_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_csv = raw_dir / "data.csv"

    print(f"[{ts()}] Test ID: {test_id}")
    print(f"[{ts()}] Çıktı dizini: {out_dir}/")
    print(f"[{ts()}] Bağlantı: {args.port} @ {args.baud}")

    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port açılamadı: {e}")
        return 2

    duties_signed: list[float] = []
    for d in args.duties:
        duties_signed.append(+abs(d))
        duties_signed.append(-abs(d))

    try:
        rtt_ms = handshake(ser)
        print(f"[{ts()}] PING → PONG ({rtt_ms:.1f} ms)  ✓\n")

        if args.dry_run:
            print(f"[{ts()}] --dry-run: step çalıştırılmadı.")
            return 0

        step_summaries: list[dict] = []
        flat_duties: list[float] = []
        with raw_csv.open("w", newline="") as fh:
            writer = csv.writer(fh)
            writer.writerow([
                "t_us_fw", "t_host_s", "phase", "step_idx",
                "duty_cmd", "omega", "ec",
                "pitch", "roll", "gx", "gy", "fp", "fr",
            ])
            for i, duty in enumerate(duties_signed, start=1):
                drive = run_step(ser, duty, writer, "drive", i)
                step_summaries.append(drive)
                flat_duties.append(duty)
                coast = run_step(ser, 0.0, writer, "coast", i)
                step_summaries.append(coast)
                flat_duties.append(0.0)

        # STOP garanti
        ser.write(b"STOP\n")
        time.sleep(0.1)

        raw_final = gzip_if_large(raw_csv)
        status = "PASS" if all(s["n_samples"] > 0 for s in step_summaries) else "PARTIAL"

        write_summary(out_dir, test_id, flat_duties, step_summaries, rtt_ms, raw_final, status)
        write_meta(out_dir, test_id, flat_duties, step_summaries, rtt_ms, raw_final, status)

        print(f"\n[{ts()}] ─── ÖZET ──────────────────────────────────")
        print(f"  Toplam step: {len(step_summaries)}")
        print(f"  Toplam örneklem: {sum(s['n_samples'] for s in step_summaries)}")
        print(f"  Durum: {status}")
        print(f"  Artifact: {out_dir}/")
        print(f"  Ham veri: {raw_final.name}  ({raw_final.stat().st_size//1024} KB)")
        return 0

    except KeyboardInterrupt:
        print(f"\n[{ts()}] Ctrl-C — STOP gönderiliyor...")
        try:
            ser.write(b"STOP\n")
            time.sleep(0.1)
        except Exception:
            pass
        return 130
    except Exception as e:
        print(f"[{ts()}] HATA: {e}")
        try:
            ser.write(b"STOP\n")
        except Exception:
            pass
        return 1
    finally:
        try:
            ser.close()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
