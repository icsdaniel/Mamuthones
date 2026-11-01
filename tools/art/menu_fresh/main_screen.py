"""Sonazzos main menu, "Su Manifestu" direction. Drawn from scratch.

python3 main_screen.py [outdir]
Writes main_screen.png, main_screen_pressed.png, main_screen.mp4 (+ debug zooms).
Canvas 135x300 art px, 4x nearest neighbour, five inks only.
"""
import math, os, random, subprocess, sys
import numpy as np
from PIL import Image
import glyphs as G

W, H, SCALE = 135, 300, 4
K, C, R, GR, B = 0, 1, 2, 3, 4          # black, cream, red, warm grey, brown
PAL = [(0x14, 0x10, 0x14), (0xef, 0xe6, 0xd2), (0xc8, 0x35, 0x2a),
       (0xc9, 0xbb, 0xa0), (0x4a, 0x3c, 0x38)]
CX = 67
BPM = 120
FPS = 30


class Canvas:
    def __init__(self):
        self.a = np.zeros((H, W), np.uint8)
        self.occ = np.zeros((H, W), bool)     # pixels covered by any object (incl. black fills)

    def px(self, x, y, c, occ=True):
        if 0 <= x < W and 0 <= y < H:
            self.a[y, x] = c
            if occ:
                self.occ[y, x] = True

    def rect(self, x, y, w, h, c, occ=True):
        x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = c
            if occ:
                self.occ[y0:y1, x0:x1] = True

    def bitmap(self, rows, x, y, c, bg=None):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == '#':
                    self.px(x + i, y + j, c)
                elif bg is not None:
                    self.px(x + i, y + j, bg)

    def text(self, s, x, y, c, font='5'):
        f, cw = (G.F5, 6) if font == '5' else (G.F3, 4)
        for ch in s:
            self.bitmap(f.get(ch, f[' ']), x, y, c)
            x += cw

    def image(self, scale=SCALE):
        rgb = np.array(PAL, np.uint8)[self.a]
        return Image.fromarray(rgb, 'RGB').resize((W * scale, H * scale), Image.NEAREST)


def text_w(s, font='5'):
    return len(s) * (6 if font == '5' else 4) - 1


# ----------------------------------------------------------------- motion
def drop(t_since, amp):
    """Approved curve: hit on the beat, hold 0.03 s, ease back (0.20 s @60 .. 0.10 s @180)."""
    hold = 0.03
    ease = 0.20 - (min(max(BPM, 60), 180) - 60) / 120 * 0.10
    if t_since < 0:
        return 0.0
    if t_since < hold:
        return float(amp)
    p = (t_since - hold) / ease
    if p >= 1:
        return 0.0
    return amp * (1 - p) ** 2   # ease-out return


def motion(t):
    spb = 60.0 / BPM
    beat = int(math.floor(t / spb + 1e-9))
    ts = t - beat * spb
    bells = int(round(drop(ts, 2)))
    mask = int(round(drop(ts, 1) - 0.01))
    in_hold = ts < 0.03
    red = 2 if (beat % 4 == 0 and in_hold) else 1
    # tongues: lag 1 px up during the hold, then swing 1 px sideways (alternating) and back
    if bells == 2:
        tongue = (0, -1)
    elif bells == 1:
        tongue = (1 if beat % 2 == 0 else -1, 0)
    else:
        tongue = (0, 0)
    return dict(bells=bells, mask=mask, red=red, tongue=tongue)


REST = dict(bells=0, mask=0, red=1, tongue=(0, 0))

# ----------------------------------------------------------------- frame
def draw_frame(cv):
    # wolf-tooth band: base row + 3-wide row + point, period 4, brown on black
    tooth = ["####", "###.", ".#.."]
    for x0 in range(0, W, 4):
        for j, row in enumerate(tooth):
            for i, ch in enumerate(row):
                if ch == '#':
                    cv.px(x0 + i, j, B)
                    cv.px(W - 1 - (x0 + i), H - 1 - j, B)
    for y0 in range(0, H, 4):
        for j, row in enumerate(tooth):
            for i, ch in enumerate(row):
                if ch == '#':
                    cv.px(j, H - 1 - (y0 + i), B)
                    cv.px(W - 1 - j, y0 + i, B)
    cv.occ[:4, :] = cv.occ[-4:, :] = True
    cv.occ[:, :4] = cv.occ[:, -4:] = True
    # inner warm grey line at inset 4
    cv.rect(4, 4, W - 8, 1, GR); cv.rect(4, H - 5, W - 8, 1, GR)
    cv.rect(4, 4, 1, H - 8, GR); cv.rect(W - 5, 4, 1, H - 8, GR)


def reg_mark(cv, x, y):
    cv.rect(x + 2, y, 1, 5, C)
    cv.rect(x, y + 2, 5, 1, C)


def rope(cv, x, y, w, knots):
    for i in range(w):
        for j in range(4):
            k = (i + j) % 4
            c = GR if k < 2 else B
            if (j in (0, 3)) and k in (1, 3):     # round the twist off top and bottom
                c = K
            cv.px(x + i, y + j, c)
    if knots:
        cv.rect(x, y + 1, 2, 2, R)
        cv.rect(x + w - 2, y + 1, 2, 2, R)


# ----------------------------------------------------------------- logo
def logo_layer(seed=7):
    """Return list of (glyph rows with nicks, x, y) for SONAZZOS."""
    rnd = random.Random(seed)
    jitter = [0, 1, 0, 0, 1, 0, 1, 0]
    out = []
    for i, ch in enumerate("SONAZZOS"):
        rows = [list(r) for r in G.LOGO[ch]]
        # chisel nicks: knock 1-2 corner pixels off stroke ends
        cands = []
        for y in range(12):
            for x in range(11):
                if rows[y][x] != '#':
                    continue
                n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < 11 and 0 <= y + dy < 12 and rows[y + dy][x + dx] == '#')
                if n == 2:
                    # true outer corner: both missing neighbours are on different axes
                    hx = any(0 <= x + dx < 11 and rows[y][x + dx] == '#' for dx in (1, -1))
                    hy = any(0 <= y + dy < 12 and rows[y + dy][x] == '#' for dy in (1, -1))
                    if hx and hy and (y in (0, 11) or x in (0, 10)):
                        cands.append((x, y))
        rnd.shuffle(cands)
        for (x, y) in cands[:2]:
            rows[y][x] = '.'
        out.append((["".join(r) for r in rows], 16 + i * 13, 22 + jitter[i]))
    return out


LOGO = logo_layer()


def draw_logo(cv, red_off):
    for rows, x, y in LOGO:
        cv.bitmap(rows, x + red_off, y + red_off, R)
    for rows, x, y in LOGO:
        cv.bitmap(rows, x, y, C)
    s = "MAMOIADA"
    cv.text(s, CX - text_w(s, '3') // 2, 16, GR, '3')


from hero_mask import draw_mask, FACE, dilate, FACE_BOT


# ----------------------------------------------------------------- hero: harness + bells
def strap_line(cv, x0, y0, x1, y1, dy):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for s in range(n + 1):
        x = x0 + (x1 - x0) * s / n
        y = y0 + (y1 - y0) * s / n
        xi, yi = int(round(x)), int(round(y))
        for k in range(4):
            cv.px(xi, yi + k - 2 + dy, B)
        if s % 3 == 0:
            cv.px(xi, yi + dy, GR)   # stitch on the strap centre line


def draw_harness(cv, dy):
    strap_line(cv, 24, 48, 110, 74, dy)
    strap_line(cv, 110, 48, 24, 74, dy)
    # strap ends: a cream rivet and a turned-back tip, so they read as leather, not rays
    for (ex, ey) in ((24, 48), (110, 48), (24, 74), (110, 74)):
        cv.rect(ex - 2, ey - 2 + dy, 5, 4, B)
        cv.px(ex, ey - 1 + dy, C)
        cv.px(ex, ey + dy, C)
    # buckle 7x5 at the crossing (falls under the mask, drawn anyway)
    cv.rect(CX - 3, 58 + dy, 7, 5, GR)
    cv.rect(CX - 1, 60 + dy, 3, 1, K)


BELL_SIZES = [(8, 10), (10, 13), (12, 16), (15, 20), (12, 16), (10, 13), (8, 10)]


def strap_y(x):
    return 108 + int(round(5 * (1 - ((x - CX) / 48.0) ** 2)))


def bell_layout():
    gap = 3
    tot = sum(w for w, _ in BELL_SIZES) + gap * 6
    x = CX - tot // 2
    out = []
    for w, h in BELL_SIZES:
        cxb = x + w // 2
        out.append((x, strap_y(cxb) + 4, w, h))
        x += w + gap
    return out


BELLS = bell_layout()


def bell_shape(w, h):
    """Rows of (left, right) inclusive: rounded crown, straight flaring sides, rolled lip."""
    rows = []
    topw = max(4, int(round(w * 0.55)))
    body_end = h - 3
    for j in range(h):
        if j == 0:
            ww = topw - 2
        elif j <= body_end:
            p = (j - 1) / max(1, body_end - 1)
            ww = topw + (w - 2 - topw) * p
        else:
            ww = w                      # lip flares out the last two rows
        l = int(round((w - ww) / 2))
        rows.append((l, w - 1 - l))
    return rows


def draw_bell(cv, x, y, w, h, tongue):
    rows = bell_shape(w, h)
    # loop handle: two cream legs rising into the strap (the strap is drawn over the arch)
    lx = x + w // 2 - 2 + (w % 2)
    cv.rect(lx, y - 4, 4 - (w % 2) + (w % 2), 1, C)
    for yy in (y - 3, y - 2, y - 1):
        cv.px(lx, yy, C); cv.px(lx + 3, yy, C)
        cv.rect(lx + 1, yy, 2, 1, K)
    bands = {max(2, int(h * 0.28)), int(h * 0.58)}
    for j, (l, r) in enumerate(rows):
        yy = y + j
        cv.rect(x + l, yy, r - l + 1, 1, K)
        cv.px(x + l, yy, C); cv.px(x + r, yy, C)
        if j == 0 or j == h - 1:
            cv.rect(x + l, yy, r - l + 1, 1, C)
            continue
        if j == h - 2:                  # lip: rolled rim, brown under-shadow inside
            cv.rect(x + l + 1, yy, r - l - 1, 1, B)
            continue
        if j >= 2:
            cv.px(x + l + 2, yy, GR)
            if w >= 10:
                cv.px(x + l + 3, yy, GR)
        if j in bands:
            for xx in range(x + l + 1, x + r):
                if cv.a[yy, xx] == K:
                    cv.px(xx, yy, B)
    # tongue (clapper) peeking under the mouth
    big = w >= 12
    tw = 2 if w % 2 == 0 else 1
    tx = x + (w - tw) // 2 + tongue[0]
    ty = y + h + tongue[1]
    cv.rect(tx, ty, tw, 2 if big else 1, C)
    if big:
        cv.rect(tx - 1 + (tw == 2), ty + 2, 3 if tw == 1 else 2, 1, C) if False else None


def draw_bells(cv, dy, tongue):
    order = [0, 6, 1, 5, 2, 4, 3]
    for i in order:
        x, y, w, h = BELLS[i]
        draw_bell(cv, x, y + dy, w, h, tongue)
    # the strap the bells hang from, drawn over their loops: brown arc with warm grey stitches
    for x in range(20, 115):
        y = strap_y(x) + dy
        cv.rect(x, y - 1, 1, 3, B)
        if x % 3 == 0:
            cv.px(x, y, GR)
    for ex in (20, 114):                 # strap ends: cream rivets
        cv.px(ex, strap_y(ex) + dy, C)


# ----------------------------------------------------------------- programme
def block(cv, x, y, w, h, fill, outline=None, shadow=True, thick=1):
    if shadow:
        cv.rect(x + 2, y + h, w, 2, B)
        cv.rect(x + w, y + 2, 2, h, B)
    cv.rect(x, y, w, h, fill)
    if outline is not None:
        for t in range(thick):
            cv.rect(x + t, y + t, w - 2 * t, 1, outline)
            cv.rect(x + t, y + h - 1 - t, w - 2 * t, 1, outline)
            cv.rect(x + t, y + t, 1, h - 2 * t, outline)
            cv.rect(x + w - 1 - t, y + t, 1, h - 2 * t, outline)
    # notched corners (1 px) ...
    for (px_, py_) in [(x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)]:
        cv.px(px_, py_, K)
    # ... plus the 2x2 registration notch top-left
    cv.rect(x, y, 2, 2, K)
    if outline is not None:
        cv.px(x + 2, y + 1, outline); cv.px(x + 1, y + 2, outline)
        cv.px(x + 2, y, outline if False else K)
        cv.px(x, y + 2, K)


def _arrow_bell():
    """11x15 solid arrowhead pointing right with an upright bell knocked out of it."""
    rows = []
    for r in range(15):
        w = 1 + int(round(min(r, 14 - r) * 10 / 7))
        rows.append(["#" if i < w else "." for i in range(11)])
    bell = ["..#..", ".#.#.", ".###.", ".###.", "#####", "#####", "..#.."]
    for j, row in enumerate(bell):
        for i, ch in enumerate(row):
            if ch == '#':
                rows[4 + j][1 + i] = "."
    return ["".join(r) for r in rows]


ARROW_BELL = _arrow_bell()


def draw_continue(cv, pressed, first_launch=False):
    x, y, w, h = 8, 160, 119, 44
    if pressed:
        x += 1; y += 1
        cv.rect(x - 1, y - 1, w + 2, h + 2, K)
        block(cv, x, y, w, h, C, shadow=False)
        ink, bg = K, C
    else:
        block(cv, x, y, w, h, R)
        ink, bg = C, R
    if first_launch:
        s = "START"
        cv.text(s, x + (w - text_w(s)) // 2, y + 14, ink)
        s = "SANT'ANTONIO"
        cv.text(s, x + (w - text_w(s, '3')) // 2, y + 25, ink, '3')
    else:
        cv.text("CONTINUE", x + 8, y + 8, ink)
        cv.text("STOP 4", x + 8, y + 20, ink)
        cv.text("CARNIVAL SUNDAY", x + 8, y + 31, ink)
        # underline under CONTINUE, carved
    cv.bitmap(ARROW_BELL, x + 100, y + (h - 15) // 2, ink)


def draw_small_block(cv, x, y, label, icon):
    block(cv, x, y, 57, 34, K, outline=C)
    cv.bitmap(icon, x + 6, y + 6, C)
    cv.text(label, x + 6, y + 22, C)


def draw_programme(cv, pressed):
    rope(cv, 8, 150, 119, True)
    draw_continue(cv, pressed)
    draw_small_block(cv, 8, 212, "STORY", G.ICON_PROFILE)
    draw_small_block(cv, 70, 212, "SONGS", G.ICON_SONG)
    rope(cv, 8, 254, 119, False)
    # Learn / Ranks: no outline, warm grey
    cv.bitmap(G.ICON_LEARN, 8, 267, GR)
    cv.text("LEARN", 20, 268, GR)
    cv.text("RANKS", 127 - 12 - text_w("RANKS"), 268, GR)
    cv.bitmap(G.ICON_RANKS, 118, 267, GR)
    for x0, w0 in ((8, 40), (87, 40)):
        cv.occ[262:282, x0:x0 + w0] = True
    s = "16 GENNAIO - MARTEDI GRASSO"
    cv.text(s, CX - text_w(s, '3') // 2 + 1, 288, GR, '3')
    cv.occ[286:295, 8:127] = True


def leader(cv, x0, x1, y):
    for x in range(x0, x1, 2):
        cv.px(x, y, B)


def draw_programme_b(cv, pressed):
    """Variant B, Su Programma: Continue is the highlighted date row of the festival calendar."""
    rope(cv, 8, 150, 119, True)
    # past stop, faint brown
    cv.text("SAT 3", 16, 158, B)
    cv.text("STOP 3", 118 - text_w("STOP 3"), 158, B)
    leader(cv, 16 + text_w("SAT 3") + 4, 118 - text_w("STOP 3") - 3, 164)
    # today's row: red carved block
    x, y, w, h = 8, 169, 119, 34
    if pressed:
        x += 1; y += 1
        block(cv, x, y, w, h, C, shadow=False)
        ink = K
    else:
        block(cv, x, y, w, h, R)
        ink = C
    cv.text("SUN 4", x + 8, y + 7, ink)
    cv.text("CONTINUE", x + 96 - text_w("CONTINUE"), y + 7, ink)
    cv.text("CARNIVAL SUNDAY", x + 8, y + 20, ink)
    cv.bitmap(ARROW_BELL, x + 100, y + (h - 15) // 2, ink)
    # next stop, faint brown and locked
    cv.text("MON 5", 16, 209, B)
    cv.text("STOP 5", 118 - text_w("STOP 5"), 209, B)
    leader(cv, 16 + text_w("MON 5") + 4, 118 - text_w("STOP 5") - 3, 215)
    draw_small_block(cv, 8, 221, "STORY", G.ICON_PROFILE)
    draw_small_block(cv, 70, 221, "SONGS", G.ICON_SONG)
    rope(cv, 8, 260, 119, False)
    cv.bitmap(G.ICON_LEARN, 8, 268, GR)
    cv.text("LEARN", 20, 269, GR)
    cv.text("RANKS", 127 - 12 - text_w("RANKS"), 269, GR)
    cv.bitmap(G.ICON_RANKS, 118, 268, GR)
    for x0, w0 in ((8, 40), (87, 40)):
        cv.occ[264:282, x0:x0 + w0] = True
    s = "16 GENNAIO - MARTEDI GRASSO"
    cv.text(s, CX - text_w(s, '3') // 2 + 1, 288, GR, '3')
    cv.occ[286:295, 8:127] = True
    cv.occ[156:218, 8:129] = True


# ----------------------------------------------------------------- chatter
def chatter_layer(occ):
    """Gouge chatter: short parallel runs of 1x2 / 2x1 brown flecks. ~4% far, ~10% near objects."""
    rnd = random.Random(5)
    near = dilate(occ, 3) & ~dilate(occ, 1)
    free = ~dilate(occ, 1)
    out = np.zeros((H, W), bool)
    attempts = 0
    for target, region in ((0.035, free & ~near), (0.08, near)):
        area = region.sum()
        goal = target * area
        ys, xs = np.nonzero(region)
        tries = 0
        while out[region].sum() < goal and tries < 20000:
            tries += 1
            i = rnd.randrange(len(xs))
            x, y = xs[i], ys[i]
            n = rnd.randint(3, 5)
            vert = rnd.random() < 0.6
            pix = []
            for k in range(n):
                if vert:      # 1x2 flecks side by side, stepping like a V-gouge's chatter
                    pix += [(x + 2 * k, y + (k % 2)), (x + 2 * k, y + 1 + (k % 2))]
                else:
                    pix += [(x + (k % 2), y + 2 * k), (x + 1 + (k % 2), y + 2 * k)]
            if all(0 <= px_ < W and 0 <= py_ < H and free[py_, px_] for px_, py_ in pix):
                for px_, py_ in pix:
                    out[py_, px_] = True
    return out


# ----------------------------------------------------------------- compose
def draw_static(cv, pressed, variant=None):
    draw_frame(cv)
    cv.bitmap(G.ICON_WHEEL, 115, 6, C)
    for (x, y) in ((10, 44), (120, 44), (10, 140), (120, 140)):
        reg_mark(cv, x, y)
    (draw_programme_b if variant == 'B' else draw_programme)(cv, pressed)


def draw_hero(cv, m):
    draw_mask(cv, m['mask'])
    # harness straps lie over the fleece, under the face
    draw_harness_over(cv, m)
    draw_bells(cv, m['bells'], m['tongue'])


def draw_harness_over(cv, m):
    # draw straps, then re-stamp the face + kerchief so the straps pass behind the mask
    tmp = Canvas()
    draw_harness(tmp, m['bells'])
    inner = dilate(FACE, 2)
    ys, xs = np.nonzero(tmp.occ)
    for y, x in zip(ys, xs):
        if not inner[y - m['mask'], x]:
            cv.px(x, y, tmp.a[y, x])


_CHATTER = {}


def render(m, pressed=False, variant=None):
    if variant not in _CHATTER:
        base = Canvas()
        draw_static(base, False, variant)
        draw_static(base, True, variant)
        draw_hero(base, REST)
        draw_logo(base, 1)
        base.occ[16:42, 10:125] |= base.occ[16:42, 10:125]
        from hero_mask import FLEECE
        quiet = dilate(FLEECE, 3)          # keep the sheepskin edge clean of chatter
        _CHATTER[variant] = chatter_layer(base.occ | quiet)
    cv = Canvas()
    cv.a[_CHATTER[variant]] = B
    draw_static(cv, pressed, variant)
    draw_logo(cv, m['red'])
    draw_hero(cv, m)
    return cv


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)) + "/out"
    os.makedirs(out, exist_ok=True)
    rest = render(REST)
    rest.image().save(f"{out}/main_screen.png")
    render(REST, pressed=True).image().save(f"{out}/main_screen_pressed.png")
    # ink census
    tot = W * H
    print("ink %:", {n: round(100 * (rest.a == i).sum() / tot, 1)
                     for i, n in enumerate("K C R G B".split())})
    # hero zoom for inspection
    rest.image(1).crop((10, 40, 125, 148)).resize((115 * 6, 108 * 6), Image.NEAREST).save(f"{out}/_hero_zoom.png")
    rest.image(1).crop((0, 0, 135, 45)).resize((135 * 6, 45 * 6), Image.NEAREST).save(f"{out}/_logo_zoom.png")
    render(REST, variant='B').image().save(f"{out}/variant.png")
    render(REST, pressed=True, variant='B').image().save(f"{out}/_variant_pressed.png")
    # animation: 4 beats at 120 BPM = 2 s = 60 frames; frame 60 would equal frame 0 -> clean loop
    n = int(4 * 60 / BPM * FPS)
    for name, var in (("main_screen", None), ("variant", 'B')):
        fdir = f"{out}/_frames_{name}"
        os.makedirs(fdir, exist_ok=True)
        for f in range(n):
            render(motion(f / FPS), variant=var).image().save(f"{fdir}/f{f:03d}.png")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{fdir}/f%03d.png",
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "12", "-preset", "slow",
                        "-movflags", "+faststart", f"{out}/{name}.mp4"], check=True)
    print("frames:", n, [motion(f / FPS)['bells'] for f in range(n)])


if __name__ == "__main__":
    main()
