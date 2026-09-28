// Painterly figure engine for Fire Night (Canvas 2D). Figures are drawn in unit space:
// height 1, feet at y=0, head top near y=-1, +x = the way the figure faces.
// L = +1 when the fire is on the figure's +x side, -1 when it is behind/opposite.
let cx=null, L=1, UH=100, SMALL=false; // SMALL: game-size tuning (fewer, crisper highlights) // current ctx, light side, unit height in px (for hairline widths)
function rngS(seed){let a=seed>>>0;return ()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
const px=n=>n/UH; // n screen pixels in unit space
function mv(p){cx.moveTo(p[0],p[1]);}
// smooth closed/open path through points (Catmull-Rom -> Bezier). Points may carry a 3rd flag 1 = sharp corner.
function path(pts,closed=true,t=0.5){cx.beginPath();const n=pts.length;const P=i=>closed?pts[(i+n)%n]:pts[Math.max(0,Math.min(n-1,i))];
 cx.moveTo(pts[0][0],pts[0][1]);const m=closed?n:n-1;
 for(let i=0;i<m;i++){const p0=P(i-1),p1=P(i),p2=P(i+1),p3=P(i+2);
  if(p1[2]||p2[2]){cx.lineTo(p2[0],p2[1]);continue;}
  const k=t/3;cx.bezierCurveTo(p1[0]+(p2[0]-p0[0])*k,p1[1]+(p2[1]-p0[1])*k,p2[0]-(p3[0]-p1[0])*k,p2[1]-(p3[1]-p1[1])*k,p2[0],p2[1]);}
 if(closed)cx.closePath();}
function poly(pts){cx.beginPath();pts.forEach((p,i)=>i?cx.lineTo(p[0],p[1]):cx.moveTo(p[0],p[1]));cx.closePath();}
function lgr(x0,y0,x1,y1,stops){const q=cx.createLinearGradient(x0,y0,x1,y1);stops.forEach(([o,c])=>q.addColorStop(o,c));return q;}
function rgr(x,y,r,stops,x0,y0,r0=0){const q=cx.createRadialGradient(x0??x,y0??y,r0,x,y,r);stops.forEach(([o,c])=>q.addColorStop(o,c));return q;}
// horizontal light gradient across [x0,x1]: cols[0] = shadow side, last = lit side
function sh(x0,x1,cols,y=0,tilt=0){const a=L>0?x0:x1,b=L>0?x1:x0;return lgr(a,y+tilt,b,y-tilt,cols.map((c,i)=>[i/(cols.length-1),c]));}
function fillP(pts,style,closed=true){path(pts,closed);cx.fillStyle=style;cx.fill();}
function strokeP(pts,style,w,closed=false){path(pts,closed);cx.strokeStyle=style;cx.lineWidth=w;cx.lineCap='round';cx.lineJoin='round';cx.stroke();}
function ellU(x,y,rx,ry,rot=0){cx.beginPath();cx.ellipse(x,y,Math.max(1e-4,rx),Math.max(1e-4,ry),rot,0,Math.PI*2);}
// resample a closed smooth outline into n points (approx, along polygon)
function resample(pts,n){const segs=[];let tot=0;for(let i=0;i<pts.length;i++){const a=pts[i],b=pts[(i+1)%pts.length];const d=Math.hypot(b[0]-a[0],b[1]-a[1]);segs.push([a,b,d]);tot+=d;}
 const out=[];for(let k=0;k<n;k++){let s=k/n*tot;for(const [a,b,d] of segs){if(s<=d){const t=d?s/d:0;out.push([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t]);break;}s-=d;}}return out;}
// shaggy fleece outline: tufts hang (gravity), tips are pointy
function shag(pts,n,amp,seed,from=0,to=1){const r=rngS(seed);const rs=resample(pts,n);let cxm=0,cym=0;pts.forEach(p=>{cxm+=p[0];cym+=p[1];});cxm/=pts.length;cym/=pts.length;
 const out=[];rs.forEach((p,i)=>{const f=i/n;if(f<from||f>to){out.push([p[0],p[1],1]);return;}const q=rs[(i+1)%n],o=rs[(i-1+n)%n];let nx=q[1]-o[1],ny=-(q[0]-o[0]);const d=Math.hypot(nx,ny)||1;nx/=d;ny/=d;
  // make normal point outward
  if((p[0]-cxm)*nx+(p[1]-cym)*ny<0){nx=-nx;ny=-ny;}
  const a=amp*(0.5+r()*0.9);out.push([p[0]-nx*amp*0.15,p[1]-ny*amp*0.15,1]);out.push([p[0]+nx*a+ (r()-0.5)*amp*0.5,p[1]+ny*a+Math.max(0,ny)*a*0.6+a*0.35,1]);});
 return out;}
// fur strokes inside current clip
function fur(x0,y0,x1,y1,n,seed,len,cols,wpx=1.2,lean=0){const r=rngS(seed);cx.lineCap='round';
 for(let i=0;i<n;i++){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);const lit=L>0?(x-x0)/(x1-x0):(x1-x)/(x1-x0);
  const c=cols(lit,r(),y);if(!c)continue;cx.strokeStyle=c;cx.lineWidth=px(wpx)*(0.7+r()*0.8);const l=len*(0.6+r()*0.8);
  const bx=(r()-0.5)*l*0.6+lean*l;cx.beginPath();cx.moveTo(x,y);cx.quadraticCurveTo(x+bx*0.2+l*0.15*(r()-0.5),y+l*0.5,x+bx,y+l);cx.stroke();}}
// a bronze cowbell (campanaccio): body is a flared trapezoid with the mouth pointing along angle a (radians, 0 = down)
function cowbell(x,y,s,a=0,seed=1,bright=1){cx.save();cx.translate(x,y);cx.rotate(a);const r=rngS(seed);
 const w0=0.46*s,w1=0.9*s,h=1.05*s;
 const pts=[[-w0/2,-h/2],[0,-h/2-0.08*s],[w0/2,-h/2],[w0*0.62,-h*0.1],[w1/2,h/2,1],[-w1/2,h/2,1],[-w0*0.62,-h*0.1]];
 path(pts);cx.fillStyle=lgr(-w1/2,0,w1/2,0,[[0,'#0c0603'],[0.5,'#22140a'],[0.8,'#3e2610'],[1,'#1a0f06']]);cx.fill();
 // top-lit shoulder of the bell (the fire is tall and above)
 cx.save();path(pts);cx.clip();cx.fillStyle=lgr(0,-h/2,0,h*0.1,[[0,`rgba(255,180,100,${0.3*bright})`],[1,'rgba(255,150,80,0)']]);cx.fillRect(-w1,-h,2*w1,h);cx.restore();
 cx.strokeStyle='#1a0e05';cx.lineWidth=0.1*s;cx.beginPath();cx.arc(0,-h/2-0.04*s,0.13*s,Math.PI,0);cx.stroke();
 ellU(0,h/2,w1/2,0.12*s);cx.fillStyle='#070302';cx.fill();
 // bright lip
 cx.beginPath();cx.ellipse(0,h/2,w1/2,0.12*s,0,Math.PI*0.05,Math.PI*0.95);cx.strokeStyle=`rgba(230,150,70,${0.45*bright})`;cx.lineWidth=0.05*s;cx.stroke();
 if(SMALL){cx.globalCompositeOperation='lighter';ellU(0,-h*0.2,w0*0.35,h*0.22);cx.fillStyle=`rgba(255,170,80,${0.35*bright})`;cx.fill();cx.globalCompositeOperation='source-over';}
 if(bright>0.3){cx.globalCompositeOperation='lighter';const gx=(r()<0.5?-1:1)*w0*0.22;ellU(gx,-0.12*s,0.035*s,0.22*s,-0.1);cx.fillStyle=`rgba(255,200,120,${0.45*bright})`;cx.fill();cx.globalCompositeOperation='source-over';}
 cx.restore();}
// hanging wool locks (clumps): roots inside the shape, tips may overhang the edge (natural shaggy outline).
// Each clump: dark body, a cool-grey sheen at the root, a warm edge where it faces the fire.
function locks(pts,x0,y0,x1,y1,seed,o={}){const r=rngS(seed);const n=o.n??160;const len=o.len??0.1,wid=o.wid??0.05;const list=[];
 for(let i=0;i<n*4&&list.length<n;i++){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0);if(!ipp(pts,x,y))continue;list.push([x,y,r(),r(),r(),r()]);}
 list.sort((a,b)=>b[1]-a[1]);
 for(const [x,y,q1,q2,q3,q4] of list){const k=Math.max(0,Math.min(1,L>0?(x-x0)/(x1-x0):(x1-x)/(x1-x0)));
  const l=len*(0.65+q1*0.7),w=wid*(0.7+q2*0.6),dx=(q3-0.5)*l*0.35+(o.lean??0)*l;
  // lobe with a wavy two-point tip
  const tip1=[x+dx-w*0.18,y+l],tip2=[x+dx+w*0.22,y+l*0.9];
  const shape=()=>{cx.beginPath();cx.moveTo(x-w/2,y);cx.bezierCurveTo(x-w*0.62,y+l*0.45,tip1[0]-w*0.25,y+l*0.8,tip1[0],tip1[1]);cx.quadraticCurveTo(x+dx,y+l*0.8,tip2[0],tip2[1]);cx.bezierCurveTo(tip2[0]+w*0.2,y+l*0.6,x+w*0.62,y+l*0.4,x+w/2,y);cx.closePath();};
  const top=o.form===false?(q4<0.5?'#1c181d':'#141116'):`rgb(${Math.round(16+34*k*k+10*q4)},${Math.round(13+22*k*k+8*q4)},${Math.round(17+14*k*k+8*q4)})`;
  shape();cx.fillStyle=lgr(0,y,0,y+l,[[0,top],[0.55,'#09080a'],[1,'#030203']]);cx.fill();
  cx.save();shape();cx.clip();
  // fire side: glossy strands catching the fire; night side: faint cool sheen
  const th0=SMALL?0.78:0.5;const kk=k>th0?Math.pow((k-th0)/(1-th0),1.1)*(o.key??1):0;const sg=L>0?1:-1;
  if(kk>0.02){for(let m=0;m<3;m++){const off=(0.45-m*0.2)*w*sg;const al=Math.min(0.95,(0.25+0.75*kk)*(1-m*0.28));
    cx.strokeStyle=`rgba(255,${130+90*kk-m*20},${50+60*kk-m*15},${al})`;cx.lineWidth=Math.max(px(0.9),w*(0.12-m*0.025));
    cx.beginPath();cx.moveTo(x+off*0.9,y+l*0.04);cx.quadraticCurveTo(x+off*1.05+dx*0.3,y+l*0.5,x+dx+off*0.5,y+l*(0.92-m*0.08));cx.stroke();}}
  else{cx.strokeStyle=`rgba(110,110,150,${0.18+0.12*q4})`;cx.lineWidth=Math.max(px(0.8),w*0.09);cx.beginPath();cx.moveTo(x-sg*w*0.3,y+l*0.05);cx.quadraticCurveTo(x-sg*w*0.35+dx*0.3,y+l*0.4,x+dx-sg*w*0.15,y+l*0.75);cx.stroke();}
  // strand grooves
  cx.strokeStyle='rgba(0,0,0,0.5)';cx.lineWidth=Math.max(px(0.8),w*0.07);cx.beginPath();cx.moveTo(x+(q3-0.5)*w*0.4,y+l*0.1);cx.quadraticCurveTo(x+dx*0.5,y+l*0.55,x+dx,y+l*0.95);cx.stroke();
  cx.restore();}}
function ipp(pts,x,y){let c=false;for(let i=0,j=pts.length-1;i<pts.length;j=i++){const [xi,yi]=pts[i],[xj,yj]=pts[j];if(((yi>y)!=(yj>y))&&(x<(xj-xi)*(y-yi)/(yj-yi)+xi))c=!c;}return c;}
// small round bell (sonajolo) with a slit
function sonajo(x,y,r){ellU(x,y,r,r);cx.fillStyle=rgr(x,y,r,[[0,'#ffe2a0'],[0.35,'#c8862e'],[1,'#3a1f08']],x+L*r*0.4,y-r*0.4);cx.fill();
 cx.strokeStyle='#1a0c04';cx.lineWidth=r*0.25;cx.beginPath();cx.moveTo(x-r*0.5,y+r*0.3);cx.lineTo(x+r*0.5,y+r*0.3);cx.stroke();}

// ---- render a figure into an offscreen buffer, light it, and composite it at (x,y) with height h
// opts: flip (+1 faces right, -1 faces left), light (+1 fire on screen-right, -1 on screen-left),
// rim warm/cool colours, key strength, amb (0..1 darkening of the shadow side)
function figure(g,draw,x,y,h,opts={}){const flip=opts.flip??1,lw=opts.light??1;const pad=Math.ceil(h*0.06)+4;
 const bx0=opts.bx0??-0.75,bx1=opts.bx1??0.75,by0=opts.by0??-1.45,by1=0.08;
 const W_=Math.ceil((bx1-bx0)*h)+2*pad,H_=Math.ceil((by1-by0)*h)+2*pad;
 const oc=document.createElement('canvas');oc.width=W_;oc.height=H_;const c=oc.getContext('2d');
 const ox=flip>0?pad-bx0*h:W_-pad+bx0*h,oy=pad-by0*h;
 c.save();c.translate(ox,oy);c.scale(flip*h,h);cx=c;L=lw*flip;UH=h;draw(opts);c.restore();
 // light pass 1: darken the side away from the fire (cool ambient), brighten toward it
 const lay=document.createElement('canvas');lay.width=W_;lay.height=H_;const l=lay.getContext('2d');
 const gx0=lw>0?0:W_,gx1=lw>0?W_:0;
 const gr=l.createLinearGradient(gx0,H_*0.2,gx1,H_*0.0);gr.addColorStop(0,opts.shadowTint??'rgba(50,50,100,1)');gr.addColorStop(0.5,'rgba(170,160,190,1)');gr.addColorStop(1,'rgba(255,255,255,1)');
 l.fillStyle=gr;l.fillRect(0,0,W_,H_);l.globalCompositeOperation='destination-in';l.drawImage(oc,0,0);
 c.globalCompositeOperation='multiply';c.drawImage(lay,0,0);c.globalCompositeOperation='source-over';
 // key light: warm soft-light wash from the fire side
 {const k2=document.createElement('canvas');k2.width=W_;k2.height=H_;const q=k2.getContext('2d');const gg=q.createLinearGradient(gx0,0,gx1,0);gg.addColorStop(0,'rgba(255,140,60,0)');gg.addColorStop(0.55,'rgba(255,140,60,0)');gg.addColorStop(1,`rgba(255,150,70,${opts.key??0.3})`);
  q.fillStyle=gg;q.fillRect(0,0,W_,H_);q.globalCompositeOperation='destination-in';q.drawImage(oc,0,0);c.globalCompositeOperation='soft-light';c.drawImage(k2,0,0);c.globalCompositeOperation='source-over';}
 // form light: broad warm bands falling off inward from the fire-side silhouette edge
 const band=(D,blur,col,alpha,mode,dy=0)=>{const r=document.createElement('canvas');r.width=W_;r.height=H_;const q=r.getContext('2d');
  q.drawImage(oc,0,0);q.globalCompositeOperation='source-in';q.fillStyle=col;q.fillRect(0,0,W_,H_);q.globalCompositeOperation='destination-out';q.drawImage(oc,-lw*D,-dy);
  const r2=document.createElement('canvas');r2.width=W_;r2.height=H_;const q2=r2.getContext('2d');q2.filter=`blur(${blur}px)`;q2.drawImage(r,0,0);q2.filter='none';q2.globalCompositeOperation='destination-in';q2.drawImage(oc,0,0);
  c.save();c.globalCompositeOperation=mode;c.globalAlpha=alpha;c.drawImage(r2,0,0);c.restore();};
 if(opts.form!==false){band(h*0.035,h*0.014,opts.formCol??'#ff7a2a',opts.formA??0.32,'screen',h*0.01);band(h*0.012,h*0.004,'#ffa060',opts.dodgeA??0.3,'color-dodge',h*0.005);}
 // light pass 2: warm rim on the fire side, cool rim on the night side
 const rim=(col,dx,dy,blur,alpha)=>{const r=document.createElement('canvas');r.width=W_;r.height=H_;const q=r.getContext('2d');
  q.drawImage(oc,0,0);q.globalCompositeOperation='source-in';q.fillStyle=col;q.fillRect(0,0,W_,H_);
  q.globalCompositeOperation='destination-out';q.drawImage(oc,-dx,-dy);
  c.save();c.globalCompositeOperation='source-atop';c.globalAlpha=alpha;if(blur)c.filter=`blur(${blur}px)`;c.drawImage(r,0,0);c.restore();};
 const d=Math.max(SMALL?2:1,h*(opts.rimW??0.006));
 rim(opts.warm??'#ffb366',lw*d,-d*0.5,Math.max(0,h*0.002),opts.warmA??0.95);
 rim(opts.hot??'#fff0c8',lw*d*0.4,-d*0.2,0,opts.hotA??0.5);
 rim(opts.cool??'#6f86ff',-lw*d*0.6,-d*0.5,Math.max(0,h*0.002),opts.coolA??0.3);
 if(opts.paint)kuwahara(oc,opts.paint);
 // brush texture and lost edges (painterly): short directional strokes in overlay; the shadow-side contour dissolves
 if(opts.brush){const b=document.createElement('canvas');b.width=W_;b.height=H_;const q=b.getContext('2d');const r=rngS(31);q.lineCap='round';
  const n=Math.round(W_*H_/90);for(let i=0;i<n;i++){const x=r()*W_,y=r()*H_,l=h*(0.01+r()*0.025),a=-1.1+r()*0.5;const v=r()<0.5?0:255;q.strokeStyle=`rgba(${v},${v},${v},${0.25+r()*0.35})`;q.lineWidth=Math.max(1,h*(0.003+r()*0.005));q.beginPath();q.moveTo(x,y);q.lineTo(x+Math.cos(a)*l,y+Math.sin(a)*l);q.stroke();}
  q.globalCompositeOperation='destination-in';q.drawImage(oc,0,0);c.save();c.globalCompositeOperation='overlay';c.globalAlpha=opts.brushA??0.35;c.drawImage(b,0,0);c.restore();
  const e=document.createElement('canvas');e.width=W_;e.height=H_;const q2=e.getContext('2d');const D=h*0.012;q2.drawImage(oc,0,0);q2.globalCompositeOperation='destination-out';q2.drawImage(oc,lw*D,-D*0.3);
  const e2=document.createElement('canvas');e2.width=W_;e2.height=H_;const q3=e2.getContext('2d');q3.filter=`blur(${h*0.006}px)`;q3.drawImage(e,0,0);
  c.save();c.globalCompositeOperation='destination-out';c.globalAlpha=opts.lostA??0.55;c.drawImage(e2,0,0);c.restore();}
 // ground shadow and warm floor light
 if(opts.shadow!==false){g.save();g.fillStyle='rgba(0,0,0,0.55)';g.beginPath();g.ellipse(x-lw*h*0.06,y+h*0.005,h*0.28,h*0.045,0,0,Math.PI*2);g.fill();g.restore();}
 g.drawImage(oc,x-ox,y-oy);return oc;}
function silhouette(g,draw,x,y,h,opts={}){const oc=document.createElement('canvas');const flip=opts.flip??1;const pad=4,bx0=-0.75,bx1=0.75,by0=-1.45;
 const W_=Math.ceil(1.5*h)+2*pad,H_=Math.ceil(1.53*h)+2*pad;oc.width=W_;oc.height=H_;const c=oc.getContext('2d');const ox=flip>0?pad-bx0*h:W_-pad+bx0*h,oy=pad-by0*h;
 c.save();c.translate(ox,oy);c.scale(flip*h,h);cx=c;L=flip;UH=h;draw(opts);c.restore();c.globalCompositeOperation='source-in';c.fillStyle=opts.col??'#000';c.fillRect(0,0,W_,H_);g.drawImage(oc,x-ox,y-oy);}
// Kuwahara filter (painterly simplification) on a canvas, radius r. Works on premultiplied colour so edges stay clean.
function kuwahara(canvas,r){const w=canvas.width,h=canvas.height;const c=canvas.getContext('2d');const im=c.getImageData(0,0,w,h);const d=im.data;
 const W1=w+1;const N=W1*(h+1);const S=[new Float64Array(N),new Float64Array(N),new Float64Array(N),new Float64Array(N),new Float64Array(N)];
 for(let y=0;y<h;y++){let a0=0,a1=0,a2=0,a3=0,a4=0;for(let x=0;x<w;x++){const i=(y*w+x)*4;const al=d[i+3]/255;const R=d[i]*al,G=d[i+1]*al,B=d[i+2]*al;const lum=0.3*R+0.59*G+0.11*B;
  a0+=R;a1+=G;a2+=B;a3+=d[i+3];a4+=lum*lum;const j=(y+1)*W1+x+1,k=y*W1+x+1;S[0][j]=S[0][k]+a0;S[1][j]=S[1][k]+a1;S[2][j]=S[2][k]+a2;S[3][j]=S[3][k]+a3;S[4][j]=S[4][k]+a4;}}
 const box=(t,x0,y0,x1,y1)=>t[(y1+1)*W1+x1+1]-t[y0*W1+x1+1]-t[(y1+1)*W1+x0]+t[y0*W1+x0];
 const out=c.createImageData(w,h);const o=out.data;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){let best=1e30,bi=null;
  for(const [dx,dy] of [[-1,-1],[1,-1],[-1,1],[1,1]]){const x0=Math.max(0,dx<0?x-r:x),x1=Math.min(w-1,dx<0?x:x+r),y0=Math.max(0,dy<0?y-r:y),y1=Math.min(h-1,dy<0?y:y+r);const n=(x1-x0+1)*(y1-y0+1);
   const R=box(S[0],x0,y0,x1,y1)/n,G=box(S[1],x0,y0,x1,y1)/n,B=box(S[2],x0,y0,x1,y1)/n;const lum=0.3*R+0.59*G+0.11*B;const v=box(S[4],x0,y0,x1,y1)/n-lum*lum;
   if(v<best){best=v;bi=[R,G,B,box(S[3],x0,y0,x1,y1)/n];}}
  const i=(y*w+x)*4;const A=d[i+3];if(A===0){continue;}const al=Math.max(1e-3,bi[3]/255);o[i]=bi[0]/al;o[i+1]=bi[1]/al;o[i+2]=bi[2]/al;o[i+3]=A;}
 c.putImageData(out,0,0);}
