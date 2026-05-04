"""
Gerçek zamanlı IMU + Encoder grafiği — 5 panel
  Üst grid (2x2):  Pitch (ham+füzyon) | Roll (ham+füzyon)
                    Gyro-X (°/s)       | Gyro-Y (°/s)
  Alt:             Encoder count (motor şaftı, 32-bit signed)

Her 30 sn'de screenshots/ klasörüne PNG kaydeder (maks 50 dosya).

Kullanım:
  python3 plot_angles.py [port] [csv_log_path]
  python3 plot_angles.py /dev/ttyACM0
  python3 plot_angles.py /dev/ttyACM0 logs/test_2a4.csv
"""

import os
import sys
import re
import glob
import time
from collections import deque

import serial
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.animation as animation

# ── Ayarlar ─────────────────────────────────────────────────
PORT               = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM0"
LOG_PATH           = sys.argv[2] if len(sys.argv) > 2 else None
BAUD               = 115200
N                  = 600        # 30 sn @ 20 Hz
EC_YLIM            = 10000      # encoder ±limit (1 tur ≈ 466 count çıkış mili)
SCREENSHOT_DIR     = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  "screenshots")
SCREENSHOT_INTERVAL = 30        # saniye
MAX_SCREENSHOTS    = 50

os.makedirs(SCREENSHOT_DIR, exist_ok=True)

# ── CSV log ─────────────────────────────────────────────────
log_file = None
log_t0   = None
if LOG_PATH:
    log_dir = os.path.dirname(os.path.abspath(LOG_PATH))
    os.makedirs(log_dir, exist_ok=True)
    log_file = open(LOG_PATH, "w", buffering=1)  # line-buffered
    log_file.write("t_ms,pitch,roll,gx_dps,gy_dps,fp,fr,ec\n")
    log_t0 = time.time()
    print(f"Log → {LOG_PATH}")

# ── Veri tamponları ──────────────────────────────────────────
keys = ("pitch", "roll", "gx", "gy", "fp", "fr", "ec")
bufs = {k: deque([0.0] * N, maxlen=N) for k in keys}
x_ax = list(range(N))

# ── Seri port ───────────────────────────────────────────────
try:
    ser = serial.Serial(PORT, BAUD, timeout=0.02)
except serial.SerialException as e:
    sys.exit(f"Port açılamadı: {e}")

# ── Şekil — 3 satır × 2 sütun, encoder altta full width ─────
plt.style.use("dark_background")
fig = plt.figure(figsize=(14, 9))
gs  = gridspec.GridSpec(3, 2, figure=fig, height_ratios=[1, 1, 1], hspace=0.45)

ax_p  = fig.add_subplot(gs[0, 0])
ax_r  = fig.add_subplot(gs[0, 1])
ax_gx = fig.add_subplot(gs[1, 0])
ax_gy = fig.add_subplot(gs[1, 1])
ax_ec = fig.add_subplot(gs[2, :])  # tam genişlik

fig.suptitle("IMU  |  ham ivme açısı + complementary filter + gyro hızı + encoder",
             fontsize=12, color="white")

def _make_ax(ax, title, ylim):
    ax.set_xlim(0, N - 1)
    ax.set_ylim(*ylim)
    ax.set_title(title, fontsize=11, pad=4)
    ax.axhline(0, color="gray", linewidth=0.5, linestyle="--")
    ax.grid(True, alpha=0.12)
    ax.tick_params(labelsize=8)

_make_ax(ax_p,  "Pitch (°)",         (-90,  90))
_make_ax(ax_r,  "Roll (°)",          (-90,  90))
_make_ax(ax_gx, "Gyro-X (°/s)",      (-300, 300))
_make_ax(ax_gy, "Gyro-Y (°/s)",      (-300, 300))
_make_ax(ax_ec, "Encoder Count (motor şaftı, 32-bit signed)",
                                     (-EC_YLIM, EC_YLIM))

# Pitch paneli: ham (soluk) + füzyon (parlak)
ln_p_raw,  = ax_p.plot(x_ax, [0.0]*N, color="#1e6fa0", linewidth=1.0,
                        alpha=0.55, label="Ham")
ln_p_fuse, = ax_p.plot(x_ax, [0.0]*N, color="#4fc3f7", linewidth=1.8,
                        label="Füzyon")
ax_p.legend(loc="upper right", fontsize=8, framealpha=0.3)
txt_p = ax_p.text(0.02, 0.88, "", transform=ax_p.transAxes,
                  fontsize=10, color="#4fc3f7", fontweight="bold")

# Roll paneli: ham + füzyon
ln_r_raw,  = ax_r.plot(x_ax, [0.0]*N, color="#1e7a72", linewidth=1.0,
                        alpha=0.55, label="Ham")
ln_r_fuse, = ax_r.plot(x_ax, [0.0]*N, color="#80cbc4", linewidth=1.8,
                        label="Füzyon")
ax_r.legend(loc="upper right", fontsize=8, framealpha=0.3)
txt_r = ax_r.text(0.02, 0.88, "", transform=ax_r.transAxes,
                  fontsize=10, color="#80cbc4", fontweight="bold")

# Gyro panelleri
ln_gx, = ax_gx.plot(x_ax, [0.0]*N, color="#ffb74d", linewidth=1.3)
txt_gx = ax_gx.text(0.02, 0.88, "", transform=ax_gx.transAxes,
                    fontsize=10, color="#ffb74d", fontweight="bold")

ln_gy, = ax_gy.plot(x_ax, [0.0]*N, color="#ef9a9a", linewidth=1.3)
txt_gy = ax_gy.text(0.02, 0.88, "", transform=ax_gy.transAxes,
                    fontsize=10, color="#ef9a9a", fontweight="bold")

# Encoder paneli
ln_ec, = ax_ec.plot(x_ax, [0.0]*N, color="#ce93d8", linewidth=1.5)
txt_ec = ax_ec.text(0.01, 0.88, "", transform=ax_ec.transAxes,
                    fontsize=11, color="#ce93d8", fontweight="bold")

# ── Screenshot ──────────────────────────────────────────────
last_shot_time = time.time()

def _save_screenshot():
    fig.canvas.draw()
    ts   = time.strftime("%Y%m%d_%H%M%S")
    path = os.path.join(SCREENSHOT_DIR, f"imu_{ts}.png")
    fig.savefig(path, dpi=100, bbox_inches="tight", facecolor="black")

    files = sorted(glob.glob(os.path.join(SCREENSHOT_DIR, "imu_*.png")))
    while len(files) > MAX_SCREENSHOTS:
        os.remove(files.pop(0))

# ── Veri okuma ───────────────────────────────────────────────
PATTERN = re.compile(
    r"P:([-\d.]+),R:([-\d.]+),GX:([-\d.]+),GY:([-\d.]+)"
    r",FP:([-\d.]+),FR:([-\d.]+)"
    r",EC:(-?\d+)"
)

def _read():
    vals = None
    try:
        while ser.in_waiting:
            raw = ser.readline().decode("utf-8", errors="ignore").strip()
            m = PATTERN.search(raw)
            if m:
                vals = (
                    float(m.group(1)), float(m.group(2)),
                    float(m.group(3)), float(m.group(4)),
                    float(m.group(5)), float(m.group(6)),
                    int(m.group(7)),
                )
    except Exception:
        pass
    return vals  # (pitch, roll, gx, gy, fp, fr, ec)

# ── Animasyon ────────────────────────────────────────────────
def update(_frame):
    global last_shot_time

    v = _read()
    if v is not None:
        bufs["pitch"].append(v[0])
        bufs["roll"].append(v[1])
        bufs["gx"].append(v[2])
        bufs["gy"].append(v[3])
        bufs["fp"].append(v[4])
        bufs["fr"].append(v[5])
        bufs["ec"].append(float(v[6]))

        if log_file is not None:
            t_ms = int((time.time() - log_t0) * 1000)
            log_file.write(
                f"{t_ms},{v[0]:.2f},{v[1]:.2f},{v[2]:.2f},{v[3]:.2f},"
                f"{v[4]:.2f},{v[5]:.2f},{v[6]}\n"
            )

    pd  = list(bufs["pitch"])
    rd  = list(bufs["roll"])
    fpd = list(bufs["fp"])
    frd = list(bufs["fr"])
    gxd = list(bufs["gx"])
    gyd = list(bufs["gy"])
    ecd = list(bufs["ec"])

    ln_p_raw.set_ydata(pd);   ln_p_fuse.set_ydata(fpd)
    ln_r_raw.set_ydata(rd);   ln_r_fuse.set_ydata(frd)
    ln_gx.set_ydata(gxd)
    ln_gy.set_ydata(gyd)
    ln_ec.set_ydata(ecd)

    txt_p.set_text(f"Ham {pd[-1]:+.1f}°  Füz {fpd[-1]:+.1f}°")
    txt_r.set_text(f"Ham {rd[-1]:+.1f}°  Füz {frd[-1]:+.1f}°")
    txt_gx.set_text(f"GX = {gxd[-1]:+.1f} °/s")
    txt_gy.set_text(f"GY = {gyd[-1]:+.1f} °/s")
    txt_ec.set_text(f"EC = {int(ecd[-1]):+d} count")

    now = time.time()
    if now - last_shot_time >= SCREENSHOT_INTERVAL:
        _save_screenshot()
        last_shot_time = now

    return (ln_p_raw, ln_p_fuse, ln_r_raw, ln_r_fuse,
            ln_gx, ln_gy, ln_ec,
            txt_p, txt_r, txt_gx, txt_gy, txt_ec)

ani = animation.FuncAnimation(
    fig, update,
    interval=40,
    blit=True,
    cache_frame_data=False
)

try:
    plt.show()
finally:
    ser.close()
    if log_file is not None:
        log_file.close()
