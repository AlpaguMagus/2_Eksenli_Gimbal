"""
Gerçek zamanlı IMU grafiği — 4 panel
  Pitch: ham ivme + füzyon   |   Roll: ham ivme + füzyon
  Gyro-X (°/s)               |   Gyro-Y (°/s)

Her 30 sn'de screenshots/ klasörüne PNG kaydeder (maks 50 dosya).
Kullanım: python3 plot_angles.py [port]
"""

import os
import sys
import re
import glob
import time
from collections import deque

import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation

# ── Ayarlar ─────────────────────────────────────────────────
PORT               = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM0"
BAUD               = 115200
N                  = 600        # 30 sn @ 20 Hz
SCREENSHOT_DIR     = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  "screenshots")
SCREENSHOT_INTERVAL = 30        # saniye
MAX_SCREENSHOTS    = 50

os.makedirs(SCREENSHOT_DIR, exist_ok=True)

# ── Veri tamponları ──────────────────────────────────────────
keys = ("pitch", "roll", "gx", "gy", "fp", "fr")
bufs = {k: deque([0.0] * N, maxlen=N) for k in keys}
x_ax = list(range(N))

# ── Seri port ───────────────────────────────────────────────
try:
    ser = serial.Serial(PORT, BAUD, timeout=0.02)
except serial.SerialException as e:
    sys.exit(f"Port açılamadı: {e}")

# ── Şekil ───────────────────────────────────────────────────
plt.style.use("dark_background")
fig, axes = plt.subplots(2, 2, figsize=(14, 7))
fig.suptitle("IMU  |  ham ivme açısı  +  complementary filter  +  gyro hızı",
             fontsize=12, color="white")

def _make_ax(ax, title, ylim):
    ax.set_xlim(0, N - 1)
    ax.set_ylim(*ylim)
    ax.set_title(title, fontsize=11, pad=4)
    ax.axhline(0, color="gray", linewidth=0.5, linestyle="--")
    ax.grid(True, alpha=0.12)
    ax.tick_params(labelsize=8)

_make_ax(axes[0][0], "Pitch (°)",    (-90,  90))
_make_ax(axes[0][1], "Roll (°)",     (-90,  90))
_make_ax(axes[1][0], "Gyro-X (°/s)", (-300, 300))
_make_ax(axes[1][1], "Gyro-Y (°/s)", (-300, 300))

# Pitch paneli: ham (soluk) + füzyon (parlak)
ln_p_raw,  = axes[0][0].plot(x_ax, [0.0]*N, color="#1e6fa0", linewidth=1.0,
                              alpha=0.55, label="Ham")
ln_p_fuse, = axes[0][0].plot(x_ax, [0.0]*N, color="#4fc3f7", linewidth=1.8,
                              label="Füzyon")
axes[0][0].legend(loc="upper right", fontsize=8, framealpha=0.3)
txt_p = axes[0][0].text(0.02, 0.88, "", transform=axes[0][0].transAxes,
                        fontsize=10, color="#4fc3f7", fontweight="bold")

# Roll paneli: ham + füzyon
ln_r_raw,  = axes[0][1].plot(x_ax, [0.0]*N, color="#1e7a72", linewidth=1.0,
                              alpha=0.55, label="Ham")
ln_r_fuse, = axes[0][1].plot(x_ax, [0.0]*N, color="#80cbc4", linewidth=1.8,
                              label="Füzyon")
axes[0][1].legend(loc="upper right", fontsize=8, framealpha=0.3)
txt_r = axes[0][1].text(0.02, 0.88, "", transform=axes[0][1].transAxes,
                        fontsize=10, color="#80cbc4", fontweight="bold")

# Gyro panelleri
ln_gx, = axes[1][0].plot(x_ax, [0.0]*N, color="#ffb74d", linewidth=1.3)
txt_gx = axes[1][0].text(0.02, 0.88, "", transform=axes[1][0].transAxes,
                          fontsize=10, color="#ffb74d", fontweight="bold")

ln_gy, = axes[1][1].plot(x_ax, [0.0]*N, color="#ef9a9a", linewidth=1.3)
txt_gy = axes[1][1].text(0.02, 0.88, "", transform=axes[1][1].transAxes,
                          fontsize=10, color="#ef9a9a", fontweight="bold")

plt.tight_layout()

# ── Screenshot ──────────────────────────────────────────────
last_shot_time = time.time()

def _save_screenshot():
    fig.canvas.draw()
    ts   = time.strftime("%Y%m%d_%H%M%S")
    path = os.path.join(SCREENSHOT_DIR, f"imu_{ts}.png")
    fig.savefig(path, dpi=100, bbox_inches="tight", facecolor="black")

    # Eski dosyaları temizle
    files = sorted(glob.glob(os.path.join(SCREENSHOT_DIR, "imu_*.png")))
    while len(files) > MAX_SCREENSHOTS:
        os.remove(files.pop(0))

# ── Veri okuma ───────────────────────────────────────────────
PATTERN = re.compile(
    r"P:([-\d.]+),R:([-\d.]+),GX:([-\d.]+),GY:([-\d.]+)"
    r",FP:([-\d.]+),FR:([-\d.]+)"
)

def _read():
    vals = None
    try:
        while ser.in_waiting:
            raw = ser.readline().decode("utf-8", errors="ignore").strip()
            m = PATTERN.search(raw)
            if m:
                vals = tuple(float(m.group(i)) for i in range(1, 7))
    except Exception:
        pass
    return vals  # (pitch, roll, gx, gy, fp, fr)

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

    pd  = list(bufs["pitch"])
    rd  = list(bufs["roll"])
    fpd = list(bufs["fp"])
    frd = list(bufs["fr"])
    gxd = list(bufs["gx"])
    gyd = list(bufs["gy"])

    ln_p_raw.set_ydata(pd);   ln_p_fuse.set_ydata(fpd)
    ln_r_raw.set_ydata(rd);   ln_r_fuse.set_ydata(frd)
    ln_gx.set_ydata(gxd)
    ln_gy.set_ydata(gyd)

    txt_p.set_text(f"Ham {pd[-1]:+.1f}°  Füz {fpd[-1]:+.1f}°")
    txt_r.set_text(f"Ham {rd[-1]:+.1f}°  Füz {frd[-1]:+.1f}°")
    txt_gx.set_text(f"GX = {gxd[-1]:+.1f} °/s")
    txt_gy.set_text(f"GY = {gyd[-1]:+.1f} °/s")

    # 30 sn'de bir screenshot
    now = time.time()
    if now - last_shot_time >= SCREENSHOT_INTERVAL:
        _save_screenshot()
        last_shot_time = now

    return (ln_p_raw, ln_p_fuse, ln_r_raw, ln_r_fuse,
            ln_gx, ln_gy, txt_p, txt_r, txt_gx, txt_gy)

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
