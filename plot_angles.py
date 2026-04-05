"""
Gerçek zamanlı IMU açı grafiği
Kullanım: python3 plot_angles.py [port]
Varsayılan port: /dev/ttyACM0
"""

import sys
import re
from collections import deque
import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation

PORT   = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM0"
BAUD   = 115200
N      = 300       # ekranda tutulacak örnek sayısı
YLIM   = 90        # grafik dikey aralığı ±derece

pitch_buf = deque([0.0] * N, maxlen=N)
roll_buf  = deque([0.0] * N, maxlen=N)
x_axis    = list(range(N))

# --- Seri port ---
try:
    ser = serial.Serial(PORT, BAUD, timeout=0.02)
except serial.SerialException as e:
    sys.exit(f"Port açılamadı: {e}")

# --- Şekil ---
plt.style.use("dark_background")
fig, (ax_p, ax_r) = plt.subplots(2, 1, figsize=(11, 6), sharex=True)
fig.suptitle("IMU — İvmeölçer Açısı  (ham, füzyonsuz)", fontsize=13, color="white")

def _setup_ax(ax, label, color):
    line, = ax.plot(x_axis, [0.0] * N, color=color, linewidth=1.4)
    ax.set_xlim(0, N - 1)
    ax.set_ylim(-YLIM, YLIM)
    ax.set_ylabel(f"{label} (°)", fontsize=11)
    ax.axhline(0, color="gray", linewidth=0.6, linestyle="--")
    ax.grid(True, alpha=0.15)
    # canlı değer etiketi
    txt = ax.text(0.01, 0.88, "", transform=ax.transAxes,
                  fontsize=12, color=color, fontweight="bold")
    return line, txt

line_p, txt_p = _setup_ax(ax_p, "Pitch", "#4fc3f7")
line_r, txt_r = _setup_ax(ax_r, "Roll",  "#ef9a9a")
ax_r.set_xlabel("Örnek", fontsize=10)
plt.tight_layout()

PATTERN = re.compile(r"P:([-\d.]+),R:([-\d.]+)")

def _read_serial():
    """Tamponda bekleyen satırları oku, en son geçerli değeri döndür."""
    p = r = None
    try:
        while ser.in_waiting:
            raw = ser.readline().decode("utf-8", errors="ignore").strip()
            m = PATTERN.search(raw)
            if m:
                p, r = float(m.group(1)), float(m.group(2))
    except Exception:
        pass
    return p, r

def update(_frame):
    p, r = _read_serial()
    if p is not None:
        pitch_buf.append(p)
        roll_buf.append(r)

    pd = list(pitch_buf)
    rd = list(roll_buf)

    line_p.set_ydata(pd)
    line_r.set_ydata(rd)
    txt_p.set_text(f"Pitch = {pd[-1]:+.1f}°")
    txt_r.set_text(f"Roll  = {rd[-1]:+.1f}°")
    return line_p, line_r, txt_p, txt_r

ani = animation.FuncAnimation(
    fig, update,
    interval=40,          # ~25 fps
    blit=True,
    cache_frame_data=False
)

try:
    plt.show()
finally:
    ser.close()
