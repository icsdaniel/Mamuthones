"""Finds the clicks in a WAV written by record_sync.gd and prints their times (see that file)."""
import sys
import numpy as np
import soundfile as sf

data, rate = sf.read(sys.argv[1])
level = np.abs(data if data.ndim == 1 else data.max(axis=1))
clicks = []
for i in np.where(level > 0.3)[0]:
    if not clicks or i - clicks[-1] > rate * 0.5:
        clicks.append(i)
print("clicks at", ", ".join("%.4f s" % (c / rate) for c in clicks))
