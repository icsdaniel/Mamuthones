"""The Woodcut look's pixel type for the game: the Controluce menu's 5x7 caps (menu_alt/font.py F5)
with the punctuation and Italian accents the game's strings need, written as a BMFont the Godot
importer reads (fonts/woodcut5.fnt + .png). Lower case is drawn as the capitals: the woodcut is set
in capitals throughout.

    python3 export_font.py <game>/fonts
"""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'menu_alt'))
from font import F5_SRC

G = dict(F5_SRC)
G.update({
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    "?": [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."],
    ",": ["..", "..", "..", "..", "..", ".#", "#."],
    ":": [".", ".", "#", ".", ".", "#", "."],
    ";": ["..", "..", ".#", "..", "..", ".#", "#."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
    "[": ["##", "#.", "#.", "#.", "#.", "#.", "##"],
    "]": ["##", ".#", ".#", ".#", ".#", ".#", "##"],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    "×": [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....."],
    "·": [".", ".", ".", "#", ".", ".", "."],
    "«": [".....", ".....", "..#.#", ".#.#.", "#.#..", ".#.#.", "..#.#"],
    "»": [".....", ".....", "#.#..", ".#.#.", "..#.#", ".#.#.", "#.#.."],
    "’": ["#", "#", ".", ".", ".", ".", "."],
    "\"": ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "…": [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],
    "−": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
    "#": [".#.#.", "#####", ".#.#.", ".#.#.", ".#.#.", "#####", ".#.#."],
    "&": [".##..", "#..#.", ".##..", ".#...", "#.#.#", "#..#.", ".##.#"],
    "*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
    "<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
    ">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
    "@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."],
})
ACC = {"À": ("A", "grave"), "Á": ("A", "acute"), "È": ("E", "grave"), "É": ("E", "acute"),
       "Ì": ("I", "grave"), "Í": ("I", "acute"), "Ò": ("O", "grave"), "Ó": ("O", "acute"),
       "Ù": ("U", "grave"), "Ú": ("U", "acute")}
TOP = 2                     # rows above the capitals, for the accents
LINE = TOP + 7 + 2          # line height: room under the baseline for , ;
BASE = TOP + 7


def glyph(ch):
    if ch in G:
        rows = G[ch]
        a = np.array([[c == "#" for c in r] for r in rows], bool)
        out = np.zeros((TOP + 7 + 1, a.shape[1]), bool)
        out[TOP:TOP + 7] = a
        if ch in ",;":
            out[TOP + 1:TOP + 8] = a
            out[TOP] = False
        return out
    if ch in ACC:
        base, kind = ACC[ch]
        g = glyph(base).copy()
        w = g.shape[1]
        m = w // 2
        if kind == "grave":
            g[0, m - 1] = True; g[1, m] = True
        else:
            g[0, m + 1] = True; g[1, m] = True
        return g
    return None


def main(out):
    chars = sorted(set(G) | set(ACC))
    lower = {c.lower(): c for c in chars if c.lower() != c}
    cells = []
    for ch in chars:
        cells.append((ch, glyph(ch)))
    pad = 1
    W = sum(g.shape[1] + pad for _, g in cells) + pad
    H = LINE + 2
    img = np.zeros((H, W, 4), np.uint8)
    x = pad
    info = {}
    for ch, g in cells:
        h, w = g.shape
        img[1:1 + h, x:x + w][g] = (255, 255, 255, 255)
        info[ch] = (x, 1, w, h)
        x += w + pad
    Image.fromarray(img, 'RGBA').save(os.path.join(out, 'woodcut5.png'))
    lines = ['info face="Woodcut5" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1' % LINE,
             'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0' % (LINE, BASE, W, H),
             'page id=0 file="woodcut5.png"']
    entries = []
    for ch, (x, y, w, h) in info.items():
        entries.append((ord(ch), x, y, w, h))
    for lo, up in lower.items():
        x, y, w, h = info[up]
        entries.append((ord(lo), x, y, w, h))
    lines.append('chars count=%d' % len(entries))
    for cid, x, y, w, h in sorted(entries):
        lines.append('char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15' % (cid, x, y, w, h, w + 1))
    with open(os.path.join(out, 'woodcut5.fnt'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(len(entries), 'glyphs')


if __name__ == '__main__':
    main(sys.argv[1])
