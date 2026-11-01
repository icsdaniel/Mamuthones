import numpy as np
from PIL import Image
from pxkit import to_img
import figure, styles
row=[]
for st,H,sc,bg,op in ((styles.EMBER,46,6,(40,28,48),None),(styles.WOODCUT,70,4,(185,167,132),styles.WOODCUT_CFG.get('fig_opts')),(styles.FESTA,92,3,(150,140,125),styles.FESTA_CFG.get('fig_opts'))):
    f,parts=figure.build(st,H,op)
    r=figure.render_parts(f,parts,st)
    fr=np.concatenate([figure.compose(f,r,i) for i in range(4)],axis=1)
    b=np.zeros_like(fr); b[...]=bg+(255,)
    row.append(to_img(np.where(fr[...,3:4]>0,fr,b),sc))
W=max(i.width for i in row); c=Image.new('RGB',(W,sum(i.height for i in row)),'white'); y=0
for i in row: c.paste(i,(0,y)); y+=i.height
c.save('/tmp/figs.png'); print(c.size)
