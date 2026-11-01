"""Export the lino round: still, animated play screen, figure bob, parts."""
import os, sys, shutil, numpy as np
from PIL import Image
from pxkit import to_img, hexc
import figure, render, lino

tag = sys.argv[1]; OUT = sys.argv[2]; page = sys.argv[3]
cfg = lino.CFG
os.makedirs(f'{OUT}/parts', exist_ok=True)
img = render.still(cfg, 0.6, 0)
to_img(img, 1).save(f'{OUT}/play_1x.png')
to_img(img, 6).save(f'{OUT}/play_1080x2400.png')
render.gif(cfg, f'{OUT}/play_animated.gif', 2)
f, parts = figure.build(lino.FIG, 96, lino.FIG_OPTS)
rp = figure.render_parts(f, parts, lino.FIG)
for k, a in rp.items():
    to_img(a, 1).save(f'{OUT}/parts/{k}.png')
kl = np.array(hexc(lino.CREAM), np.uint8)
frames = [figure.compose(f, rp, i, kl) for i in range(4)]
to_img(np.concatenate(frames, 1), 1).save(f'{OUT}/mamuthone_sheet.png')
g = []
for a in frames:
    b = np.zeros_like(a); b[...] = (20, 16, 20, 255)
    g.append(to_img(np.where(a[..., 3:4] > 0, a, b), 3).convert('RGB'))
g[0].save(f'{OUT}/mamuthone_bob.gif', save_all=True, append_images=g[1:], duration=figure.BOB_TIMES_MS, loop=0)
# before / after: round 1 W2 next to the new version, same on-screen size
before = Image.open('/mnt/project-files/pixel-styles/woodcut-r1/w2_lino_red/play_1080x2400.png').resize((540, 1200), Image.NEAREST)
after = to_img(img, 3)
c = Image.new('RGB', (1100, 1200), (40, 40, 40)); c.paste(before, (0, 0)); c.paste(after, (560, 0))
c.save(f'{OUT}/before_after.png')
for src, dst in (('play_animated.gif', 'play.gif'), ('mamuthone_bob.gif', 'bob.gif'), ('before_after.png', 'before_after.png'), ('play_1080x2400.png', 'play.png')):
    shutil.copy(f'{OUT}/{src}', f'{page}/{tag}_{dst}')
print('ok')
