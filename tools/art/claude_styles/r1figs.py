import numpy as np
from PIL import Image
from pxkit import to_img
import figure, woodcut
row=[]
for k,cfg in woodcut.R1.items():
    st=cfg['style']; f,p=figure.build(st,70,cfg['fig_opts']); r=figure.render_parts(f,p,st)
    from pxkit import hexc
    a=figure.compose(f,r,0,np.array(hexc(cfg['keyline']),np.uint8) if cfg.get('keyline') else None); b=np.zeros_like(a)
    b[...]= (np.array(list(int(cfg['pal']['sky'][0][i:i+2],16) for i in (1,3,5))+[255]))
    row.append(to_img(np.where(a[...,3:4]>0,a,b),4))
c=Image.new('RGB',(sum(i.width for i in row),row[0].height)); x=0
for i in row: c.paste(i,(x,0)); x+=i.width
c.save('/tmp/r1f.png')
