"""Night menus, round 2: each screen redrawn around its own job.

Shared language with the play screen:
- the main action is a red note (red oval, cream edge); there is one per screen, in thumb reach;
- secondary actions are plain cream words on dotted lane lines, not more ovals;
- states use the note colours: cream = done, red = next or chosen, black in a cream ring = locked.
"""
import math, os, sys
import numpy as np
from PIL import Image
from menus import Cv, tw, W, H, S, INK, CREAM, RED, TAN, BROWN, BELL, GEAR, BACK, PLAY, LOCK, TROPHY, stars, scene_strip

DIM = '#7a6a60'


def note(c, cx, cy, rx, kind, ry=None):
    ry = ry or rx * 0.55
    if kind == 'q':
        c.oval(cx, cy, rx, ry, CREAM)
    elif kind == 'e':
        c.oval(cx, cy, rx + 1, ry + 1, CREAM); c.oval(cx, cy, rx, ry, RED)
    else:
        c.oval(cx, cy, rx, ry, CREAM); c.oval(cx, cy, rx - 2, ry - 1.5, INK)


def dots(c, x0, x1, y, col=BROWN, step=3):
    for x in range(int(x0), int(x1), step):
        c.put(x, y, col)


def vdots(c, x, y0, y1, col=TAN, step=3):
    for y in range(int(y0), int(y1), step):
        c.put(x, y, col)


def base(title=None, back=True):
    c = Cv(INK); stars(c)
    if title:
        if back:
            c.icon(BACK, 6, 8, CREAM)
        c.ctext(title, W / 2, 7, CREAM)
        dots(c, 4, W - 4, 20, TAN)
    return c


def main_button(c, label, y, w=112, sub=None, icon=PLAY):
    """The one red note per screen."""
    h = 25 if sub else 21
    note(c, W / 2, y + h / 2, w / 2, 'e', h / 2)
    lw = tw(label) + (8 if icon else 0)
    x = W / 2 - lw / 2
    ty = y + (4 if sub else 7)
    if sub:
        ty = y + 5
    if icon:
        c.icon(icon, x, ty + 1, CREAM); x += 8
    c.text(label, x, ty, CREAM)
    if sub:
        c.ctext(sub, W / 2, ty + 9, CREAM)


def word_button(c, label, cx, y, col=CREAM):
    c.ctext(label, cx, y, col)


def grade_note(c, g, cx, cy, rx=6):
    if g == 'S':
        c.oval(cx, cy, rx + 2, rx * 0.75 + 2, CREAM)
    c.oval(cx, cy, rx, rx * 0.75, RED)
    c.ctext(g, cx + 0.5, cy - 3, CREAM)


def lock_note(c, cx, cy, rx=6):
    note(c, cx, cy, rx, 'o', rx * 0.75)


# --- 1 title: identity, one obvious next step, three ways in --------------------------------
def title():
    c = base()
    try:
        c.paste(scene_strip(0.3, 2.3)[56:186], 0, 78)
    except Exception:
        pass
    for y in range(78, 96):                         # fade the scene into the sky
        k = (y - 78) / 18
        r = np.random.default_rng(y)
        m = r.random(W) > k
        c.a[y, m] = (20, 16, 20, 255)
    c.rect(0, 200, W, 100, INK); stars(c, 7)
    c.rect(0, 200, W, 1, INK)
    c.icon(BELL, 36, 12, CREAM, 3)
    c.icon(['...#...'], 36, 33, RED, 3)
    c.icon(BELL, 78, 16, CREAM, 3)
    c.icon(['...#...'], 78, 37, RED, 3)
    for k, x in ((-1, 30), (1, 104)):
        for j in range(2):
            c.rect(x + k * j * 4, 18 + j * 3, 2, 8 - j * 2, RED)
    c.ctext('SONAZZOS', W / 2, 50, CREAM, 2)
    c.ctext('MAMOIADA - CARNIVAL', W / 2, 68, TAN)
    main_button(c, 'CONTINUE', 208, 116, 'STOP 4 - CARNIVAL')
    cols = [('STORY', 'q'), ('SONGS', 'e'), ('LEARN', 'o')]
    for i, (lab, k) in enumerate(cols):
        cx = 24 + i * 43.5
        note(c, cx, 247, 7, k)
        c.ctext(lab, cx, 256, CREAM)
    dots(c, 8, W - 8, 272, BROWN)
    c.icon(TROPHY, 9, 281, TAN); c.text('RANKS', 17, 281, TAN)
    c.icon(GEAR, W - 15, 280, TAN)
    return c


# --- 2 story: where am I on the procession, what's next ---------------------------------------
STOPS = [(1, 'THE WORKSHOP', 'WINTER', 'S'), (2, "SANT'ANTONIO", 'JAN 16 - FIRES', 'A'),
         (3, 'THE BONFIRES', 'JAN 17', 'B'), (4, 'CARNIVAL SUNDAY', 'THE FIRST OUTING', None),
         (5, 'THE ROPE', 'CARNIVAL', None), (6, 'THE PIAZZA', 'CARNIVAL', None),
         (7, 'SHROVE TUESDAY', 'THE LAST DAY', None)]


def story():
    c = base('STORY')
    x0 = 18
    y = 34
    vdots(c, x0, 30, 288, TAN, 2)
    for (n, name, day, g) in STOPS:
        if n == 4:                                     # the next stop, open with its picture
            note(c, x0, y + 4, 9, 'e', 6)
            c.ctext(str(n), x0 + 0.5, y + 1, CREAM)
            c.text(name, 32, y, CREAM)
            c.text(day, 32, y + 10, TAN)
            try:
                pic = scene_strip(0.0, 2.3)[70:112, 20:115]
                c.paste(pic, 32, y + 21)
                c.box(31, y + 20, 97, 44, CREAM)
            except Exception:
                pass
            main_button(c, 'PLAY', y + 67, 70, None)
            y += 93
            continue
        done = g is not None
        note(c, x0, y + 4, 9, 'q' if done else 'o', 6)
        c.ctext(str(n), x0 + 0.5, y + 1, INK if done else DIM)
        c.text(name, 32, y, CREAM if done else DIM)
        c.text(day, 32, y + 10, TAN if done else BROWN)
        if done:
            grade_note(c, g, W - 14, y + 7)
        else:
            c.icon(LOCK, W - 17, y + 3, DIM)
        y += 26 if n != 3 else 28
    c.ctext('3 OF 7 STOPS - 1 S', W / 2, H - 9, TAN)
    return c


# --- 3 song card: choose how hard, see what you got, play -------------------------------------
def stop_card():
    c = base('STOP 4')
    try:
        pic = scene_strip(0.0, 2.3)[64:154, 10:125]
        c.paste(pic, 10, 26)
        c.box(9, 25, 117, 92, CREAM)
    except Exception:
        pass
    c.ctext('CARNIVAL SUNDAY', W / 2, 124, CREAM)
    c.ctext('108 BPM - 2:41', W / 2, 135, TAN)
    rows = [('EASY', 1, 'S'), ('MEDIUM', 2, 'A'), ('HARD', 3, 'B'), ('EXPERT', 4, None)]
    y = 152
    for i, (d, dens, g) in enumerate(rows):
        sel = d == 'HARD'
        if sel:
            c.rect(6, y - 3, W - 12, 19, '#2a2024')
            c.box(6, y - 3, W - 12, 19, RED)
        for k in range(4):                          # how dense: up to four small notes
            note(c, 15 + k * 7, y + 6, 3, 'q' if k < dens else 'o', 2)
        c.text(d, 46, y + 3, CREAM if sel else TAN)
        if g:
            grade_note(c, g, W - 16, y + 6, 5)
        else:
            c.ctext('-', W - 16, y + 3, DIM)
        if i < 3:
            dots(c, 10, W - 10, y + 16, BROWN)
        y += 21
    c.text('BEST', 10, 240, TAN); c.rtext('152 480', W - 10, 240, CREAM)
    main_button(c, 'PLAY HARD', 260, 116)
    return c


# --- 4 free play: every song at a glance, jump in fast ---------------------------------------
def free_play():
    c = base('SONGS')
    c.icon(TROPHY, W - 13, 8, CREAM)
    x = 8
    for i, t in enumerate(['ALL', 'ORIGINAL', 'REMIX']):
        w_ = tw(t) + 10
        if i == 0:
            note(c, x + w_ / 2, 32, w_ / 2, 'e', 6)
            c.text(t, x + 5, 29, CREAM)
        else:
            c.text(t, x + 5, 29, TAN)
        x += w_ + 4
    songs = [(1, 'THE WORKSHOP', 80, 'S'), (2, "SANT'ANTONIO", 68, 'A'), (3, 'THE BONFIRES', 100, 'B'),
             (4, 'CARNIVAL SUNDAY', 108, None), (5, 'THE ROPE', 116, 'L'), (6, 'THE PIAZZA', 144, 'L'),
             (7, 'SHROVE TUESDAY', 126, 'L')]
    y = 46
    for (n, nm, bpm, g) in songs:
        open_ = n == 4
        locked = g == 'L'
        if open_:
            c.rect(6, y - 3, W - 12, 52, '#2a2024'); c.box(6, y - 3, W - 12, 52, RED)
        note(c, 15, y + 6, 6, 'o' if locked else ('e' if open_ else 'q'), 4)
        c.ctext(str(n), 15.5, y + 3, DIM if locked else (CREAM if open_ else INK))
        c.text(nm, 27, y, CREAM if not locked else DIM)
        c.text(f'{bpm} BPM', 27, y + 9, TAN if not locked else BROWN)
        if g in ('S', 'A', 'B'):
            grade_note(c, g, W - 15, y + 6, 5)
        elif locked:
            c.icon(LOCK, W - 18, y + 2, DIM)
        if open_:
            for k, d in enumerate('EMHX'):
                cx = 16 + k * 17
                if d == 'H':
                    note(c, cx, y + 31, 7, 'e', 5)
                else:
                    note(c, cx, y + 31, 7, 'o', 5)
                c.ctext(d, cx + 0.5, y + 28, CREAM)
            note(c, W - 30, y + 31, 20, 'e', 8)
            c.icon(PLAY, W - 41, y + 28, CREAM); c.text('PLAY', W - 34, y + 28, CREAM)
            y += 58
        else:
            dots(c, 10, W - 10, y + 19, BROWN)
            y += 24
    return c


# --- 5 results: how did I do, why, what next --------------------------------------------------
def results():
    c = base('RESULTS', back=False)
    c.ctext('CARNIVAL SUNDAY - HARD', W / 2, 28, TAN)
    cx, cy = W / 2, 66
    c.oval(cx, cy, 28, 21, CREAM); c.oval(cx, cy, 26, 19, RED)
    c.oval(cx, cy, 22, 15.5, CREAM); c.oval(cx, cy, 21, 14.5, RED)
    c.ctext('S', cx + 1, cy - 13, CREAM, 4)
    for k in (-1, 1):                               # bell strokes round the grade
        for j in range(3):
            c.rect(cx + k * (34 + j * 5) - 1, cy - 8 + j * 3, 2, 14 - j * 3, CREAM if j else RED)
    c.ctext('184 220', W / 2, 96, CREAM, 2)
    note(c, W / 2, 120, 54, 'e', 6)
    c.ctext('NEW BEST +31 740', W / 2, 117, CREAM)
    # accuracy as one bar, split by judgement
    counts = [('PERFECT', 412, CREAM), ('GREAT', 38, TAN), ('GOOD', 6, DIM), ('MISS', 2, RED)]
    tot = sum(v for _, v, _ in counts)
    x = 10; y = 138; bw = W - 20
    for (k, v, col) in counts:
        w_ = max(2, round(bw * v / tot)) if v else 0
        c.rect(x, y, w_, 6, col); x += w_
    c.box(9, y - 1, bw + 2, 8, BROWN)
    for i, (k, v, col) in enumerate(counts):
        cx_ = 10 + i * 30 + 13
        c.ctext(str(v), cx_, 152, col if col != DIM else TAN)
        c.ctext(k if k != 'PERFECT' else 'PERF', cx_, 162, BROWN if col == DIM else col)
    dots(c, 10, W - 10, 176, BROWN)
    c.text('MAX COMBO', 10, 184, TAN); c.rtext('287', W - 10, 184, CREAM)
    c.text('ACCURACY', 10, 196, TAN); c.rtext('97.8%', W - 10, 196, CREAM)
    c.text('REMIX', 10, 208, TAN); c.rtext('UNLOCKED', W - 10, 208, RED)
    main_button(c, 'NEXT STOP', 236, 116, 'THE ROPE')
    word_button(c, 'RETRY', 36, 270); word_button(c, 'STORY', W - 36, 270)
    vdots(c, W // 2, 266, 282, BROWN)
    return c


# --- 6 pause: back in fast, the song stays in view --------------------------------------------
def pause():
    c = Cv(INK)
    try:
        c.paste(scene_strip(0.86, 3.1), 0, 0)
    except Exception:
        pass
    c.ctext('PAUSED', W / 2, 92, CREAM, 2)
    c.rect(18, 114, W - 36, 3, BROWN); c.rect(18, 114, int((W - 36) * 0.45), 3, RED)
    note(c, 18 + (W - 36) * 0.45, 115.5, 3, 'q', 2.5)
    c.text('1:12', 18, 121, TAN); c.rtext('2:41', W - 18, 121, TAN)
    main_button(c, 'RESUME', 142, 112, '3 2 1 COUNT-IN')
    for i, lab in enumerate(['RESTART', 'SETTINGS', 'QUIT TO STORY']):
        y = 178 + i * 18
        word_button(c, lab, W / 2, y)
        if i < 2:
            dots(c, 30, W - 30, y + 12, BROWN)
    return c


# --- 7 settings: grouped, one screen, no scrolling --------------------------------------------
def settings():
    c = base('SETTINGS')
    groups = [('SOUND', [('MUSIC', 'slider', 0.8), ('EFFECTS', 'slider', 0.6), ('HEADPHONES', 'toggle', 1)]),
              ('PLAY', [('NOTE SPEED', 'value', '7'), ('VIBRATION', 'toggle', 1), ('CALIBRATE', 'go', '+32 MS')]),
              ('OTHER', [('LANGUAGE', 'value', 'EN'), ('CREDITS', 'go', None)])]
    y = 30
    for gname, rows in groups:
        c.text(gname, 8, y, RED)
        y += 12
        for (k, kind, v) in rows:
            c.text(k, 10, y + 3, CREAM)
            rx = W - 10
            if kind == 'slider':
                x0 = rx - 44
                vdots  # lane-line slider with a note as the knob
                c.rect(x0, y + 6, 44, 1, BROWN); c.rect(x0, y + 6, int(44 * v), 1, CREAM)
                note(c, x0 + 44 * v, y + 6.5, 5, 'q', 3)
            elif kind == 'toggle':
                c.oval(rx - 9, y + 6.5, 10, 5.5, CREAM); c.oval(rx - 9, y + 6.5, 9, 4.5, RED)
                c.oval(rx - 4, y + 6.5, 4, 3.5, CREAM)
            elif kind == 'value':
                c.rtext(v, rx - 8, y + 3, CREAM)
                c.icon(['#..', '##.', '###', '##.', '#..'], rx - 3, y + 4, RED)
                c.icon(['..#', '.##', '###', '.##', '..#'], rx - 8 - tw(v) - 6, y + 4, RED)
            else:
                if v:
                    c.rtext(v, rx - 7, y + 3, TAN)
                c.icon(['#..', '##.', '###', '##.', '#..'], rx - 3, y + 4, RED)
            dots(c, 10, W - 10, y + 15, BROWN)
            y += 20
        y += 8
    c.ctext('SONAZZOS 0.9', W / 2, H - 12, BROWN)
    return c


# --- 8 calibration: tap with the sound, see if you're early or late ---------------------------
def calibration():
    c = base('CALIBRATE')
    c.ctext('TAP WHEN THE NOTE', W / 2, 28, CREAM)
    c.ctext('HITS THE RING', W / 2, 38, CREAM)
    for i in range(3):
        note(c, W / 2 - 12 + i * 12, 54, 4, 'e' if i == 1 else ('q' if i == 0 else 'o'), 2.5)
    # one lane of the play screen: the note slides down to the ring
    top, ring = 66, 150
    for y in range(top, ring):
        k = (y - top) / (ring - top)
        hw = 8 + 26 * k
        c.put(W / 2 - hw, y, TAN); c.put(W / 2 + hw, y, TAN)
    note(c, W / 2, 128, 20, 'q', 7)
    c.oval(W / 2, ring, 36, 12, CREAM); c.oval(W / 2, ring, 34, 10.5, INK)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        c.put(W / 2 + math.cos(a) * 31, ring + math.sin(a) * 9, RED)
    c.ctext('BEAT 6 OF 16', W / 2, 168, TAN)
    # the result so far
    c.ctext('+32 MS', W / 2, 182, RED, 2)
    y = 204
    c.rect(18, y, W - 36, 1, BROWN); c.rect(W // 2, y - 4, 1, 9, CREAM)
    r = np.random.default_rng(4)
    for _ in range(6):
        x = int(W / 2 + 7 + r.normal(0, 4))
        note(c, x, y, 2, 'e', 1.5)
    c.text('EARLY', 18, y + 6, BROWN); c.rtext('LATE', W - 18, y + 6, BROWN)
    # the whole bottom is the step button
    c.rect(6, 226, W - 12, 56, '#2a2024'); c.box(6, 226, W - 12, 56, CREAM)
    c.ctext('TAP ANYWHERE HERE', W / 2, 250, CREAM)
    c.ctext('SKIP', W / 2, H - 12, TAN)
    return c


SCREENS = [('title', title), ('story', story), ('stop_card', stop_card), ('free_play', free_play),
           ('results', results), ('pause', pause), ('settings', settings), ('calibration', calibration)]


def render_all(out):
    os.makedirs(out, exist_ok=True)
    for name, fn in SCREENS:
        c = fn()
        Image.fromarray(c.a[..., :3]).resize((W * S, H * S), Image.NEAREST).save(f'{out}/night2_{name}.png')


if __name__ == '__main__':
    render_all(sys.argv[1])
