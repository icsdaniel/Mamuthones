"""Menu and screen mockups in the lino inks: three directions, eight screens each.

A Print   - cream paper, black ink blocks, red stamps: the game's printed programme.
B Night   - the black street, cream line work, oval buttons shaped like the notes.
C Tickets - festival ticket cards on brown, punched notches and perforations.

Canvas is 135x300 art pixels, shown at 4x (540x1200) like the play screen.
"""
import math, os, sys
import numpy as np
from PIL import Image
from pxkit import hexc

W, H, S = 135, 300, 4
INK, CREAM, RED, TAN, BROWN = '#141014', '#efe6d2', '#c8352a', '#c9bba0', '#4a3c38'

# --- 5x7 font, all caps ------------------------------------------------------------------
F = {
 'A': ".###.#...##...##...#######...##...#", 'B': "####.#...##...#####.#...##...#####.",
 'C': ".###.#...##....#....#....#...#.###.", 'D': "####.#...##...##...##...##...#####.",
 'E': "######....####.#....#....#....#####", 'F': "######....####.#....#....#....#....",
 'G': ".###.#...##....#.####...##...#.####", 'H': "#...##...#######...##...##...##...#",
 'I': ".###...#....#....#....#....#...###.", 'J': "..###...#....#....#....##...#.###..",
 'K': "#...##..#.###..#..#.#...##...##...#",
 'L': "#....#....#....#....#....#....#####", 'M': "#...###.###.#.##...##...##...##...#",
 'N': "#...###..##.#.##..###...##...##...#", 'O': ".###.#...##...##...##...##...#.###.",
 'P': "####.#...##...#####.#....#....#....", 'Q': ".###.#...##...##...##.#.##..#..##.#",
 'R': "####.#...##...#####.#.#..#..#.#...#",
 'S': ".#####....#.....###.....#....#####.", 'T': "#####..#....#....#....#....#....#..",
 'U': "#...##...##...##...##...##...#.###.", 'V': "#...##...##...##...##...#.#.#...#..",
 'W': "#...##...##...##.#.##.#.##.#.#.#.#.",
 'X': "#...##...#.#.#...#...#.#.#...##...#", 'Y': "#...##...#.#.#...#....#....#....#..",
 'Z': "#####....#...#...#...#...#....#####",
 '0': ".###.#...##..###.#.###..##...#.###.", '1': "..#...##....#....#....#....#...###.",
 '2': ".###.#...#....#...#...#...#...#####", '3': "####.....#....#.###.....#....#####.",
 '4': "...#...##..#.#.#..#.#####...#....#.", '5': "######....####.....#....#....#####.",
 '6': ".###.#....#....####.#...##...#.###.", '7': "#####....#...#...#...#....#....#...",
 '8': ".###.#...##...#.###.#...##...#.###.", '9': ".###.#...##...#.####....#....#.###.",
 ' ': "." * 35, '!': "..#....#....#....#....#.........#..", '.': "." * 30 + "..#..",
 ',': "." * 25 + "..#...#...", ':': ".......#.........#..........", "'": "..#....#...#......................",
 '-': "...............###...............", '/': "....#...#...#...#...#...#...#.....",
 '+': ".......#....#..#####..#....#.......", '%': "##..###..#...#...#...#...#..###..##",
 '?': ".###.#...#....#...#...#.........#..", '&': ".##..#..#.#.#...#...#.#.##..#..##.#",
 '<': "...#...#...#...#.....#.....#.....#", '>': "#.....#.....#.....#...#...#...#...",
 '*': "........#.#.#.###.#.#.#.#........",
}


def C(h):
    return np.array(hexc(h) + ((255,) if len(hexc(h)) == 3 else ()), np.uint8)[:4]


class Cv:
    def __init__(self, bg):
        self.a = np.zeros((H, W, 4), np.uint8)
        self.a[...] = C(bg)
        self.Y, self.X = np.mgrid[0:H, 0:W]

    def fill(self, m, col):
        self.a[m] = C(col)

    def rect(self, x, y, w, h, col):
        x, y, w, h = int(round(x)), int(round(y)), int(round(w)), int(round(h))
        self.a[max(0, y):max(0, y + h), max(0, x):max(0, x + w)] = C(col)

    def box(self, x, y, w, h, col, t=1):
        self.rect(x, y, w, t, col); self.rect(x, y + h - t, w, t, col)
        self.rect(x, y, t, h, col); self.rect(x + w - t, y, t, h, col)

    def put(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.a[y, x] = C(col)

    def oval(self, cx, cy, rx, ry, col):
        self.fill(((self.X + 0.5 - cx) / rx) ** 2 + ((self.Y + 0.5 - cy) / ry) ** 2 <= 1, col)

    def text(self, s, x, y, col, sc=1, sp=1):
        x, y = int(round(x)), int(round(y))
        for ch in s.upper():
            g = F.get(ch, F[' ']).ljust(35, '.')
            for i in range(7):
                for j in range(5):
                    if g[i * 5 + j] == '#':
                        self.rect(x + j * sc, y + i * sc, sc, sc, col)
            x += (5 + sp) * sc
        return x

    def ctext(self, s, cx, y, col, sc=1, sp=1):
        self.text(s, int(round(cx - tw(s, sc, sp) / 2)), y, col, sc, sp)

    def rtext(self, s, rx, y, col, sc=1):
        self.text(s, rx - tw(s, sc), y, col, sc)

    def icon(self, rows, x, y, col, sc=1):
        x, y = int(round(x)), int(round(y))
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch == '#':
                    self.rect(x + i * sc, y + j * sc, sc, sc, col)

    def paste(self, arr, x, y):
        h, w = arr.shape[:2]
        self.a[y:y + h, x:x + w] = arr[:max(0, min(h, H - y)), :max(0, min(w, W - x))]


def tw(s, sc=1, sp=1):
    return len(s) * (5 + sp) * sc - sp * sc


HEART = ['.##.##.', '#######', '#######', '.#####.', '..###..', '...#...']
BELL = ['...#...', '..###..', '.#####.', '.#####.', '.#####.', '#######', '...#...']
GEAR = ['..#.#..', '.#####.', '##...##', '.#...#.', '##...##', '.#####.', '..#.#..']
BACK = ['...#...', '..#....', '.######', '..#....', '...#...']
PLAY = ['#....', '###..', '#####', '###..', '#....']
LOCK = ['.###.', '#...#', '#...#', '#####', '##.##', '#####']
TROPHY = ['#####', '#####', '.###.', '..#..', '.###.']
PAUSE = ['##.##', '##.##', '##.##', '##.##', '##.##']
MASK = ['.#####.', '#######', '#.#.#.#', '#######', '##...##', '.#####.', '..###..']

STOPS = [(1, 'THE WORKSHOP', 'WINTER', 'S'), (2, "SANT'ANTONIO", 'JAN 16', 'A'),
         (3, 'THE BONFIRES', 'JAN 17', 'B'), (4, 'CARNIVAL', 'SUNDAY', None),
         (5, 'THE ROPE', 'CARNIVAL', None), (6, 'THE PIAZZA', 'CARNIVAL', None),
         (7, 'SHROVE TUE.', 'LAST DAY', None)]
NEXT = 4


def grain(c, col, seed=1, p=0.035):
    r = np.random.default_rng(seed)
    c.fill(r.random((H, W)) < p, col)


def stars(c, seed=3):
    r = np.random.default_rng(seed)
    for _ in range(40):
        c.put(int(r.random() * W), int(r.random() * H), TAN if r.random() < 0.7 else CREAM)


def gouges(c, col, seed=5):
    """Lino gouge strokes: short diagonal cuts in rows."""
    r = np.random.default_rng(seed)
    for y in range(4, H, 9):
        x = int(r.random() * 10) - 10
        while x < W:
            L = 4 + int(r.random() * 8)
            for k in range(L):
                c.put(x + k, y + k // 3, col)
            x += L + 3 + int(r.random() * 8)


# --- theme widgets -----------------------------------------------------------------------
class Theme:
    def __init__(self, key):
        self.k = key

    # backgrounds
    def bg(self, c):
        if self.k == 'a':
            c.a[...] = C(CREAM); grain(c, TAN)
        elif self.k == 'b':
            c.a[...] = C(INK); stars(c)
        else:
            c.a[...] = C(BROWN); gouges(c, '#3a2e2b')

    @property
    def fg(self):          # text on the background
        return {'a': INK, 'b': CREAM, 'c': CREAM}[self.k]

    @property
    def dim(self):
        return {'a': BROWN, 'b': TAN, 'c': TAN}[self.k]

    def panel(self, c, x, y, w, h, hl=False):
        """A content panel; returns the text colour inside it."""
        if self.k == 'a':
            c.rect(x + 2, y + 2, w, h, INK)                  # printed block shadow
            c.rect(x, y, w, h, RED if hl else CREAM)
            c.box(x, y, w, h, INK)
            return CREAM if hl else INK
        if self.k == 'b':
            c.rect(x, y, w, h, INK)
            col = RED if hl else TAN
            c.box(x, y, w, h, col)
            for (px, py) in ((x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)):
                c.put(px, py, INK)                            # rounded corners
            return CREAM
        # ticket
        c.rect(x, y, w, h, RED if hl else CREAM)
        for py in (y + h // 2 - 2,):
            c.oval(x, py + 2, 3, 3, BROWN); c.oval(x + w, py + 2, 3, 3, BROWN)   # punched notches
        c.box(x + 2, y + 2, w - 4, h - 4, TAN if not hl else CREAM)
        return CREAM if hl else INK

    def button(self, c, label, cx, y, w, primary=False, icon=None):
        h = 15
        x = int(cx - w / 2)
        if self.k == 'a':
            c.rect(x + 2, y + 2, w, h, INK)
            c.rect(x, y, w, h, RED if primary else INK)
            c.box(x + 1, y + 1, w - 2, h - 2, CREAM if primary else BROWN)
            col = CREAM
        elif self.k == 'b':
            c.oval(cx, y + h / 2, w / 2 + 1, h / 2 + 1, CREAM if not primary else CREAM)
            c.oval(cx, y + h / 2, w / 2, h / 2, RED if primary else INK)
            col = CREAM
        else:
            c.rect(x, y, w, h, RED if primary else TAN)
            for k in range(x + 2, x + w - 2, 3):              # perforated top edge
                c.put(k, y, BROWN)
                c.put(k, y + h - 1, BROWN)
            c.box(x + 2, y + 2, w - 4, h - 4, CREAM if primary else BROWN)
            col = CREAM if primary else INK
        lw = tw(label) + (8 if icon else 0)
        tx = int(cx - lw / 2)
        if icon:
            c.icon(icon, tx, y + 5, col); tx += 8
        c.text(label, tx, y + 4, col)

    def header(self, c, title, back=True):
        if self.k == 'a':
            c.rect(0, 0, W, 20, INK)
            c.rect(0, 20, W, 1, RED)
            col = CREAM
        elif self.k == 'b':
            for x in range(4, W - 4, 3):
                c.put(x, 20, TAN)
            col = CREAM
        else:
            c.rect(0, 0, W, 20, INK)
            for x in range(0, W, 4):
                c.put(x, 20, TAN); c.put(x + 1, 20, TAN)
            col = CREAM
        if back:
            c.icon(BACK, 6, 8, col)
        c.ctext(title, W / 2, 7, col)

    def grade(self, c, g, cx, cy, big=False):
        sc = 4 if big else 1
        r = 15 if big else 5
        if self.k == 'a':
            c.oval(cx + (2 if big else 1), cy + (2 if big else 1), r, r, INK)
            c.oval(cx, cy, r, r, RED); c.oval(cx, cy, r - (2 if big else 1), r - (2 if big else 1), RED)
            if big:
                c.fill(((c.X + .5 - cx) ** 2 + (c.Y + .5 - cy) ** 2 <= (r - 2) ** 2) & ((c.X + .5 - cx) ** 2 + (c.Y + .5 - cy) ** 2 > (r - 3) ** 2), CREAM)
            col = CREAM
        elif self.k == 'b':
            ky = 0.62 if big else 0.75
            if g == 'S':
                c.oval(cx, cy, r + (2 if big else 1), (r + (2 if big else 1)) * ky, CREAM)
            c.oval(cx, cy, r, r * ky, RED)
            col = CREAM
        else:
            c.oval(cx, cy, r + 1, r + 1, CREAM)
            c.oval(cx, cy, r, r, RED)
            if big:
                for k in range(16):
                    a = k * math.pi / 8
                    c.put(int(cx + math.cos(a) * (r - 2)), int(cy + math.sin(a) * (r - 2)), CREAM)
            col = CREAM
        c.ctext(g, cx + (0.5 if not big else 0), int(cy - 3.5 * sc), col, sc)


# --- screens -------------------------------------------------------------------------------
def scene_strip(dark=0.55, t=1.0):
    """The play scene (round 38), darkened, as an art-pixel picture."""
    import smooth
    f = smooth.frame(smooth.R38 if dark else smooth.R38, t, 1)[..., :4].astype(float)
    f[..., :3] *= (1 - dark)
    return f.astype(np.uint8)


def title(th):
    c = Cv(INK); th.bg(c)
    if th.k == 'a':
        c.rect(0, 0, W, 132, INK)
        c.icon(BELL, 46, 14, CREAM, 6)
        c.icon(['...#...'], 46, 56, RED, 6)
        for k in (-1, 1):                              # ring strokes
            for j in range(3):
                c.rect(W / 2 + k * (30 + j * 5) - 1, 30 + j * 4, 2, 10 - j * 2, RED)
        c.ctext('SONAZZOS', W / 2, 82, CREAM, 2)
        c.ctext('A MAMOIADA RHYTHM GAME', W / 2, 104, TAN)
        for x in range(0, W, 6):
            c.rect(x, 128, 3, 4, RED)
        y = 150
    elif th.k == 'b':
        try:
            c.paste(scene_strip(0.35, 2.3)[62:166], 0, 196)
        except Exception:
            pass
        c.rect(0, 0, W, 196, INK); stars(c)
        c.rect(0, 0, W, 196, INK); stars(c)
        c.rect(0, 296, W, 4, INK)
        c.icon(BELL, 50, 18, CREAM, 5)
        c.icon(['...#...'], 50, 53, RED, 5)
        c.ctext('SONAZZOS', W / 2, 74, CREAM, 2)
        c.ctext('A MAMOIADA RHYTHM GAME', W / 2, 94, TAN)
        y = 118
    else:
        c.rect(14, 14, W - 28, 110, CREAM)
        c.oval(14, 69, 4, 4, BROWN); c.oval(W - 14, 69, 4, 4, BROWN)
        c.box(17, 17, W - 34, 104, RED)
        c.ctext('ADMIT ONE', W / 2, 24, RED)
        c.icon(BELL, 50, 36, INK, 5)
        c.ctext('SONAZZOS', W / 2, 78, INK, 2)
        for x in range(20, W - 20, 3):
            c.put(x, 98, BROWN)
        c.ctext('MAMOIADA', W / 2, 104, BROWN)
        y = 140
    th.button(c, 'CONTINUE STOP 4', W / 2, y, 112, True, PLAY)
    th.button(c, 'STORY', W / 2, y + 24, 112)
    th.button(c, 'FREE PLAY', W / 2, y + 44, 112)
    th.button(c, 'TUTORIAL', W / 2, y + 64, 112)
    gc = th.fg if th.k != 'a' else INK
    c.icon(GEAR, W - 15, H - 16, gc)
    c.icon(TROPHY, 9, H - 15, gc)
    return c


def story(th):
    c = Cv(INK); th.bg(c); th.header(c, 'STORY')
    y = 28
    for (n, name, day, g) in STOPS:
        locked = n > NEXT
        hl = n == NEXT
        h = 32
        col = th.panel(c, 8, y, W - 18, h - 4, hl)
        if locked:
            col = th.dim if th.k == 'b' else (BROWN if th.k == 'a' else BROWN)
        c.text(str(n), 13, y + 5, col, 2)
        c.text(name, 28, y + 6, col)
        c.text(day, 28, y + 16, RED if (hl and th.k == 'b') else (th.dim if th.k == 'b' else (TAN if hl else BROWN)))
        if g:
            th.grade(c, g, W - 22, y + 14)
        elif locked:
            c.icon(LOCK, W - 25, y + 10, col)
        else:
            c.icon(PLAY, W - 24, y + 10, col)
        if th.k == 'b' and n < 7:
            for k in range(y + h - 4, y + h, 2):
                c.put(16, k, TAN)
        y += h
    return c


def stop_card(th):
    c = Cv(INK); th.bg(c); th.header(c, 'STOP 4')
    col = th.panel(c, 8, 28, W - 18, 92)
    try:
        pic = scene_strip(0.0, 2.3)[60:140, 22:113]
        c.paste(pic, 12, 32)
    except Exception:
        pass
    c.ctext('CARNIVAL SUNDAY', W / 2, 128, th.fg)
    c.ctext('108 BPM - 2:41', W / 2, 139, th.dim)
    y = 152
    for i, d in enumerate(['EASY', 'MEDIUM', 'HARD', 'EXPERT']):
        sel = i == 2
        x = 8 + (i % 2) * 60
        y = 152 + (i // 2) * 17
        if th.k == 'b':
            c.oval(x + 28, y + 7, 29, 7.5, CREAM if sel else TAN)
            c.oval(x + 28, y + 7, 28, 6.5, RED if sel else INK)
            tc = CREAM
        elif th.k == 'a':
            c.rect(x, y, 56, 14, RED if sel else CREAM); c.box(x, y, 56, 14, INK)
            tc = CREAM if sel else INK
        else:
            c.rect(x, y, 56, 14, RED if sel else TAN)
            tc = CREAM if sel else INK
        c.ctext(d, x + 28, y + 4, tc)
    col = th.panel(c, 8, 192, W - 18, 30)
    c.text('BEST', 14, 197, col)
    c.text('152 480', 14, 208, col, 1)
    th.grade(c, 'A', W - 26, 207)
    th.button(c, 'PLAY', W / 2, 234, 110, True, PLAY)
    th.button(c, 'REMIX LOCKED', W / 2, 256, 110, False, LOCK)
    return c


def free_play(th):
    c = Cv(INK); th.bg(c); th.header(c, 'FREE PLAY')
    c.icon(TROPHY, W - 13, 8, CREAM if th.k != 'a' else CREAM)
    tabs = ['ALL', 'ORIGINAL', 'REMIX']
    x = 8
    for i, t in enumerate(tabs):
        w_ = tw(t) + 8
        if i == 0:
            if th.k == 'b':
                c.oval(x + w_ / 2, 33, w_ / 2, 6, RED)
            else:
                c.rect(x, 27, w_, 13, RED)
            c.text(t, x + 4, 30, CREAM)
        else:
            c.text(t, x + 4, 30, th.dim)
        x += w_ + 4
    songs = [('THE WORKSHOP', 80, 'S'), ("SANT'ANTONIO", 68, 'A'), ('THE BONFIRES', 100, 'B'),
             ('CARNIVAL SUNDAY', 108, None), ('THE ROPE', 116, None), ('THE PIAZZA', 144, None)]
    y = 48
    for i, (nm, bpm, g) in enumerate(songs):
        locked = i > 3
        col = th.panel(c, 8, y, W - 18, 30, i == 3)
        if locked:
            col = BROWN if th.k != 'b' else th.dim
        c.text(nm, 14, y + 6, col)
        c.text(f'{bpm} BPM', 14, y + 17, (TAN if i == 3 else (BROWN if th.k != 'b' else TAN)))
        if g:
            th.grade(c, g, W - 22, y + 14)
        elif locked:
            c.icon(LOCK, W - 25, y + 11, col)
        y += 36
    return c


def results(th):
    c = Cv(INK); th.bg(c); th.header(c, 'RESULTS', back=False)
    c.ctext('CARNIVAL SUNDAY', W / 2, 28, th.fg)
    c.ctext('HARD', W / 2, 38, RED if th.k != 'c' else TAN)
    th.grade(c, 'S', W / 2, 72, big=True)
    c.ctext('184 220', W / 2, 98, th.fg, 2)
    c.ctext('NEW BEST +31 740', W / 2, 116, RED if th.k == 'a' else CREAM)
    col = th.panel(c, 8, 132, W - 18, 78)
    rows = [('PERFECT', '412'), ('GREAT', '38'), ('GOOD', '6'), ('MISS', '2'), ('MAX COMBO', '287')]
    for i, (k, v) in enumerate(rows):
        c.text(k, 15, 139 + i * 13, col)
        c.rtext(v, W - 16, 139 + i * 13, RED if (k == 'MISS' and th.k != 'c') else col)
    th.button(c, 'NEXT STOP', W / 2, 224, 100, True, PLAY)
    th.button(c, 'RETRY', W / 2, 246, 100)
    th.button(c, 'STORY', W / 2, 266, 100)
    return c


def pause(th):
    c = Cv(INK)
    try:
        f = scene_strip(0.7, 3.1)
        c.paste(f, 0, 0)
    except Exception:
        pass
    x, y, w_, h_ = 14, 86, W - 28, 128
    if th.k == 'a':
        c.rect(x + 2, y + 2, w_, h_, INK); c.rect(x, y, w_, h_, CREAM); grain_box(c, x, y, w_, h_)
        c.box(x, y, w_, h_, INK); tc = INK
    elif th.k == 'b':
        c.rect(x, y, w_, h_, INK); c.box(x, y, w_, h_, TAN); tc = CREAM
    else:
        c.rect(x, y, w_, h_, BROWN); gouges_box(c, x, y, w_, h_)
        c.box(x, y, w_, h_, TAN); tc = CREAM
    c.icon(PAUSE, W / 2 - 2, y + 9, RED)
    c.ctext('PAUSED', W / 2, y + 20, tc, 1)
    th.button(c, 'RESUME', W / 2, y + 38, 84, True, PLAY)
    th.button(c, 'RESTART', W / 2, y + 60, 84)
    th.button(c, 'SETTINGS', W / 2, y + 80, 84)
    th.button(c, 'QUIT', W / 2, y + 100, 84)
    return c


def grain_box(c, x, y, w, h):
    r = np.random.default_rng(9)
    m = (r.random((h, w)) < 0.035)
    sub = c.a[y:y + h, x:x + w]
    sub[m] = C(TAN)


def gouges_box(c, x, y, w, h):
    for yy in range(y + 4, y + h, 9):
        for xx in range(x + (yy * 7) % 9, x + w - 6, 13):
            for k in range(6):
                c.put(xx + k, yy + k // 3, '#3a2e2b')


def settings(th):
    c = Cv(INK); th.bg(c); th.header(c, 'SETTINGS')
    rows = [('MUSIC', 'slider', 0.8), ('EFFECTS', 'slider', 0.6), ('VIBRATION', 'toggle', 1),
            ('NOTE SPEED', 'value', '7'), ('HEADPHONES', 'toggle', 1), ('CALIBRATE', 'go', None),
            ('LANGUAGE', 'value', 'EN'), ('CREDITS', 'go', None)]
    y = 30
    for i, (k, kind, v) in enumerate(rows):
        if i in (5,):
            y += 6
        col = th.panel(c, 8, y, W - 18, 24)
        c.text(k, 14, y + 9, col)
        rx = W - 16
        if kind == 'slider':
            x0 = rx - 40
            c.rect(x0, y + 11, 40, 2, th.dim if th.k != 'a' else TAN)
            c.rect(x0, y + 11, int(40 * v), 2, RED)
            if th.k == 'b':
                c.oval(x0 + 40 * v, y + 12, 4, 3, CREAM)
            else:
                c.rect(int(x0 + 40 * v) - 2, y + 8, 4, 8, INK if th.k == 'a' else RED)
                c.box(int(x0 + 40 * v) - 2, y + 8, 4, 8, CREAM if th.k != 'a' else INK)
        elif kind == 'toggle':
            if th.k == 'b':
                c.oval(rx - 8, y + 12, 9, 5, RED); c.oval(rx - 4, y + 12, 4, 4, CREAM)
            else:
                c.rect(rx - 18, y + 7, 18, 10, RED); c.rect(rx - 9, y + 8, 8, 8, CREAM)
                if th.k == 'a':
                    c.box(rx - 18, y + 7, 18, 10, INK)
        elif kind == 'value':
            c.rtext(f'< {v} >', rx, y + 9, RED if th.k != 'c' else RED)
        else:
            c.icon(PLAY, rx - 6, y + 10, RED)
        y += 28
    c.ctext('SONAZZOS 0.9', W / 2, H - 14, th.dim)
    return c


def calibration(th):
    c = Cv(INK); th.bg(c); th.header(c, 'CALIBRATE')
    c.ctext('TAP ON EACH BEAT', W / 2, 30, th.fg)
    c.ctext('STEP 2 OF 3', W / 2, 41, th.dim)
    for i in range(3):
        cx = W / 2 - 12 + i * 12
        if th.k == 'b':
            c.oval(cx, 56, 4, 2.5, RED if i < 2 else TAN)
        else:
            c.rect(int(cx) - 3, 53, 6, 6, RED if i < 2 else (TAN if th.k == 'c' else BROWN))
    # the pulsing ring: hit ring of the play screen, lit on the beat
    cy = 112
    c.oval(W / 2, cy, 44, 18, CREAM if th.k != 'a' else INK)
    c.oval(W / 2, cy, 41, 16, INK if th.k != 'a' else CREAM)
    c.oval(W / 2, cy, 30, 11.5, RED)
    c.oval(W / 2, cy, 27, 10, INK if th.k != 'a' else CREAM)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        c.put(int(W / 2 + math.cos(a) * 36), int(cy + math.sin(a) * 14), RED)
    c.ctext('BEAT 6 / 16', W / 2, 140, th.fg)
    col = th.panel(c, 8, 158, W - 18, 46)
    c.ctext('AUDIO DELAY', W / 2, 165, col)
    c.ctext('+32 MS', W / 2, 178, RED if th.k != 'c' else RED, 2)
    # tap timing dots: early left, late right
    y = 220
    c.rect(18, y, W - 36, 1, th.dim)
    c.rect(int(W / 2), y - 4, 1, 9, th.fg)
    r = np.random.default_rng(4)
    for _ in range(9):
        x = int(W / 2 + 6 + r.normal(0, 5))
        c.rect(x, y - 2, 2, 5, RED)
    c.text('EARLY', 18, y + 6, th.dim); c.rtext('LATE', W - 18, y + 6, th.dim)
    th.button(c, 'TAP', W / 2, 250, 100, True)
    c.ctext('OR SKIP', W / 2, 274, th.dim)
    return c


SCREENS = [('title', title), ('story', story), ('stop_card', stop_card), ('free_play', free_play),
           ('results', results), ('pause', pause), ('settings', settings), ('calibration', calibration)]


def render_all(out):
    os.makedirs(out, exist_ok=True)
    sheets = {}
    for k in 'abc':
        th = Theme(k)
        row = []
        for name, fn in SCREENS:
            c = fn(th)
            im = Image.fromarray(c.a[..., :3]).resize((W * S, H * S), Image.NEAREST)
            im.save(f'{out}/menu_{k}_{name}.png')
            row.append(im)
        gap = 24
        sheet = Image.new('RGB', (len(row) * (W * S + gap) - gap, H * S), (32, 28, 30))
        for i, im in enumerate(row):
            sheet.paste(im, (i * (W * S + gap), 0))
        sheet.save(f'{out}/menus_{k}_sheet.png')
        sheets[k] = sheet
    return sheets


if __name__ == '__main__':
    render_all(sys.argv[1])
