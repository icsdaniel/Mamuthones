// Direction A, "Fire Night": warm painterly night of Sant'Antonio in Mamoiada.
let cv=document.getElementById('c');let g=cv?cv.getContext('2d'):null;
const R=rng(7);
const C={night0:'#05041a',night1:'#120d3a',night2:'#231652',ink:'#07060f',ember:'#ff7a1f',gold:'#ffc84a',hot:'#fff3cf',crim:'#c8181e',crimD:'#5a0710',bone:'#f3e6c8',bronze:'#c98a2e'};
function lg(x0,y0,x1,y1,stops){const q=g.createLinearGradient(x0,y0,x1,y1);stops.forEach(([o,c])=>q.addColorStop(o,c));return q;}
function rg(x,y,r0,r1,stops,x1,y1){const q=g.createRadialGradient(x,y,r0,x1??x,y1??y,r1);stops.forEach(([o,c])=>q.addColorStop(o,c));return q;}
function ell(x,y,rx,ry){g.beginPath();g.ellipse(x,y,Math.max(0.1,rx),Math.max(0.1,ry),0,0,Math.PI*2);}
function roadPoly(z0,z1,u0,u1){const y0=yOfZ(z0),y1=yOfZ(z1);g.beginPath();g.moveTo(360+u0*wOfY(y0)/2,y0);g.lineTo(360+u1*wOfY(y0)/2,y0);g.lineTo(360+u1*wOfY(y1)/2,y1);g.lineTo(360+u0*wOfY(y1)/2,y1);g.closePath();}

// ---------- sky, smoke, skyline, fire ----------
function sky(){g.fillStyle=lg(0,0,0,H,[[0,C.night0],[0.12,C.night1],[0.2,'#2a1650'],[0.5,'#0b0820'],[1,'#050409']]);g.fillRect(0,0,W,H);
 // stars, only high up and away from the fire
 for(let i=0;i<120;i++){const x=R()*W,y=R()*170;if(Math.abs(x-360)<150&&y>60)continue;const a=0.25+R()*0.6;g.fillStyle=`rgba(230,225,255,${a})`;g.fillRect(x,y,R()<0.1?2:1,R()<0.1?2:1);}
 // big warm bloom of the bonfire over the whole upper field
 g.globalCompositeOperation='lighter';
 g.fillStyle=rg(360,185,0,560,[[0,'rgba(255,140,40,0.55)'],[0.25,'rgba(220,70,30,0.28)'],[0.55,'rgba(120,30,60,0.12)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,0,W,900);
 g.globalCompositeOperation='source-over';
 // smoke columns catching the light
 for(let i=0;i<14;i++){const x=300+R()*120+(i-7)*6,y=150-i*9-R()*10,r=40+i*7;g.fillStyle=rg(x,y,0,r,[[0,`rgba(255,150,90,${0.10-i*0.005})`],[1,'rgba(80,40,80,0)']]);g.fillRect(x-r,y-r,2*r,2*r);}}
function skyline(){const base=204;g.fillStyle='#0a0716';
 // stone houses of Mamoiada, left and right of the fire
 const houses=[[0,150,70],[60,162,60],[110,140,55],[160,170,50],[205,176,40],[470,174,45],[510,160,55],[560,145,65],[620,165,50],[662,150,60]];
 houses.forEach(([x,top,w])=>{g.beginPath();g.moveTo(x,base);g.lineTo(x,top+8);g.lineTo(x+w*0.5,top);g.lineTo(x+w,top+8);g.lineTo(x+w,base);g.closePath();g.fill();});
 // bell tower of the parish church, left of the fire
 g.beginPath();g.moveTo(150,base);g.lineTo(150,96);g.lineTo(163,80);g.lineTo(176,96);g.lineTo(176,base);g.closePath();g.fill();g.fillRect(162,68,2,14);g.fillRect(158,72,10,2);
 g.fillStyle='rgba(255,170,80,0.85)';g.fillRect(158,104,10,14);g.fillStyle='#0a0716';g.fillRect(162,104,2,14);
 // warm windows and fire-lit walls facing the square
 [[40,176],[92,184],[128,170],[520,182],[585,170],[640,186],[700,178]].forEach(([x,y])=>{g.fillStyle='rgba(255,160,70,0.9)';g.fillRect(x,y,7,9);g.fillStyle='rgba(255,140,60,0.25)';g.fillRect(x-4,y-4,15,17);});
 g.globalCompositeOperation='lighter';g.fillStyle=rg(360,200,40,300,[[0,'rgba(255,120,40,0.35)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,100,W,120);g.globalCompositeOperation='source-over';}
function flame(x,y,w,h,col0,col1,lean){g.beginPath();g.moveTo(x-w/2,y);g.bezierCurveTo(x-w/2,y-h*0.45,x-w*0.1+lean*0.5,y-h*0.6,x+lean,y-h);g.bezierCurveTo(x+w*0.15+lean*0.5,y-h*0.55,x+w/2,y-h*0.4,x+w/2,y);g.closePath();g.fillStyle=lg(x,y,x,y-h,[[0,col0],[1,col1]]);g.fill();}
function tongue(x,y,w,h,lean,c0,c1){g.beginPath();g.moveTo(x-w/2,y);g.bezierCurveTo(x-w*0.55,y-h*0.35,x-w*0.25+lean*0.4,y-h*0.7,x+lean,y-h);g.bezierCurveTo(x+w*0.1+lean*0.5,y-h*0.62,x+w*0.6,y-h*0.38,x+w/2,y);g.closePath();g.fillStyle=lg(x,y,x+lean,y-h,[[0,c0],[0.55,c0],[1,c1]]);g.fill();}
function vnoise(seed){const h=(i,j)=>{let n=Math.imul(i,374761393)+Math.imul(j,668265263)+seed*1442695;n=Math.imul(n^(n>>>13),1274126177);return ((n^(n>>>16))>>>0)/4294967296;};
 const sm=t=>t*t*(3-2*t);return (x,y)=>{const i=Math.floor(x),j=Math.floor(y),fx=sm(x-i),fy=sm(y-j);const a=h(i,j),b=h(i+1,j),c=h(i,j+1),d=h(i+1,j+1);return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy;};}
function fbm(n,x,y){let v=0,a=0.5,f=1;for(let k=0;k<5;k++){v+=a*n(x*f,y*f);a*=0.5;f*=2.03;}return v;}
function bonfire(){const bx=360,by=200;const r=rng(21);
 g.globalCompositeOperation='lighter';g.fillStyle=rg(bx,by-80,0,280,[[0,'rgba(255,190,90,0.8)'],[0.35,'rgba(255,100,30,0.4)'],[1,'rgba(0,0,0,0)']]);g.fillRect(bx-300,by-340,600,440);g.globalCompositeOperation='source-over';
 // painterly flame field: turbulent noise inside a tall cone, mapped through the fire ramp
 const X0=170,Y0=-30,FW=380,FH=240;const oc=document.createElement('canvas');oc.width=FW;oc.height=FH;const oc2=oc.getContext('2d');const im=oc2.createImageData(FW,FH);
 const n1=vnoise(3),n2=vnoise(9);const ramp=[[0.0,[90,8,20,0]],[0.16,[120,12,22,150]],[0.3,[200,34,24,230]],[0.48,[250,98,28,250]],[0.64,[255,160,48,255]],[0.8,[255,214,110,255]],[0.92,[255,246,210,255]],[1,[255,255,245,255]]];
 const col=t=>{t=Math.max(0,Math.min(1,t));for(let i=1;i<ramp.length;i++)if(t<=ramp[i][0]){const [a,ca]=ramp[i-1],[b,cb]=ramp[i];const k=(t-a)/(b-a);return ca.map((v,j)=>v+(cb[j]-v)*k);}return ramp[ramp.length-1][1];};
 for(let py=0;py<FH;py++)for(let px=0;px<FW;px++){const x=X0+px,y=Y0+py;const v=(by-y)/225,u=(x-bx)/150;if(v<-0.05)continue;
  const t1=fbm(n1,x*0.018,y*0.009-3),t2=fbm(n2,x*0.045,y*0.02);const uu=u+(t1-0.5)*0.9*Math.max(0,v)+(t2-0.5)*0.25;
  const w=Math.max(0.02,1.05*(1-Math.max(0,v))**0.9);let I=(1-Math.abs(uu)/w)*1.35-Math.max(0,v)*0.6+0.08+(t2-0.5)*0.5+(t1-0.5)*0.35;if(v<0)I*=1+v*8;
  if(I<=0)continue;const c=col(I);const o=(py*FW+px)*4;im.data[o]=c[0];im.data[o+1]=c[1];im.data[o+2]=c[2];im.data[o+3]=c[3];}
 oc2.putImageData(im,0,0);g.drawImage(oc,X0,Y0);
 // the pyre: heaped logs silhouetted at the base, rims glowing
 for(let i=0;i<12;i++){const t=r(),lx=bx+(r()-0.5)*260*(1-t*0.4),ly=by-2-t*12,len=40+r()*50,a=(r()-0.5)*0.7;g.save();g.translate(lx,ly);g.rotate(a);g.fillStyle='#1a0c08';g.fillRect(-len/2,-4,len,8);g.fillStyle=`rgba(255,${130+r()*90},50,${0.55+r()*0.4})`;g.fillRect(-len/2,-5,len,2);g.restore();}
 g.globalCompositeOperation='lighter';g.fillStyle=rg(bx,by,0,140,[[0,'rgba(255,200,110,0.55)'],[1,'rgba(0,0,0,0)']]);g.fillRect(bx-150,by-60,300,80);g.globalCompositeOperation='source-over';
 // sparks rising into the night
 for(let i=0;i<110;i++){const a=r(),x=bx+(r()-0.5)*320*(0.3+a),y=by-80-a*230;g.fillStyle=r()<0.5?'rgba(255,230,140,0.95)':'rgba(255,130,40,0.9)';const s=r()<0.25?3:2;g.fillRect(x,y,s,s);}}
// ---------- ground beside the road and the road itself ----------
function ground(rings=true){ // the square beside the road: cobbles warmed by the fire, a crowd at the edge, beat rings
 g.fillStyle=lg(0,TOPY,0,HITY,[[0,'#2c1620'],[0.25,'#150c1d'],[1,'#07060c']]);g.fillRect(0,TOPY,W,HITY-TOPY);
 const r=rng(5);for(let z=0.1;z<ZMAX;z+=0.035){const y=yOfZ(z),sc=wOfY(y)/720;for(let x=-20;x<W+20;x+=46*sc+8){const xx=x+(r()-0.5)*10*sc;const warm=Math.max(0,1-Math.hypot(xx-360,(y-TOPY)*1.6)/600);g.fillStyle=`rgba(${40+warm*150},${24+warm*60},${40+warm*10},${0.35})`;ell(xx,y,20*sc+3,6*sc+1.5);g.fill();}}
 g.globalCompositeOperation='lighter';g.fillStyle=rg(360,TOPY,0,520,[[0,'rgba(255,120,40,0.34)'],[0.5,'rgba(160,50,40,0.10)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,TOPY,W,700);
 // beat rings rolling out from the fire across the square
 if(rings){g.save();g.beginPath();g.rect(0,TOPY+2,W,H);g.clip();
 [[330,120,0.5],[560,230,0.3],[800,360,0.16]].forEach(([rx,ry,a])=>{g.strokeStyle=`rgba(255,150,60,${a})`;g.lineWidth=5;ell(360,TOPY+8,rx,ry);g.stroke();g.strokeStyle=`rgba(255,220,150,${a*0.6})`;g.lineWidth=1.5;ell(360,TOPY+8,rx,ry);g.stroke();});
 g.restore();}g.globalCompositeOperation='source-over';
 // the crowd watching from the edge of the square, rim-lit
 const cr=rng(11);for(const side of [-1,1])for(let i=0;i<16;i++){const x=side<0?4+i*13+cr()*6:716-i*13-cr()*6;if(side<0&&x>edgeL(TOPY)-6)continue;if(side>0&&x<edgeR(TOPY)+6)continue;const hh=26+cr()*12,y=TOPY+6;
  g.fillStyle='#08060c';g.beginPath();g.ellipse(x,y-hh*0.25,9,hh*0.45,0,Math.PI,0);g.fill();ell(x,y-hh*0.72,5.5,6.5);g.fill();
  g.strokeStyle='rgba(255,150,70,0.7)';g.lineWidth=1.5;g.beginPath();g.arc(x,y-hh*0.72,6,side<0?-0.6:Math.PI-0.9,side<0?0.9:Math.PI+0.6);g.stroke();}}
function road(){ // calm dark stone, warm at the far end; no busy texture where notes travel
 roadPoly(-0.12,ZMAX,-1,1);g.fillStyle=lg(0,TOPY,0,BTN_Y,[[0,'#3a1d22'],[0.18,'#23142a'],[0.55,'#130d22'],[1,'#0b0816']]);g.fill();
 g.save();roadPoly(-0.12,ZMAX,-1,1);g.clip();
 // fire reflection: one soft warm streak down the middle, fading long before the hit line
 g.globalCompositeOperation='lighter';g.fillStyle=rg(360,TOPY,0,560,[[0,'rgba(255,130,50,0.30)'],[0.6,'rgba(255,90,40,0.06)'],[1,'rgba(0,0,0,0)']],360,TOPY);g.fillRect(0,TOPY,W,700);
 // very faint cobble courses (low contrast so notes stay clean)
 g.globalCompositeOperation='source-over';for(let z=0.05;z<ZMAX;z+=0.09){const y=yOfZ(z);g.strokeStyle=`rgba(255,200,160,${0.025+0.02*(z/ZMAX)})`;g.lineWidth=1;g.beginPath();g.moveTo(edgeL(y),y);g.lineTo(edgeR(y),y);g.stroke();}
 g.restore();
 // lane dividers: thin warm light, dashed pulses travelling toward the player
 for(const u of [-1/3,1/3]){for(let z=0;z<ZMAX;z+=0.02){const y0=yOfZ(z),y1=yOfZ(z+0.02);const pulse=Math.max(0,Math.cos((z*6.0)*Math.PI))**6;const a=0.32+0.5*pulse*(1-z/ZMAX*0.6);
  g.strokeStyle=`rgba(255,196,120,${a})`;g.lineWidth=Math.max(1.2,3.5*wOfY(y0)/720);g.beginPath();g.moveTo(360+u*wOfY(y0)/2,y0);g.lineTo(360+u*wOfY(y1)/2,y1);g.stroke();}}
 // road edges: glowing ember rails
 for(const s of [-1,1]){g.save();g.shadowColor='rgba(255,100,30,0.95)';g.shadowBlur=18;
  g.strokeStyle=lg(0,TOPY,0,HITY,[[0,'#ffcf7a'],[0.5,'#ff7a1f'],[1,'#ff5a1a']]);g.lineWidth=5;g.beginPath();g.moveTo(360+s*wOfY(TOPY)/2,TOPY);g.lineTo(360+s*wOfY(BTN_Y)/2,BTN_Y);g.stroke();
  g.shadowBlur=0;g.strokeStyle='rgba(255,245,220,0.9)';g.lineWidth=1.5;g.beginPath();g.moveTo(360+s*wOfY(TOPY)/2,TOPY);g.lineTo(360+s*wOfY(BTN_Y)/2,BTN_Y);g.stroke();g.restore();
  // beat pulses: bright beads on the rails
  for(const z of [0.18,0.52,0.9,1.3]){const y=yOfZ(z),x=360+s*wOfY(y)/2,r=10*wOfY(y)/720+3;g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,r*4,[[0,'rgba(255,230,160,0.9)'],[0.3,'rgba(255,120,40,0.4)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-r*4,y-r*4,r*8,r*8);g.globalCompositeOperation='source-over';}}
 // far end lip where notes emerge from the firelight
 g.fillStyle='rgba(255,200,120,0.55)';g.fillRect(edgeL(TOPY),TOPY-1,wOfY(TOPY),2);}

// ---------- Mamuthones and Issohadores beside the road ----------
function tuftPath(pts,amp,seed){const r=rng(seed);g.beginPath();pts.forEach(([x,y],i)=>{if(i==0)g.moveTo(x,y);else{const [px,py]=pts[i-1];const mx=(px+x)/2,my=(py+y)/2;const nx=-(y-py),ny=x-px;const l=Math.hypot(nx,ny)||1;const k=amp*(0.6+r()*0.8);g.quadraticCurveTo(mx+nx/l*k,my+ny/l*k,x,y);}});g.closePath();}
function files(){for(const side of [-1,1]){const zs=[0.44,0.66,0.85,1.03,1.22];zs.forEach((z,i)=>{const y=yOfZ(z),w=wOfY(y);const gap=0.10*w+14;const x=side<0?edgeL(y)-gap:edgeR(y)+gap;
  if(i==0)issohadore(x,y,0.21*w,-side,90+i);else mamuthone(x,y,0.2*w,-side,i*1.7+(side>0?0.8:0),30+i*7+(side>0?50:0));});}}

// ---------- notes ----------
function noteShadow(x,y,rx,ry){g.fillStyle='rgba(0,0,0,0.55)';ell(x,y+ry*0.9,rx*1.08,ry*0.9);g.fill();}
function gem(x,y,sc,lit){const rx=0.3*240*sc,ry=rx*0.38,t=rx*0.16;
 g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y+t,0,rx*1.7,[[0,'rgba(255,140,50,0.38)'],[1,'rgba(0,0,0,0)']]);g.save();g.scale(1,0.45);g.fillRect(x-rx*1.8,(y+t)/0.45-rx*1.8,rx*3.6,rx*3.6);g.restore();g.globalCompositeOperation='source-over';
 noteShadow(x,y+t,rx,ry);
 g.save();g.shadowColor='rgba(255,120,30,0.9)';g.shadowBlur=24*sc+6;
 g.fillStyle='#5a0710';ell(x,y+t,rx,ry);g.fill();g.fillRect(x-rx,y,2*rx,t);g.restore();
 // bevelled crimson rim and hot gold face
 g.fillStyle=lg(0,y-ry,0,y+ry,[[0,'#ff5a2a'],[1,'#8a0d14']]);ell(x,y,rx,ry);g.fill();
 g.fillStyle=rg(x-rx*0.15,y-ry*0.35,0,rx*0.8,[[0,'#ffffff'],[0.3,'#fff0b8'],[0.65,'#ffc13a'],[1,'#ff7a1f']]);ell(x,y-ry*0.05,rx*0.78,ry*0.72);g.fill();
 g.strokeStyle='rgba(90,10,10,0.9)';g.lineWidth=Math.max(1,2*sc);ell(x,y-ry*0.05,rx*0.78,ry*0.72);g.stroke();
 g.strokeStyle='rgba(255,250,230,0.9)';g.lineWidth=Math.max(1,2.4*sc);g.beginPath();g.ellipse(x,y,rx,ry,0,Math.PI*1.08,Math.PI*1.92);g.stroke();
 g.fillStyle='rgba(255,255,255,0.95)';ell(x-rx*0.32,y-ry*0.32,rx*0.16,ry*0.14);g.fill();
 g.strokeStyle='#1a0306';g.lineWidth=Math.max(1,2*sc);ell(x,y+t*0.5,rx+1,ry+t*0.5+1);g.stroke();}
function step(l,z){const y=yOfZ(z);gem(laneX(l,y),y,wOfY(y)/720);}
function hold(l,z0,z1){const u0=(l-0.17)*2/3,u1=(l+0.17)*2/3;
 g.save();g.shadowColor='rgba(255,60,30,0.8)';g.shadowBlur=20;roadPoly(z0,z1,u0,u1);g.fillStyle=lg(0,yOfZ(z1),0,yOfZ(z0),[[0,'#8a0d14'],[1,'#d8201f']]);g.fill();g.restore();
 g.save();roadPoly(z0,z1,u0,u1);g.clip();
 // woven sash: gold lozenges down the centre, darker weave between
 for(let z=z0;z<z1;z+=0.012){roadPoly(z,z+0.005,u0,u1);g.fillStyle='rgba(60,0,8,0.28)';g.fill();}
 for(let z=z0+0.03;z<z1-0.02;z+=0.07){const ya=yOfZ(z+0.025),yb=yOfZ(z-0.025),ym=yOfZ(z),xm=laneX(l,ym),hw=0.12*laneW(ym);g.beginPath();g.moveTo(xm,ya);g.lineTo(xm+hw,ym);g.lineTo(xm,yb);g.lineTo(xm-hw,ym);g.closePath();g.fillStyle='#ffc84a';g.fill();g.strokeStyle='#5a0710';g.lineWidth=1.5;g.stroke();}
 g.restore();
 for(const u of [u0,u1]){g.strokeStyle='#ffd27a';g.lineWidth=3;g.beginPath();const y0=yOfZ(z0),y1=yOfZ(z1);g.moveTo(360+u*wOfY(y0)/2,y0);g.lineTo(360+u*wOfY(y1)/2,y1);g.stroke();}
 // end cap: hollow gold ring
 const ye=yOfZ(z1),xe=laneX(l,ye),sc=wOfY(ye)/720,rx=0.24*240*sc,ry=rx*0.38;g.save();g.shadowColor='rgba(255,200,90,0.9)';g.shadowBlur=14;g.strokeStyle='#ffd27a';g.lineWidth=6*sc+2;ell(xe,ye,rx,ry);g.stroke();g.restore();
 step(l,z0);}
function bellBar(z,dir){const z1=z+0.045;const y0=yOfZ(z),y1=yOfZ(z1);const t=10*wOfY(y0)/720;
 g.fillStyle='rgba(0,0,0,0.5)';roadPoly(z-0.02,z1-0.01,-1,1);g.fill();
 g.save();g.shadowColor='rgba(255,170,60,0.8)';g.shadowBlur=22;g.fillStyle='#5a3208';g.beginPath();g.moveTo(edgeL(y0),y0);g.lineTo(edgeR(y0),y0);g.lineTo(edgeR(y0),y0+t);g.lineTo(edgeL(y0),y0+t);g.fill();g.restore();
 roadPoly(z,z1,-1,1);g.fillStyle=lg(0,y1,0,y0,[[0,'#fff1c0'],[0.35,'#f2b64a'],[1,'#b0681c']]);g.fill();g.strokeStyle='#2a1204';g.lineWidth=2;g.stroke();
 // chevrons: raise (up) or lower (down)
 const n=6,ym=(y0+y1)/2,hh=(y0-y1)*0.32;for(let i=0;i<n;i++){const u=-0.86+i*(1.72/(n-1));if(Math.abs(u)<0.2)continue;const x=360+u*wOfY(ym)/2,wd=hh*1.6;
  g.strokeStyle='#3a1604';g.lineWidth=4;g.lineJoin='round';g.beginPath();g.moveTo(x-wd,ym+hh*dir);g.lineTo(x,ym-hh*dir);g.lineTo(x+wd,ym+hh*dir);g.stroke();}
 // central medallion with a bell
 const r=(y0-y1)*0.95;g.save();g.shadowColor='rgba(255,60,30,0.9)';g.shadowBlur=16;g.fillStyle='#c8181e';ell(360,ym,r*1.2,r);g.fill();g.restore();
 g.strokeStyle='#ffe0a0';g.lineWidth=3;ell(360,ym,r*1.2,r);g.stroke();
 g.fillStyle='#ffe0a0';g.beginPath();g.moveTo(360-r*0.5,ym+r*0.45);g.quadraticCurveTo(360-r*0.45,ym-r*0.55,360,ym-r*0.6);g.quadraticCurveTo(360+r*0.45,ym-r*0.55,360+r*0.5,ym+r*0.45);g.closePath();g.fill();ell(360,ym+r*0.55,r*0.12,r*0.1);g.fill();}
function rope(z,l0,l1){const y=yOfZ(z),sc=wOfY(y)/720;const xa=laneX(l0,y)-0.3*laneW(y),xb=laneX(l1,y)+0.25*laneW(y);const th=16*sc+4;
 g.fillStyle='rgba(0,0,0,0.5)';ell((xa+xb)/2,y+th*0.9,(xb-xa)/2,th*0.5);g.fill();
 g.save();g.shadowColor='rgba(255,210,140,0.8)';g.shadowBlur=14;g.lineCap='round';g.strokeStyle='#6b4a22';g.lineWidth=th+4;g.beginPath();g.moveTo(xa,y);g.bezierCurveTo(xa+(xb-xa)*0.3,y-th*0.8,xa+(xb-xa)*0.6,y+th*0.8,xb-th,y);g.stroke();g.restore();
 g.strokeStyle='#f0d9a4';g.lineWidth=th;g.lineCap='round';g.beginPath();g.moveTo(xa,y);g.bezierCurveTo(xa+(xb-xa)*0.3,y-th*0.8,xa+(xb-xa)*0.6,y+th*0.8,xb-th,y);g.stroke();
 // twist marks
 for(let i=1;i<14;i++){const t=i/14,u=1-t;const px=u*u*u*xa+3*u*u*t*(xa+(xb-xa)*0.3)+3*u*t*t*(xa+(xb-xa)*0.6)+t*t*t*(xb-th),py=u*u*u*y+3*u*u*t*(y-th*0.8)+3*u*t*t*(y+th*0.8)+t*t*t*y;g.strokeStyle='#8a6230';g.lineWidth=Math.max(1.5,3*sc);g.beginPath();g.moveTo(px-th*0.3,py+th*0.45);g.lineTo(px+th*0.3,py-th*0.45);g.stroke();}
 // arrowhead: swipe direction
 g.save();g.shadowColor='rgba(255,230,160,1)';g.shadowBlur=16;g.fillStyle='#fff3cf';g.beginPath();g.moveTo(xb+th*0.6,y);g.lineTo(xb-th*1.1,y-th*1.1);g.lineTo(xb-th*0.8,y);g.lineTo(xb-th*1.1,y+th*1.1);g.closePath();g.fill();g.restore();}
function standStill(z){const z1=z+0.05;const y0=yOfZ(z),y1=yOfZ(z1);
 roadPoly(z,z1,-1,1);g.fillStyle='rgba(18,20,48,0.85)';g.fill();
 g.save();roadPoly(z,z1,-1,1);g.clip();g.strokeStyle='rgba(190,205,255,0.8)';g.lineWidth=5*wOfY(y0)/720+1;for(let x=-80;x<800;x+=22){g.beginPath();g.moveTo(x,y0);g.lineTo(x+(y0-y1)*1.2,y1);g.stroke();}g.restore();
 g.strokeStyle='#dfe6ff';g.lineWidth=2;roadPoly(z,z1,-1,1);g.stroke();
 const ym=(y0+y1)/2;g.font='bold 15px "DejaVu Sans"';g.textAlign='center';g.textBaseline='middle';const tw=g.measureText('STAND STILL').width+16;g.fillStyle='#10132e';g.fillRect(360-tw/2,ym-10,tw,20);g.strokeStyle='#dfe6ff';g.strokeRect(360-tw/2,ym-10,tw,20);g.fillStyle='#eef2ff';g.fillText('STAND STILL',360,ym+1);}

// ---------- hit line, receptors, hit burst ----------
function hitLine(){const y=HITY;
 g.globalCompositeOperation='lighter';g.fillStyle=lg(0,y-60,0,y+60,[[0,'rgba(255,120,30,0)'],[0.5,'rgba(255,140,40,0.45)'],[1,'rgba(255,120,30,0)']]);g.fillRect(0,y-60,W,120);g.globalCompositeOperation='source-over';
 g.fillStyle='#2a0b06';g.fillRect(0,y-9,W,18);
 g.fillStyle=lg(0,y-7,0,y+7,[[0,'#ffcf6a'],[0.45,'#fff8e0'],[0.55,'#fff8e0'],[1,'#e8781f']]);g.fillRect(0,y-7,W,14);
 g.fillStyle='rgba(120,30,10,0.9)';g.fillRect(0,y+7,W,2);
 // receptors: bronze bell-mouth rings sitting on the line
 [-1,0,1].forEach(l=>{const x=laneX(l,y),rx=0.33*240,ry=rx*0.38;g.lineWidth=7;g.strokeStyle='#2a0b06';ell(x,y,rx+2,ry+2);g.stroke();
  g.strokeStyle=lg(0,y-ry,0,y+ry,[[0,'#ffe6a0'],[0.5,'#d8902e'],[1,'#7a3e10']]);g.lineWidth=5;ell(x,y,rx,ry);g.stroke();});}
function burst(l){const y=HITY,x=laneX(l,y);
 g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,200,[[0,'rgba(255,250,220,1)'],[0.15,'rgba(255,210,110,0.85)'],[0.45,'rgba(255,110,30,0.35)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-220,y-220,440,440);
 // star rays
 const rr=rng(3);for(let i=0;i<14;i++){const a=i/14*Math.PI*2+rr()*0.2,len=90+rr()*120,wd=6+rr()*8;g.fillStyle=lg(x,y,x+Math.cos(a)*len,y+Math.sin(a)*len*0.55,[[0,'rgba(255,245,210,0.95)'],[1,'rgba(255,120,30,0)']]);g.beginPath();g.moveTo(x+Math.cos(a+Math.PI/2)*wd,y+Math.sin(a+Math.PI/2)*wd*0.55);g.lineTo(x+Math.cos(a)*len,y+Math.sin(a)*len*0.55);g.lineTo(x-Math.cos(a+Math.PI/2)*wd,y-Math.sin(a+Math.PI/2)*wd*0.55);g.closePath();g.fill();}
 g.globalCompositeOperation='source-over';
 // expanding ring and embers
 g.strokeStyle='rgba(255,236,180,0.95)';g.lineWidth=5;ell(x,y,150,58);g.stroke();g.strokeStyle='rgba(255,140,40,0.6)';g.lineWidth=3;ell(x,y,176,68);g.stroke();
 for(let i=0;i<26;i++){const a=rr()*Math.PI*2,d=60+rr()*140;g.fillStyle=rr()<0.5?'#fff0b0':'#ff8a2a';const s=3+rr()*4;g.fillRect(x+Math.cos(a)*d,y+Math.sin(a)*d*0.55-10,s,s);}}
function judgement(l,txt){const x=laneX(l,HITY),y=HITY+84;g.save();g.translate(x,y);g.transform(1,0,-0.18,1,0,0);g.font='bold 46px "DejaVu Sans"';g.textAlign='center';g.textBaseline='middle';
 g.lineJoin='round';g.lineWidth=10;g.strokeStyle='#2a0706';g.strokeText(txt,0,0);g.fillStyle=lg(0,-22,0,22,[[0,'#fff8dc'],[0.5,'#ffd060'],[1,'#ff7a1f']]);g.fillText(txt,0,0);g.restore();}

// ---------- step buttons ----------
function foot(x,y,s,mirror){g.save();g.translate(x,y);g.scale(mirror?-s:s,s);g.beginPath();g.ellipse(0,-6,11,17,-0.12,0,Math.PI*2);g.fill();g.beginPath();g.ellipse(2,20,8,9,0,0,Math.PI*2);g.fill();
 [[-8,-27,3.4],[-2,-30,3.2],[4,-29,3],[9,-26,2.7],[12,-21,2.3]].forEach(([a,b,r])=>{g.beginPath();g.arc(a,b,r,0,Math.PI*2);g.fill();});g.restore();}
function buttons(){g.fillStyle='#07050d';g.fillRect(0,BTN_Y,W,H-BTN_Y);
 const bw=226,gap=11,x0=(W-3*bw-2*gap)/2;[0,1,2].forEach(i=>{const x=x0+i*(bw+gap),y=BTN_Y+10,h=H-BTN_Y-20,on=i==1;
  g.save();g.shadowColor=on?'rgba(255,90,30,0.9)':'rgba(0,0,0,0)';g.shadowBlur=on?30:0;
  const rr=18;g.beginPath();g.roundRect(x,y,bw,h,rr);g.fillStyle=on?lg(0,y,0,y+h,[[0,'#e0321f'],[1,'#6a0a10']]):lg(0,y,0,y+h,[[0,'#241a30'],[1,'#120d1c']]);g.fill();g.restore();
  g.lineWidth=3;g.strokeStyle=on?'#ffe0a0':'#b8782a';g.beginPath();g.roundRect(x+1.5,y+1.5,bw-3,h-3,rr);g.stroke();
  g.lineWidth=1.5;g.strokeStyle=on?'rgba(255,240,200,0.6)':'rgba(255,180,90,0.25)';g.beginPath();g.roundRect(x+9,y+9,bw-18,h-18,12);g.stroke();
  g.fillStyle=on?'#fff6de':'#f0e2c4';g.save();if(on){g.shadowColor='rgba(255,230,160,0.9)';g.shadowBlur=18;}
  const cx=x+bw/2,cy=y+h/2;if(i==1){foot(cx-22,cy,1.25,true);foot(cx+22,cy+6,1.25,false);}else foot(cx,cy,1.4,i==0);g.restore();});}

// ---------- HUD ----------
function hudText(t,x,y,size,fill,al='left',stroke=8){g.save();g.translate(x,y);g.transform(1,0,-0.14,1,0,0);g.font=`bold ${size}px "DejaVu Sans"`;g.textAlign=al;g.textBaseline='alphabetic';g.lineJoin='round';g.lineWidth=stroke;g.strokeStyle='#12060a';g.strokeText(t,0,0);g.fillStyle=fill;g.fillText(t,0,0);g.restore();}
function bellIcon(x,y,r,lit){g.save();if(lit){g.shadowColor='rgba(255,190,80,0.9)';g.shadowBlur=10;}g.fillStyle=lit?lg(0,y-r,0,y+r,[[0,'#fff1c0'],[0.5,'#ffbe45'],[1,'#c46a18']]):'#3a2a36';
 g.beginPath();g.moveTo(x-r*0.9,y+r*0.7);g.quadraticCurveTo(x-r*0.85,y-r,x,y-r);g.quadraticCurveTo(x+r*0.85,y-r,x+r*0.9,y+r*0.7);g.closePath();g.fill();g.restore();g.fillStyle=lit?'#5a2a08':'#1a1018';ell(x,y+r*0.8,r*0.25,r*0.2);g.fill();}
function hud(){ // dark band so the HUD always reads over the sky and fire
 g.fillStyle=rg(560,50,0,220,[[0,'rgba(4,3,12,0.7)'],[1,'rgba(4,3,12,0)']]);g.fillRect(340,0,380,150);
 // framed score plate
 g.save();g.beginPath();g.roundRect(12,12,300,86,14);g.fillStyle='rgba(20,10,30,0.8)';g.fill();g.lineWidth=2.5;g.strokeStyle='#c8862e';g.stroke();g.beginPath();g.roundRect(18,18,288,74,10);g.lineWidth=1;g.strokeStyle='rgba(255,200,120,0.3)';g.stroke();g.restore();
 hudText('92,761',30,66,50,lg(0,24,0,66,[[0,'#ffffff'],[0.55,'#ffe7a8'],[1,'#ffb13a']]));
 hudText('+12,675 on your best',30,90,19,'#ff9a3a','left',5);
 // progress bar with section ticks and a flame at the head
 const bx=24,by=112,bw=498,bh=14,p=0.68;g.fillStyle='#120a18';g.beginPath();g.roundRect(bx-3,by-3,bw+6,bh+6,9);g.fill();g.strokeStyle='#a8702a';g.lineWidth=2;g.stroke();
 g.fillStyle=lg(bx,0,bx+bw*p,0,[[0,'#8a0d14'],[0.7,'#e0321f'],[1,'#ffb13a']]);g.beginPath();g.roundRect(bx,by,bw*p,bh,7);g.fill();
 g.fillStyle='rgba(255,255,255,0.35)';g.fillRect(bx+4,by+2,bw*p-8,3);
 [0.22,0.44,0.66,0.84].forEach(t=>{g.fillStyle=t<p?'#fff0c8':'#6a5a70';g.fillRect(bx+bw*t-1.5,by-5,3,bh+10);});
 g.globalCompositeOperation='lighter';g.fillStyle=rg(bx+bw*p,by+bh/2,0,22,[[0,'rgba(255,240,200,1)'],[0.4,'rgba(255,150,40,0.6)'],[1,'rgba(0,0,0,0)']]);g.fillRect(bx+bw*p-24,by-18,48,50);g.globalCompositeOperation='source-over';
 // unison meter: x4 with six bells
 hudText('UNISON',520,46,24,'#fff3dc','right',6);hudText('×4',596,48,32,lg(0,20,0,48,[[0,'#fff'],[1,'#ffb13a']]),'right',7);
 for(let i=0;i<6;i++)bellIcon(418+i*34,72,12,i<5);
 // pause
 g.beginPath();g.arc(662,52,25,0,Math.PI*2);g.fillStyle='rgba(30,16,40,0.9)';g.fill();g.lineWidth=2.5;g.strokeStyle='#c8862e';g.stroke();g.fillStyle='#fff3dc';g.fillRect(652,40,7,24);g.fillRect(665,40,7,24);
 // section name tag
 g.font='bold 18px "DejaVu Sans"';const tw=g.measureText('CLIMAX').width+22;g.fillStyle='#c8181e';g.beginPath();g.moveTo(706-tw,106);g.lineTo(706,106);g.lineTo(706,132);g.lineTo(706-tw,132);g.lineTo(706-tw-8,119);g.closePath();g.fill();
 g.fillStyle='#fff3dc';g.textAlign='right';g.textBaseline='middle';g.fillText('CLIMAX',696,120);}

// ---------- compose ----------
function vignette(){g.fillStyle=rg(360,640,300,900,[[0,'rgba(0,0,0,0)'],[1,'rgba(0,0,0,0.55)']]);g.fillRect(0,0,W,H);}
function composeMock(){
sky();skyline();bonfire();ground();files();road();vignette();
standStill(1.2);bellBar(0.96,1);rope(0.78,-1,0);hold(1,0.3,0.7);step(-1,0.6);step(0,0.45);step(1,0.16);step(-1,0.3);
hitLine();burst(0);
judgement(0,'PERFECT');
buttons();hud();}
