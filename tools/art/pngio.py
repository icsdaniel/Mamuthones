"""Minimal PNG writer/reader with numpy + zlib (no PIL in the toolchain)."""
import struct
import zlib

import numpy as np


def write_png(path, arr):
    """Write a uint8 array (H, W), (H, W, 2), (H, W, 3) or (H, W, 4) as PNG."""
    a = np.asarray(arr)
    if a.dtype != np.uint8:
        a = np.clip(a, 0, 255).astype(np.uint8)
    if a.ndim == 2:
        a = a[:, :, None]
    h, w, c = a.shape
    color_type = {1: 0, 2: 4, 3: 2, 4: 6}[c]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def read_png(path):
    """Read an 8-bit non-interlaced PNG into a uint8 array (H, W, C)."""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    idat = b""
    w = h = ct = 0
    while pos < len(data):
        (n,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if tag == b"IHDR":
            w, h, depth, ct, _, _, inter = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and inter == 0
        elif tag == b"IDAT":
            idat += body
    c = {0: 1, 4: 2, 2: 3, 6: 4}[ct]
    raw = zlib.decompress(idat)
    stride = w * c
    out = np.zeros((h, stride), np.int32)
    prev = np.zeros(stride, np.int32)
    p = 0
    for y in range(h):
        ft = raw[p]
        line = np.frombuffer(raw[p + 1:p + 1 + stride], np.uint8).astype(np.int32)
        p += 1 + stride
        cur = np.zeros(stride, np.int32)
        if ft == 0:
            cur = line
        elif ft == 2:
            cur = (line + prev) & 255
        else:
            for i in range(stride):
                left = cur[i - c] if i >= c else 0
                up = prev[i]
                ul = prev[i - c] if i >= c else 0
                if ft == 1:
                    v = left
                elif ft == 3:
                    v = (left + up) >> 1
                else:
                    pa, pb, pc = abs(up - ul), abs(left - ul), abs(left + up - 2 * ul)
                    v = left if pa <= pb and pa <= pc else (up if pb <= pc else ul)
                cur[i] = (line[i] + v) & 255
        out[y] = cur
        prev = cur
    return out.reshape(h, w, c).astype(np.uint8)
