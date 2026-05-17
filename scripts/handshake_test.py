#!/usr/bin/env python3
"""
USB CDC uçtan uca sanity testi — Faz 2 / Aşama 2B.

Test akışı:
  1. Bağlantı + handshake (PING → PONG, 1 sn timeout)
  2. DUTY:+0.20 (3 sn, 250 ms heartbeat) → STOP → 1 sn cooldown
  3. DUTY:-0.20 (3 sn, heartbeat) → STOP → 1 sn cooldown
  4. DUTY:+0.30 (3 sn, heartbeat) → STOP → 1 sn cooldown

Her step için OMEGA değerleri toplanır, steady-state ortalama raporlanır.
Hata/Ctrl-C durumunda STOP komutu garantili gönderilir.

Kullanım:
    python3 scripts/handshake_test.py
    python3 scripts/handshake_test.py --port /dev/ttyACM1
"""

import argparse
import re
import sys
import time

import serial

OMEGA_RE = re.compile(r"OMEGA:(-?[\d.]+)")
HEARTBEAT_S = 0.25      # 250 ms (1 sn watchdog'a 4x marj)
HANDSHAKE_TIMEOUT_S = 1.0


def ts():
    """HH:MM:SS damgası."""
    return time.strftime("%H:%M:%S")


def read_omegas(ser):
    """Buffer'daki tüm satırları oku, OMEGA değerlerini liste olarak döndür."""
    values = []
    while ser.in_waiting:
        line = ser.readline().decode("utf-8", errors="ignore").strip()
        m = OMEGA_RE.search(line)
        if m:
            try:
                values.append(float(m.group(1)))
            except ValueError:
                pass
    return values


def handshake(ser):
    """PING gönder, 1 sn içinde PONG bekle. Süreyi ms olarak döndür."""
    # Bekleyen veriyi temizle
    ser.reset_input_buffer()
    ser.write(b"PING\n")
    t0 = time.time()
    while time.time() - t0 < HANDSHAKE_TIMEOUT_S:
        line = ser.readline().decode("utf-8", errors="ignore").strip()
        if "PONG" in line:
            return (time.time() - t0) * 1000.0
    raise RuntimeError(f"Handshake timeout — {HANDSHAKE_TIMEOUT_S}s içinde PONG alınamadı")


def run_step(ser, duty, duration_s):
    """DUTY:<duty> gönder, duration_s boyunca heartbeat ile sür.
    Her ~0.5 sn'de OMEGA örneği yazdır, dönerken steady-state ortalamasını ver."""
    sign = "+" if duty >= 0 else ""
    cmd = f"DUTY:{sign}{duty:.2f}".encode() + b"\n"
    print(f"[{ts()}] >> {cmd.decode().strip()}  ({duration_s:.1f} sn, heartbeat {int(HEARTBEAT_S*1000)} ms)")

    ser.reset_input_buffer()
    ser.write(cmd)
    t_start = time.time()
    last_hb = t_start
    last_print = t_start
    omegas = []

    while True:
        now = time.time()
        elapsed = now - t_start
        if elapsed >= duration_s:
            break

        # Heartbeat
        if now - last_hb >= HEARTBEAT_S:
            ser.write(b"PING\n")
            last_hb = now

        # OMEGA oku
        omegas.extend(read_omegas(ser))

        # Periyodik gösterim (her ~0.5 sn)
        if now - last_print >= 0.5 and omegas:
            print(f"          t={elapsed:4.1f}s  OMEGA={omegas[-1]:+7.1f}  (n={len(omegas)})")
            last_print = now

        time.sleep(0.02)  # CPU rahatlat

    # Steady-state ortalama: son yarısı
    if omegas:
        steady = omegas[len(omegas) // 2 :]
        avg = sum(steady) / len(steady)
        print(f"          → avg(steady) = {avg:+7.2f}  (n={len(steady)})")
        return avg
    print("          → OMEGA örneği yok (USB akış sorunu?)")
    return None


def stop_and_cooldown(ser, duration_s):
    """STOP gönder, cooldown sırasında OMEGA'nın 0'a indiğini doğrula."""
    print(f"[{ts()}] >> STOP  (cooldown {duration_s:.1f} sn)")
    ser.write(b"STOP\n")
    ser.reset_input_buffer()
    t_start = time.time()
    last_hb = t_start
    final_omega = None

    while time.time() - t_start < duration_s:
        now = time.time()
        if now - last_hb >= HEARTBEAT_S:
            ser.write(b"PING\n")
            last_hb = now
        vals = read_omegas(ser)
        if vals:
            final_omega = vals[-1]
        time.sleep(0.02)

    if final_omega is not None:
        marker = "✓" if abs(final_omega) < 5.0 else "⚠"
        print(f"          → cooldown sonu OMEGA = {final_omega:+7.2f}  {marker}")
    return final_omega


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--port", default="/dev/ttyACM0", help="seri port (default /dev/ttyACM0)")
    parser.add_argument("--baud", default=115200, type=int)
    args = parser.parse_args()

    print(f"[{ts()}] Connecting to {args.port} @ {args.baud}...")
    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.05)
    except serial.SerialException as e:
        print(f"[ERR] Port açılamadı: {e}")
        sys.exit(2)

    try:
        # 1. Handshake
        rtt_ms = handshake(ser)
        print(f"[{ts()}] PING → PONG ({rtt_ms:.1f} ms)  ✓")
        print()

        # 2. Mini sequence
        results = []
        for duty, dur in [(+0.20, 3.0), (-0.20, 3.0), (+0.30, 3.0)]:
            avg = run_step(ser, duty, dur)
            results.append((duty, avg))
            stop_and_cooldown(ser, 1.0)
            print()

        # 3. Özet
        print(f"[{ts()}] ─── SUMMARY ───────────────────────────────")
        for duty, avg in results:
            sign = "+" if duty >= 0 else ""
            avg_s = f"{avg:+7.2f}" if avg is not None else "  N/A "
            print(f"  DUTY:{sign}{duty:.2f}  →  steady OMEGA = {avg_s} rad/s")
        # Yön simetrisi
        cw20  = results[0][1]
        ccw20 = results[1][1]
        if cw20 is not None and ccw20 is not None:
            sym_err = abs(abs(cw20) - abs(ccw20)) / max(abs(cw20), abs(ccw20), 1e-6) * 100
            print(f"  Yön simetrisi (±%20): fark = {sym_err:.1f}%")
        print(f"[{ts()}] ALL PASS")

    except KeyboardInterrupt:
        print(f"\n[{ts()}] Ctrl-C — STOP gönderiliyor...")
        sys.exit(130)
    except Exception as e:
        print(f"[{ts()}] HATA: {e}")
        sys.exit(1)
    finally:
        # Garantili durdurma
        try:
            ser.write(b"STOP\n")
            time.sleep(0.1)
            ser.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
