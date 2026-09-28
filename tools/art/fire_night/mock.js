// Direction A, "Fire Night": warm painterly night of Sant'Antonio in Mamoiada.
let cv=document.getElementById('c');let g=cv?cv.getContext('2d'):null;
const R=rng(7);
const C={night0:'#05041a',night1:'#120d3a',night2:'#231652',ink:'#07060f',ember:'#ff7a1f',gold:'#ffc84a',hot:'#fff3cf',crim:'#c8181e',crimD:'#5a0710',bone:'#f3e6c8',bronze:'#c98a2e'};
function lg(x0,y0,x1,y1,stops){const q=g.createLinearGradient(x0,y0,x1,y1);stops.forEach(([o,c])=>q.addColorStop(o,c));return q;}
function rg(x,y,r0,r1,stops,x1,y1){const q=g.createRadialGradient(x,y,r0,x1??x,y1??y,r1);stops.forEach(([o,c])=>q.addColorStop(o,c));return q;}
function ell(x,y,rx,ry){g.beginPath();g.ellipse(x,y,Math.max(0.1,rx),Math.max(0.1,ry),0,0,Math.PI*2);}
function roadPoly(z0,z1,u0,u1){const y0=yOfZ(z0),y1=yOfZ(z1);g.beginPath();g.moveTo(360+u0*wOfY(y0)/2,y0);g.lineTo(360+u1*wOfY(y0)/2,y0);g.lineTo(360+u1*wOfY(y1)/2,y1);g.lineTo(360+u0*wOfY(y1)/2,y1);g.closePath();}

// ---------- carved serif, small caps ----------
const SERIF='"FreeSerif","Liberation Serif",serif';
function scRuns(t,size){const runs=[];for(const ch of t){const lo=ch!==ch.toUpperCase();const sz=lo?Math.round(size*0.8):size;const c=ch.toUpperCase();if(runs.length&&runs[runs.length-1][1]===sz)runs[runs.length-1][0]+=c;else runs.push([c,sz]);}return runs;}
function scWidth(t,size,sp){let w=0;for(const [str,sz] of scRuns(t,size)){g.font=`bold ${sz}px ${SERIF}`;for(const ch of str)w+=g.measureText(ch).width+sp;}return w-sp;}
function scText(t,x,y,size,o={}){const sp=o.sp??size*0.05;const w=scWidth(t,size,sp);const x0=o.al=='c'?x-w/2:o.al=='r'?x-w:x;
 const pass=(dy,fn)=>{let px0=x0;for(const [str,sz] of scRuns(t,size)){g.font=`bold ${sz}px ${SERIF}`;for(const ch of str){fn(ch,px0,y+dy);px0+=g.measureText(ch).width+sp;}}};
 g.textBaseline='alphabetic';g.textAlign='left';g.lineJoin='round';
 if(o.halo){g.lineWidth=o.haloW??6;g.strokeStyle=o.halo;pass(0,(c,a,b)=>g.strokeText(c,a,b));}
 pass(Math.max(1,size*0.06),(c,a,b)=>{g.fillStyle=o.shadowCol??'rgba(10,3,4,0.9)';g.fillText(c,a,b);}); // carved: cut shadow below
 pass(0,(c,a,b)=>{g.fillStyle=o.fill??'#efe2c6';g.fillText(c,a,b);});
 if(o.hair){g.lineWidth=o.hairW??1;g.strokeStyle=o.hair;pass(0,(c,a,b)=>g.strokeText(c,a,b));}
 return w;}
// ---------- sky, smoke, skyline, fire ----------
function sky(){g.fillStyle=lg(0,0,0,H,[[0,C.night0],[0.12,C.night1],[0.2,'#2a1650'],[0.5,'#0b0820'],[1,'#050409']]);g.fillRect(0,0,W,H);
 // stars, only high up and away from the fire
 for(let i=0;i<120;i++){const x=R()*W,y=R()*170;if(Math.abs(x-360)<150&&y>60)continue;const a=0.25+R()*0.6;g.fillStyle=`rgba(230,225,255,${a})`;g.fillRect(x,y,R()<0.1?2:1,R()<0.1?2:1);}
 // big warm bloom of the bonfire over the whole upper field
 g.globalCompositeOperation='lighter';
 g.fillStyle=rg(360,170,0,560,[[0,'rgba(255,140,40,0.55)'],[0.25,'rgba(220,70,30,0.28)'],[0.55,'rgba(120,30,60,0.12)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,0,W,900);
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
function bonfire(){const bx=360,by=198;const r=rng(21);// the whole fire sits between the HUD (y 110) and the road's far end (y 195)
 g.globalCompositeOperation='lighter';g.fillStyle=rg(bx,by-40,0,240,[[0,'rgba(255,190,90,0.75)'],[0.35,'rgba(255,100,30,0.35)'],[1,'rgba(0,0,0,0)']]);g.fillRect(bx-300,by-260,600,340);g.globalCompositeOperation='source-over';
 const X0=196,Y0=62,FW=328,FH=140;const oc=document.createElement('canvas');oc.width=FW;oc.height=FH;const oc2=oc.getContext('2d');const im=oc2.createImageData(FW,FH);
 const n1=vnoise(3),n2=vnoise(9);const ramp=[[0.0,[90,8,20,0]],[0.16,[120,12,22,150]],[0.3,[200,34,24,230]],[0.48,[250,98,28,250]],[0.64,[255,160,48,255]],[0.8,[255,214,110,255]],[0.92,[255,246,210,255]],[1,[255,255,245,255]]];
 const col=t=>{t=Math.max(0,Math.min(1,t));for(let i=1;i<ramp.length;i++)if(t<=ramp[i][0]){const [a,ca]=ramp[i-1],[b,cb]=ramp[i];const k=(t-a)/(b-a);return ca.map((v,j)=>v+(cb[j]-v)*k);}return ramp[ramp.length-1][1];};
 for(let py=0;py<FH;py++)for(let px=0;px<FW;px++){const x=X0+px,y=Y0+py;const v=(by-y)/105,u=(x-bx)/135;if(v<-0.05||v>=0.999)continue;
  const t1=fbm(n1,x*0.03,y*0.016-3),t2=fbm(n2,x*0.07,y*0.035);const uu=u+(t1-0.5)*0.9*Math.max(0,v)+(t2-0.5)*0.25;
  const w=Math.max(0.02,1.05*(1-Math.max(0,v))**0.85);let I=(1-Math.abs(uu)/w)*1.35-Math.max(0,v)*0.55+0.1+(t2-0.5)*0.5+(t1-0.5)*0.35;if(v<0)I*=1+v*8;
  if(I<=0)continue;const c=col(I);const o=(py*FW+px)*4;im.data[o]=c[0];im.data[o+1]=c[1];im.data[o+2]=c[2];im.data[o+3]=c[3];}
 oc2.putImageData(im,0,0);g.drawImage(oc,X0,Y0);
 // the pyre: stacked logs, the base glowing
 for(let i=0;i<16;i++){const t=r(),lx=bx+(r()-0.5)*240*(1-t*0.4),ly=by-3-t*14,len=34+r()*40,a=(r()-0.5)*0.8;g.save();g.translate(lx,ly);g.rotate(a);g.fillStyle='#1a0c08';g.fillRect(-len/2,-3.5,len,7);g.fillStyle=`rgba(255,${130+r()*90},50,${0.55+r()*0.4})`;g.fillRect(-len/2,-4.5,len,2);g.restore();}
 g.globalCompositeOperation='lighter';g.fillStyle=rg(bx,by,0,140,[[0,'rgba(255,200,110,0.55)'],[1,'rgba(0,0,0,0)']]);g.fillRect(bx-150,by-60,300,80);g.globalCompositeOperation='source-over';
 for(let i=0;i<70;i++){const a=r(),x=bx+(r()-0.5)*300*(0.3+a),y=by-50-a*140;if(y<108&&Math.abs(x-360)>110)continue;g.fillStyle=r()<0.5?'rgba(255,230,140,0.95)':'rgba(255,130,40,0.9)';const s=r()<0.25?3:2;g.fillRect(x,y,s,s);}}
// ---------- ground beside the road and the road itself ----------
function ground(rings=true){ // the square beside the road: cobbles warmed by the fire, a crowd at the edge, beat rings
 g.fillStyle=lg(0,TOPY,0,HITY,[[0,'#2c1620'],[0.25,'#150c1d'],[1,'#07060c']]);g.fillRect(0,TOPY,W,HITY-TOPY);
 const r=rng(5);for(let n=0;n<520;n++){const z=r()*(ZMAX+0.35)-0.05,y=yOfZ(z),sc=wOfY(y)/720;const xx=r()*W;if(xx>edgeL(y)-10&&xx<edgeR(y)+10)continue;
  const warm=Math.max(0,1-Math.hypot(xx-360,(y-TOPY)*1.4)/620);const rw=(14+r()*18)*sc+3,rh=(4+r()*4)*sc+1.5;
  g.fillStyle=`rgba(${34+warm*120},${22+warm*50},${34+warm*14},${0.1+0.16*r()})`;g.beginPath();g.ellipse(xx,y,rw,rh,(r()-0.5)*0.5,0,7);g.fill();
  g.fillStyle=`rgba(255,${150+warm*60},${90+warm*30},${0.04+0.1*warm})`;g.beginPath();g.ellipse(xx,y-rh*0.4,rw*0.7,Math.max(0.8,rh*0.3),0,0,7);g.fill();}
 g.globalCompositeOperation='lighter';g.fillStyle=rg(360,TOPY,0,520,[[0,'rgba(255,120,40,0.34)'],[0.5,'rgba(160,50,40,0.10)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,TOPY,W,700);
 // beat rings rolling out from the fire across the square
 if(rings){g.save();g.beginPath();g.rect(0,TOPY+2,W,H);g.clip();
 [[330,120,0.5],[560,230,0.3],[800,360,0.16]].forEach(([rx,ry,a])=>{g.strokeStyle=`rgba(255,150,60,${a})`;g.lineWidth=5;ell(360,TOPY+8,rx,ry);g.stroke();g.strokeStyle=`rgba(255,220,150,${a*0.6})`;g.lineWidth=1.5;ell(360,TOPY+8,rx,ry);g.stroke();});
 g.restore();}g.globalCompositeOperation='source-over';
 // the crowd watching from the edge of the square, rim-lit
 const cr=rng(11);for(const side of [-1,1])for(let i=0;i<16;i++){const x=side<0?4+i*13+cr()*6:716-i*13-cr()*6;if(side<0&&x>edgeL(TOPY)-6)continue;if(side>0&&x<edgeR(TOPY)+6)continue;const hh=26+cr()*12,y=TOPY+6;
  g.fillStyle='#08060c';g.beginPath();g.ellipse(x,y-hh*0.25,9,hh*0.45,0,Math.PI,0);g.fill();ell(x,y-hh*0.72,5.5,6.5);g.fill();
  g.strokeStyle='rgba(255,150,70,0.7)';g.lineWidth=1.5;g.beginPath();g.arc(x,y-hh*0.72,6,side<0?-0.6:Math.PI-0.9,side<0?0.9:Math.PI+0.6);g.stroke();}}
function road(){ // basalt setts at low contrast, the fire's reflection, warm lane lines
 roadPoly(-0.12,ZMAX,-1,1);g.fillStyle=lg(0,TOPY,0,BTN_Y,[[0,'#2a1c22'],[0.25,'#1a1520'],[0.6,'#131018'],[1,'#0c0a12']]);g.fill();
 g.save();roadPoly(-0.12,ZMAX,-1,1);g.clip();
 // setts: small squared basalt blocks in staggered courses; each block within ±6% value
 {const rr=rng(77);let z=-0.12,row=0;while(z<ZMAX){const dz=0.034*(1+z*0.35);const z1=z+dz;const n=12;const off=row%2?0.5:0;
   for(let k=-1;k<n;k++){const u0=-1+(k+off)*2/n,u1=-1+(k+1+off)*2/n;if(u1<=-1||u0>=1)continue;const t=rr();
    roadPoly(z,z1,Math.max(-1,u0),Math.min(1,u1));const v=t<0.5?255:0;g.fillStyle=`rgba(${v},${v},${v},${0.018+0.028*rr()})`;g.fill();
    g.strokeStyle='rgba(0,0,0,0.30)';g.lineWidth=Math.max(0.8,1.6*wOfY(yOfZ(z))/720);g.stroke();}
   z=z1;row++;}}
 // fire light across the far third, and its long reflection down the middle, fading toward the player
 g.globalCompositeOperation='lighter';
 g.fillStyle=rg(360,TOPY,0,470,[[0,'rgba(255,140,50,0.42)'],[0.45,'rgba(255,90,40,0.14)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,TOPY,W,560);
 g.save();g.translate(360,TOPY);g.scale(0.28,1);g.fillStyle=rg(0,0,0,700,[[0,'rgba(255,170,80,0.34)'],[0.5,'rgba(255,110,40,0.10)'],[1,'rgba(0,0,0,0)']]);g.fillRect(-700,0,1400,760);g.restore();
 // the hit line pours warm light onto the stone nearest the player
 g.fillStyle=rg(360,HITY,0,420,[[0,'rgba(255,120,40,0.14)'],[1,'rgba(0,0,0,0)']]);g.fillRect(0,HITY-420,W,600);
 // ember specks drifting along the outer margins, outside the gem paths
 const er=rng(12);for(let i=0;i<46;i++){const z=er()*ZMAX,y=yOfZ(z);const sd=er()<0.5?-1:1;const u=sd*(0.9+er()*0.08);const x=360+u*wOfY(y)/2;const sz=1+er()*2*wOfY(y)/720;g.fillStyle=`rgba(255,${140+er()*90},60,${0.35+er()*0.5})`;g.fillRect(x,y,sz,sz);}
 g.globalCompositeOperation='source-over';
 g.restore();
 // lane dividers: warm 2 px at 35%
 for(const u of [-1/3,1/3]){g.strokeStyle='rgba(255,190,120,0.35)';g.lineWidth=2;g.beginPath();g.moveTo(360+u*wOfY(TOPY)/2,TOPY);g.lineTo(360+u*wOfY(HITY)/2,HITY);g.stroke();
  g.strokeStyle='rgba(255,190,120,0.18)';g.beginPath();g.moveTo(360+u*wOfY(HITY)/2,HITY);g.lineTo(360+u*wOfY(BTN_Y)/2,BTN_Y);g.stroke();}
 // road edges: glowing ember rails
 for(const s of [-1,1]){g.save();g.shadowColor='rgba(255,100,30,0.95)';g.shadowBlur=18;
  g.strokeStyle=lg(0,TOPY,0,HITY,[[0,'#ffcf7a'],[0.5,'#ff7a1f'],[1,'#ff5a1a']]);g.lineWidth=5;g.beginPath();g.moveTo(360+s*wOfY(TOPY)/2,TOPY);g.lineTo(360+s*wOfY(BTN_Y)/2,BTN_Y);g.stroke();
  g.shadowBlur=0;g.strokeStyle='rgba(255,245,220,0.9)';g.lineWidth=1.5;g.beginPath();g.moveTo(360+s*wOfY(TOPY)/2,TOPY);g.lineTo(360+s*wOfY(BTN_Y)/2,BTN_Y);g.stroke();g.restore();
  for(const z of [0.18,0.52,0.9,1.3]){const y=yOfZ(z),x=360+s*wOfY(y)/2,r=10*wOfY(y)/720+3;g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,r*4,[[0,'rgba(255,230,160,0.9)'],[0.3,'rgba(255,120,40,0.4)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-r*4,y-r*4,r*8,r*8);g.globalCompositeOperation='source-over';}}
 g.fillStyle='rgba(255,200,120,0.55)';g.fillRect(edgeL(TOPY),TOPY-1,wOfY(TOPY),2);}
// ---------- Mamuthones and Issohadores beside the road ----------
function tuftPath(pts,amp,seed){const r=rng(seed);g.beginPath();pts.forEach(([x,y],i)=>{if(i==0)g.moveTo(x,y);else{const [px,py]=pts[i-1];const mx=(px+x)/2,my=(py+y)/2;const nx=-(y-py),ny=x-px;const l=Math.hypot(nx,ny)||1;const k=amp*(0.6+r()*0.8);g.quadraticCurveTo(mx+nx/l*k,my+ny/l*k,x,y);}});g.closePath();}
function files(){SMALL=true;filesInner();SMALL=false;}
const FIG={warm:'#ff9a4a',hot:'#ffe0b0',cool:'#9a80ff',coolA:0.55,warmA:1,hotA:0.6,shadowTint:'rgba(110,92,170,1)',paint:0};
function filesInner(){// three Mamuthones per side, in unison (the Climax jump)
 for(const side of [-1,1]){const zs=[0.5,0.8,1.15],hs=[0.3,0.33,0.36];[2,1,0].forEach(i=>{const z=zs[i],y=yOfZ(z),w=wOfY(y);const h=hs[i]*w;
  const x=side<0?edgeL(y)-0.2*h-4:edgeR(y)+0.2*h+4;
  g.save();g.globalCompositeOperation='lighter';g.fillStyle=rg(x+side*-h*0.1,y,0,h*0.5,[[0,'rgba(255,120,40,0.3)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-h*0.6,y-h*0.3,h*1.2,h*0.6);g.restore();
  // ground shadow cast away from the fire, left on the ground while the dancer is in the air
  g.fillStyle='rgba(0,0,0,0.6)';g.save();g.translate(x+side*h*0.08,y+2);g.rotate(side*0.12);ell(0,0,h*0.3,h*0.055);g.fill();g.restore();
  figure(g,o=>mamuthone({view:'q',step:0.15,jump:true,dens:0.7}),x,y,h,Object.assign({flip:-side,light:-side,shadow:false,rimW:0.012,form:true,formA:0.25,dodgeA:0.2,key:0.3},FIG));
  const bx=x+side*h*0.33,by=y-h*0.66;g.strokeStyle='rgba(255,215,150,0.55)';g.lineWidth=Math.max(1,h*0.01);for(const k of [0,1]){g.beginPath();g.arc(bx,by,h*(0.1+k*0.07),side<0?Math.PI*0.72:-Math.PI*0.28,side<0?Math.PI*1.28:Math.PI*0.28);g.stroke();}});}}
function issohadores(){// the leaders, standing in the near wings at hit-line depth, twirling the soha overhead
 const keep=Object.assign({},IC);Object.assign(IC,{red0:'#5a0610',red1:'#a8101a',red2:'#e8261e',red3:'#ff9a5a',wh0:'#9a8a78',wh1:'#d4c6ac',wh2:'#ede3cf',wh3:'#fff4de',bk1:'#1a1418',bk2:'#3a2e34'});
 for(const side of [-1,1]){const y=1058,h=220,x=side<0?40:680;
  g.save();g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,110,[[0,'rgba(255,120,40,0.35)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-120,y-60,240,120);g.restore();
  g.fillStyle='rgba(0,0,0,0.6)';g.save();g.translate(x+side*18,y+3);g.rotate(side*0.15);ell(0,0,62,11);g.fill();g.restore();
  figure(g,o=>issohadore({view:'q',twirl:true}),x,y,h,Object.assign({flip:-side,light:-side,shadow:false,rimW:0.012,form:true,formA:0.35,dodgeA:0.25,key:0.2,brush:true,brushA:0.15,lostA:0.3},FIG,{shadowTint:'rgba(150,130,190,1)'}));}
 Object.assign(IC,keep);}
// ---------- notes ----------
function noteShadow(x,y,rx,ry){g.fillStyle='rgba(0,0,0,0.55)';ell(x,y+ry*0.9,rx*1.08,ry*0.9);g.fill();}
function gem(x,y,sc,o={}){const rx=0.3*240*sc*(o.off?0.78:1),ry=rx*0.38,t=rx*0.18;
 g.globalCompositeOperation='lighter';
 // soft reflection on the stone below and a low ember halo
 g.fillStyle=rg(x,y+t+ry*1.6,0,rx*0.9,[[0,'rgba(255,100,40,0.30)'],[1,'rgba(0,0,0,0)']]);g.save();g.translate(x,y+t+ry*1.6);g.scale(0.7,1.6);g.translate(-x,-(y+t+ry*1.6));g.fillRect(x-rx,y+t+ry*1.6-rx,2*rx,2*rx);g.restore();
 g.fillStyle=rg(x,y,0,rx*1.5,[[0,'rgba(255,110,40,0.30)'],[1,'rgba(0,0,0,0)']]);g.save();g.translate(x,y);g.scale(1,0.5);g.translate(-x,-y);g.fillRect(x-rx*1.6,y-rx*1.6,rx*3.2,rx*3.2);g.restore();
 g.globalCompositeOperation='source-over';
 noteShadow(x,y+t,rx,ry);
 // side of the stone: deep red, matte
 g.beginPath();g.moveTo(x-rx,y);g.lineTo(x-rx,y+t);g.ellipse(x,y+t,rx,ry,0,Math.PI,0,true);g.lineTo(x+rx,y);g.closePath();g.fillStyle=lg(x-rx,0,x+rx,0,[[0,'#2a0306'],[0.55,'#5e0a10'],[1,'#34050a']]);g.fill();
 // top face: matte deep red, lit a little from the far fire
 g.fillStyle=lg(0,y-ry,0,y+ry,[[0,'#a4161c'],[0.6,'#7a0e14'],[1,'#560a10']]);ell(x,y,rx,ry);g.fill();
 g.strokeStyle='rgba(30,0,4,0.55)';g.lineWidth=Math.max(1,2*sc);ell(x,y,rx*0.8,ry*0.76);g.stroke();
 // ember core
 g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,rx*0.72,[[0,'rgba(255,252,230,1)'],[0.2,'rgba(255,226,140,1)'],[0.5,'rgba(255,130,40,0.7)'],[1,'rgba(0,0,0,0)']]);g.save();g.translate(x,y);g.scale(1,ry/rx);g.translate(-x,-y);g.fillRect(x-rx*0.8,y-rx*0.8,rx*1.6,rx*1.6);g.fillRect(x-rx*0.8,y-rx*0.8,rx*1.6,rx*1.6);g.restore();g.globalCompositeOperation='source-over';
 g.strokeStyle='rgba(255,170,110,0.55)';g.lineWidth=Math.max(1,1.6*sc);g.beginPath();g.ellipse(x,y,rx,ry,0,Math.PI*1.1,Math.PI*1.9);g.stroke();
 if(o.off){g.strokeStyle='rgba(240,226,198,0.85)';g.lineWidth=Math.max(1,2*sc);g.setLineDash([4*sc+1,4*sc+1]);ell(x,y+t*0.5,rx*1.3,ry*1.35+t*0.5);g.stroke();g.setLineDash([]);}
 g.strokeStyle='#1a0306';g.lineWidth=Math.max(1,2*sc);ell(x,y+t*0.5,rx+1,ry+t*0.5+1);g.stroke();}
function step(l,z,o){const y=yOfZ(z);gem(laneX(l,y),y,wOfY(y)/720,o);}
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
 // words: RAISE | BELLS either side of the medallion, chevrons at the ends
 {const ym0=(y0+y1)/2,fs=Math.round((y0-y1)*0.95);const ww=wOfY(ym0);scText(dir>0?'Raise':'Lower',360-ww*0.2,ym0+fs*0.36,fs,{fill:'#2a1204',al:'c',sp:fs*0.12,shadowCol:'rgba(255,240,200,0.6)'});scText('Bells',360+ww*0.2,ym0+fs*0.36,fs,{fill:'#2a1204',al:'c',sp:fs*0.12,shadowCol:'rgba(255,240,200,0.6)'});}
 const n=6,ym=(y0+y1)/2,hh=(y0-y1)*0.32;for(let i=0;i<n;i++){const u=-0.86+i*(1.72/(n-1));if(Math.abs(u)<0.75)continue;const x=360+u*wOfY(ym)/2,wd=hh*1.6;
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
 const ym=(y0+y1)/2;const tw=scWidth('Stand still',15,1.5)+20;g.fillStyle='#10132e';g.fillRect(360-tw/2,ym-11,tw,22);g.strokeStyle='#dfe6ff';g.lineWidth=1.5;g.strokeRect(360-tw/2,ym-11,tw,22);scText('Stand still',360,ym+5,15,{fill:'#eef2ff',al:'c',sp:1.5});}

// ---------- hit line, receptors, hit burst ----------
function hitLine(){const y=HITY;
 g.globalCompositeOperation='lighter';g.fillStyle=lg(0,y-60,0,y+60,[[0,'rgba(255,120,30,0)'],[0.5,'rgba(255,140,40,0.45)'],[1,'rgba(255,120,30,0)']]);g.fillRect(0,y-60,W,120);g.globalCompositeOperation='source-over';
 g.fillStyle='#2a0b06';g.fillRect(0,y-9,W,18);
 g.fillStyle=lg(0,y-7,0,y+7,[[0,'#ffcf6a'],[0.45,'#fff8e0'],[0.55,'#fff8e0'],[1,'#e8781f']]);g.fillRect(0,y-7,W,14);
 g.fillStyle='rgba(120,30,10,0.9)';g.fillRect(0,y+7,W,2);
 // receptors: bronze bell-mouth rings sitting on the line
 [-1,0,1].forEach(l=>{const x=laneX(l,y),rx=0.33*240,ry=rx*0.38;g.lineWidth=7;g.strokeStyle='#2a0b06';ell(x,y,rx+2,ry+2);g.stroke();
  g.strokeStyle=lg(0,y-ry,0,y+ry,[[0,'#ffe6a0'],[0.5,'#d8902e'],[1,'#7a3e10']]);g.lineWidth=5;ell(x,y,rx,ry);g.stroke();});}
function burst(l){const y=HITY,x=laneX(l,y);const rx=0.33*240,ry=rx*0.38;const rr=rng(3);
 g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,170,[[0,'rgba(255,230,170,0.7)'],[0.3,'rgba(255,150,60,0.35)'],[1,'rgba(0,0,0,0)']]);g.save();g.translate(x,y);g.scale(1,0.55);g.translate(-x,-y);g.fillRect(x-180,y-180,360,360);g.restore();
 // ring pulse travelling outward from the receptor (never over it)
 [[1.32,0.95,5],[1.7,0.5,3],[2.15,0.22,2]].forEach(([k,a,w])=>{g.strokeStyle=`rgba(255,222,150,${a})`;g.lineWidth=w;ell(x,y,rx*k,ry*k);g.stroke();});
 // embers rising
 for(let i=0;i<13;i++){const a=-Math.PI*(0.1+rr()*0.8),d=rx*(1.1+rr()*0.9);const ex=x+Math.cos(a)*d,ey=y+Math.sin(a)*d*0.8-rr()*30;const s=2+rr()*3;g.fillStyle=rr()<0.5?'rgba(255,236,170,0.95)':'rgba(255,140,50,0.9)';g.fillRect(ex,ey,s,s*1.6);}
 g.globalCompositeOperation='source-over';}
function judgement(l,txt){const x=laneX(l,HITY),y=HITY+106;// below the receptor ring, never over it
 const w=scText(txt,x,y,38,{fill:lg(0,y-30,0,y,[[0,'#fff4dc'],[1,'#e8d2a4']]),hair:'rgba(232,178,80,0.95)',hairW:1.2,al:'c',sp:4,halo:'rgba(20,6,6,0.55)',haloW:7});
 g.strokeStyle='rgba(232,178,80,0.8)';g.lineWidth=1.2;for(const sd of [-1,1]){const x0=x+sd*(w/2+14),x1=x+sd*(w/2+60);g.beginPath();g.moveTo(x0,y-12);g.lineTo(x1,y-12);g.stroke();g.fillStyle='#e8b250';g.save();g.translate(x0+sd*4,y-12);g.rotate(Math.PI/4);g.fillRect(-3,-3,6,6);g.restore();}}
// ---------- step buttons ----------
function foot(x,y,s,mirror){g.save();g.translate(x,y);g.scale(mirror?-s:s,s);// a sole: broad ball, narrow waist, round heel; no toes
 g.beginPath();g.moveTo(-1,-33);g.bezierCurveTo(9,-34,14,-22,12,-10);g.bezierCurveTo(11,0,6,5,7,14);g.bezierCurveTo(8,27,-3,31,-7,26);g.bezierCurveTo(-11,21,-9,11,-9,3);g.bezierCurveTo(-9,-6,-14,-14,-13,-23);g.bezierCurveTo(-12,-31,-7,-33,-1,-33);g.closePath();g.fill();
 g.globalCompositeOperation='source-atop';g.strokeStyle='rgba(0,0,0,0.18)';g.lineWidth=1.5;for(let k=0;k<5;k++){g.beginPath();g.moveTo(-12,-24+k*5);g.lineTo(12,-26+k*5);g.stroke();}g.restore();}
function lozengeBand(x,y,w,h,col){// Sardinian woven motif: a row of stepped lozenges
 const n=Math.round(w/(h*1.6));const step=w/n;g.fillStyle=col;for(let i=0;i<n;i++){const cx0=x+step*(i+0.5),cy0=y+h/2;g.beginPath();g.moveTo(cx0,y);g.lineTo(cx0+h*0.55,cy0);g.lineTo(cx0,y+h);g.lineTo(cx0-h*0.55,cy0);g.closePath();g.fill();
  g.fillRect(cx0+step/2-1,cy0-1,2,2);}}
function buttons(){g.fillStyle=lg(0,BTN_Y,0,H,[[0,'#0b0712'],[1,'#050309']]);g.fillRect(0,BTN_Y,W,H-BTN_Y);
 // the stage edge: a thin ember line and the hit-line glow spilling over the top of the panel
 g.fillStyle=lg(0,BTN_Y-2,0,BTN_Y+40,[[0,'rgba(255,120,40,0.35)'],[1,'rgba(255,120,40,0)']]);g.fillRect(0,BTN_Y,W,40);
 const bw=226,gap=11,x0=(W-3*bw-2*gap)/2;[0,1,2].forEach(i=>{const x=x0+i*(bw+gap),y=BTN_Y+10,h=H-BTN_Y-20,on=i==1;const rr=18;
  g.save();if(on){g.shadowColor='rgba(255,90,30,0.95)';g.shadowBlur=34;}else{g.shadowColor='rgba(0,0,0,0.8)';g.shadowBlur=12;g.shadowOffsetY=6;}
  g.beginPath();g.roundRect(x,y,bw,h,rr);g.fillStyle=on?lg(0,y,0,y+h,[[0,'#f0402a'],[0.55,'#a8141a'],[1,'#560710']]):lg(0,y,0,y+h,[[0,'#2c1f36'],[0.5,'#1a1224'],[1,'#0f0a16']]);g.fill();g.restore();
  g.save();g.beginPath();g.roundRect(x,y,bw,h,rr);g.clip();
  // lacquered surface: soft top sheen and a faint wood/leather grain
  g.fillStyle=lg(0,y,0,y+h*0.45,[[0,on?'rgba(255,220,170,0.35)':'rgba(255,200,160,0.10)'],[1,'rgba(255,255,255,0)']]);g.fillRect(x,y,bw,h*0.45);
  const gr=rng(40+i);for(let k=0;k<26;k++){const yy=y+gr()*h;g.strokeStyle=on?'rgba(60,0,0,0.12)':'rgba(255,190,140,0.035)';g.lineWidth=1+gr()*2;g.beginPath();g.moveTo(x,yy);g.bezierCurveTo(x+bw*0.3,yy+(gr()-0.5)*8,x+bw*0.7,yy+(gr()-0.5)*8,x+bw,yy+(gr()-0.5)*6);g.stroke();}
  // woven lozenge band along the top (the Issohadore sash motif)
  g.fillStyle=on?'rgba(80,0,8,0.45)':'rgba(0,0,0,0.35)';g.fillRect(x,y+16,bw,16);
  lozengeBand(x+14,y+18,bw-28,12,on?'rgba(255,214,140,0.95)':'rgba(214,150,70,0.55)');
  // warm under-light rising from the hit line
  g.fillStyle=lg(0,y,0,y+60,[[0,on?'rgba(255,230,160,0.35)':'rgba(255,140,60,0.16)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x,y,bw,60);
  g.restore();
  // bronze bevel frame with studs
  g.lineWidth=4;g.strokeStyle=lg(x,y,x,y+h,on?[[0,'#fff0c0'],[0.5,'#ffb04a'],[1,'#b8561a']]:[[0,'#e0a050'],[0.5,'#8a5220'],[1,'#4a2810']]);g.beginPath();g.roundRect(x+2,y+2,bw-4,h-4,rr-1);g.stroke();
  g.lineWidth=1.2;g.strokeStyle=on?'rgba(255,245,210,0.7)':'rgba(255,200,130,0.28)';g.beginPath();g.roundRect(x+9,y+9,bw-18,h-18,12);g.stroke();
  for(const [sx,sy] of [[x+16,y+h-16],[x+bw-16,y+h-16]]){g.fillStyle=rg(sx-1,sy-1,0,5,[[0,on?'#fff4d0':'#f0c070'],[0.6,on?'#e08030':'#8a5220'],[1,'#2a1406']]);ell(sx,sy,4.5,4.5);g.fill();}
  // footprint icons: engraved bone, lit on the pressed plate
  const cx0=x+bw/2,cy0=y+h/2+14;
  const feet=(dx,dy)=>{if(i==1){foot(cx0-22+dx,cy0+dy,1.25,true);foot(cx0+22+dx,cy0+6+dy,1.25,false);}else foot(cx0+dx,cy0+dy,1.4,i==0);};
  g.fillStyle='rgba(0,0,0,0.55)';feet(0,3);
  g.save();if(on){g.shadowColor='rgba(255,230,160,0.95)';g.shadowBlur=20;}g.fillStyle=on?'#fff6de':lg(0,cy0-40,0,cy0+40,[[0,'#f6e6c6'],[1,'#b89868']]);feet(0,0);g.restore();});
 // pressed plate: sparks thrown up from the stamp
 const r2=rng(9);g.globalCompositeOperation='lighter';for(let k=0;k<22;k++){const px0=360+(r2()-0.5)*200,py0=BTN_Y+6-r2()*40;g.fillStyle=`rgba(255,${150+r2()*90},70,${0.4+r2()*0.5})`;g.fillRect(px0,py0,2,2+r2()*3);}g.globalCompositeOperation='source-over';}

// ---------- HUD ----------
function hudText(t,x,y,size,fill,al='left',stroke=8){g.save();g.translate(x,y);g.transform(1,0,-0.14,1,0,0);g.font=`bold ${size}px "DejaVu Sans"`;g.textAlign=al;g.textBaseline='alphabetic';g.lineJoin='round';g.lineWidth=stroke;g.strokeStyle='#12060a';g.strokeText(t,0,0);g.fillStyle=fill;g.fillText(t,0,0);g.restore();}
function bellIcon(x,y,r,lit){g.save();if(lit){g.shadowColor='rgba(255,190,80,0.9)';g.shadowBlur=10;}g.fillStyle=lit?lg(0,y-r,0,y+r,[[0,'#fff1c0'],[0.5,'#ffbe45'],[1,'#c46a18']]):'#3a2a36';
 g.beginPath();g.moveTo(x-r*0.9,y+r*0.7);g.quadraticCurveTo(x-r*0.85,y-r,x,y-r);g.quadraticCurveTo(x+r*0.85,y-r,x+r*0.9,y+r*0.7);g.closePath();g.fill();g.restore();g.fillStyle=lit?'#5a2a08':'#1a1018';ell(x,y+r*0.8,r*0.25,r*0.2);g.fill();}
function hud(){ // compact: everything within the top 110 px; the centre is left open for the fire
 g.fillStyle=rg(110,52,0,190,[[0,'rgba(4,3,12,0.72)'],[1,'rgba(4,3,12,0)']]);g.fillRect(0,0,320,130);
 g.fillStyle=rg(610,52,0,190,[[0,'rgba(4,3,12,0.72)'],[1,'rgba(4,3,12,0)']]);g.fillRect(400,0,320,130);
 // progress: a thin line across the very top, with phrase ticks
 const p=0.68;g.fillStyle='rgba(30,18,34,0.95)';g.fillRect(0,0,W,4);g.fillStyle=lg(0,0,W*p,0,[[0,'#7a2a0c'],[1,'#ffc86a']]);g.fillRect(0,0,W*p,4);
 [0.22,0.44,0.66,0.84].forEach(t=>{g.fillStyle=t<p?'#fff0c8':'#6a5a70';g.fillRect(W*t-1,0,2,8);});
 g.globalCompositeOperation='lighter';g.fillStyle=rg(W*p,2,0,16,[[0,'rgba(255,230,170,1)'],[1,'rgba(0,0,0,0)']]);g.fillRect(W*p-18,0,36,20);g.globalCompositeOperation='source-over';
 // score in carved serif
 scText('92,761',22,58,38,{fill:lg(0,28,0,58,[[0,'#fff6e2'],[0.6,'#f0dcb2'],[1,'#d4a45a']]),hair:'rgba(255,214,140,0.5)',sp:2});
 scText('+12,675 on your best',23,82,14,{fill:'#d9a24a',sp:1});
 // unison and its six bells
 scText('Unison',590,40,17,{fill:'#efe2c6',al:'r',sp:1.5});scText('×4',634,42,25,{fill:lg(0,20,0,42,[[0,'#fff6e0'],[1,'#e0a040']]),al:'r'});
 for(let i=0;i<6;i++)bellIcon(478+i*28,66,10,i<5);
 // pause
 g.beginPath();g.arc(680,40,21,0,Math.PI*2);g.fillStyle='rgba(30,16,40,0.9)';g.fill();g.lineWidth=2;g.strokeStyle='#c8862e';g.stroke();g.fillStyle='#fff3dc';g.fillRect(672,30,6,20);g.fillRect(683,30,6,20);
 // section: gold small caps between hairlines
 const tw=scWidth('Climax',15,2.5);const tx=W-22;scText('Climax',tx,100,15,{fill:'#e8c070',al:'r',sp:2.5});
 g.fillStyle='rgba(232,192,112,0.75)';g.fillRect(tx-tw-44,95,32,1);g.save();g.translate(tx-tw-8,95.5);g.rotate(Math.PI/4);g.fillRect(-2.5,-2.5,5,5);g.restore();}
// ---------- compose ----------
function vignette(){g.fillStyle=rg(360,640,300,900,[[0,'rgba(0,0,0,0)'],[1,'rgba(0,0,0,0.55)']]);g.fillRect(0,0,W,H);}
function composeMock(){
sky();skyline();bonfire();ground();files();road();vignette();
standStill(1.28);bellBar(1.04,1);rope(0.82,-1,0);step(0,0.63,{off:true});hold(1,0.3,0.7);step(-1,0.6);step(0,0.45);step(1,0.16);step(-1,0.3);
burst(0);hitLine();issohadores();
judgement(0,'Perfect');
buttons();hud();}
