// figures for A: strong, chunky silhouettes lit by the fire on the road side
function mamuthone(x,y,h,side,phase,seed){const s=h,f=side;const lift=Math.max(0,Math.sin(phase))*0.06*s;const X=u=>x+u*s*f,Y=v=>y-lift+v*s;
 const P=(pts)=>{g.beginPath();pts.forEach(([u,v],i)=>i?g.lineTo(X(u),Y(v)):g.moveTo(X(u),Y(v)));g.closePath();};
 g.fillStyle='rgba(0,0,0,0.6)';ell(x,y+2,0.3*s,0.065*s);g.fill();
 g.globalCompositeOperation='lighter';g.fillStyle=rg(x,y,0,0.55*s,[[0,'rgba(255,130,40,0.32)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-0.6*s,y-0.3*s,1.2*s,0.6*s);g.globalCompositeOperation='source-over';
 // legs: one planted, one lifted mid-jump; leather cambales
 const up=Math.sin(phase)>0;g.fillStyle='#0b080a';P([[-0.13,-0.32],[-0.03,-0.32],[-0.04,-0.05],[-0.12,-0.05]]);g.fill();
 P([[0.02,-0.32],[0.12,-0.32],up?[0.16,-0.14]:[0.11,-0.05],up?[0.08,-0.12]:[0.03,-0.05]]);g.fill();
 g.fillStyle='#4a2c16';P([[-0.15,-0.07],[-0.02,-0.07],[0.0,0],[-0.16,0]]);g.fill();P(up?[[0.06,-0.15],[0.18,-0.16],[0.22,-0.1],[0.08,-0.09]]:[[0.02,-0.07],[0.13,-0.07],[0.17,0],[0.01,0]]);g.fill();
 // black sheepskin: a big shaggy hunched mass with spiky tufts
 const r=rng(seed);const pts=[];const N=34;for(let i=0;i<N;i++){const a=i/N*Math.PI*2;let ru=0.29,rv=0.3;const cu=0.0,cv=-0.56;let u=cu+Math.cos(a)*ru*(1+0.05*Math.sin(a*3)),v=cv+Math.sin(a)*rv;
  if(v<-0.72)u+=0.05; // hunched shoulders lean forward
  const sp=(i%2)?0.05+r()*0.04:0;pts.push([u+Math.cos(a)*sp,v+Math.sin(a)*sp]);}
 P(pts);g.fillStyle='#0d0a0c';g.fill();
 g.save();P(pts);g.clip();
 g.globalCompositeOperation='lighter';g.fillStyle=lg(X(0.34),Y(-0.9),X(0.0),Y(-0.5),[[0,'rgba(255,150,60,0.85)'],[0.5,'rgba(200,70,30,0.25)'],[1,'rgba(0,0,0,0)']]);g.fillRect(x-s,y-1.2*s,2*s,1.2*s);g.globalCompositeOperation='source-over';
 for(let i=0;i<70;i++){const u=-0.28+r()*0.56,v=-0.84+r()*0.56;const tx=X(u),ty=Y(v);const warm=(u*1+0.3)/0.6;g.strokeStyle=`rgba(${60+warm*150},${40+warm*70},${40+warm*20},${0.35+r()*0.3})`;g.lineWidth=Math.max(1,s*0.014);g.beginPath();g.moveTo(tx,ty);g.quadraticCurveTo(tx+0.02*s*f,ty+0.03*s,tx+(r()-0.3)*0.04*s*f,ty+0.07*s);g.stroke();}
 g.restore();
 // sa carriga: a hump of bronze bells on the far side of the back
 const bl=[[-0.3,-0.74],[-0.36,-0.62],[-0.33,-0.5],[-0.26,-0.4],[-0.22,-0.66],[-0.25,-0.54],[-0.18,-0.46],[-0.16,-0.76]];bl.forEach(([u,v],i)=>{const bx=X(u),by=Y(v)+Math.sin(phase+i*0.9)*0.012*s,rb=0.065*s;
  g.fillStyle='#1a0c04';ell(bx,by+rb*0.1,rb*1.08,rb*1.02);g.fill();
  g.fillStyle=rg(bx+rb*0.35*f,by-rb*0.35,0,rb*1.2,[[0,'#fff0b8'],[0.3,'#e3a23c'],[0.75,'#8a4e16'],[1,'#2a1406']]);ell(bx,by,rb,rb*0.95);g.fill();
  g.fillStyle='#120804';ell(bx,by+rb*0.6,rb*0.55,rb*0.2);g.fill();});
 // motion arcs from the bells: they ring on the beat
 g.strokeStyle='rgba(255,220,150,0.55)';g.lineWidth=Math.max(1,0.015*s);for(const k of [0,1]){g.beginPath();g.arc(X(-0.42-k*0.06),Y(-0.58),0.08*s+k*0.05*s,f>0?Math.PI*0.7:-Math.PI*0.3,f>0?Math.PI*1.3:Math.PI*0.3);g.stroke();}
 // head: black kerchief hood, carved dark-wood mask thrust forward and lit by the fire
 g.fillStyle='#0a0709';P([[-0.05,-0.76],[-0.04,-1.02],[0.08,-1.12],[0.22,-1.08],[0.28,-0.9],[0.2,-0.72]]);g.fill();
 const MP=[[0.08,-1.02],[0.24,-1.03],[0.31,-0.94],[0.31,-0.82],[0.24,-0.72],[0.13,-0.74],[0.08,-0.86]];
 g.fillStyle=lg(X(0.06),0,X(0.32),0,[[0,'#1c0d06'],[0.5,'#6a3618'],[1,'#e08a48']]);P(MP);g.fill();
 g.strokeStyle='#080403';g.lineWidth=Math.max(1,0.012*s);P(MP);g.stroke();
 // deep eye holes under a heavy brow, long lit nose, grim mouth
 g.fillStyle='#070302';ell(X(0.15),Y(-0.92),0.03*s,0.02*s);g.fill();ell(X(0.25),Y(-0.92),0.026*s,0.019*s);g.fill();
 g.strokeStyle='#ffc58a';g.lineWidth=Math.max(1,0.016*s);g.beginPath();g.moveTo(X(0.1),Y(-0.96));g.quadraticCurveTo(X(0.2),Y(-0.99),X(0.3),Y(-0.955));g.stroke();
 g.fillStyle='#ffb877';P([[0.2,-0.93],[0.34,-0.82],[0.23,-0.82]]);g.fill();
 g.strokeStyle='#070302';g.lineWidth=Math.max(1,0.014*s);g.beginPath();g.moveTo(X(0.14),Y(-0.78));g.lineTo(X(0.26),Y(-0.77));g.stroke();}
function issohadore(x,y,h,side,seed){const s=h,f=side;const X=u=>x+u*s*f,Y=v=>y+v*s;const P=(pts)=>{g.beginPath();pts.forEach(([u,v],i)=>i?g.lineTo(X(u),Y(v)):g.moveTo(X(u),Y(v)));g.closePath();};
 g.fillStyle='rgba(0,0,0,0.6)';ell(x,y+2,0.26*s,0.06*s);g.fill();
 // legs: stepping toward the road; white trousers, black gaiters and shoes
 g.fillStyle='#ece0c6';P([[-0.12,-0.5],[-0.02,-0.5],[-0.05,-0.22],[-0.14,-0.22]]);g.fill();P([[0.0,-0.5],[0.1,-0.5],[0.17,-0.24],[0.08,-0.22]]);g.fill();
 g.fillStyle='#0e0a0c';P([[-0.14,-0.23],[-0.05,-0.23],[-0.05,-0.03],[-0.14,-0.03]]);g.fill();P([[0.08,-0.23],[0.17,-0.25],[0.2,-0.04],[0.11,-0.03]]);g.fill();
 P([[-0.16,-0.04],[-0.03,-0.04],[-0.02,0],[-0.17,0]]);g.fill();P([[0.1,-0.05],[0.22,-0.05],[0.25,0],[0.1,0]]);g.fill();
 // red jacket with a short flared skirt, lit on the road side
 g.fillStyle=lg(X(-0.18),0,X(0.2),0,[[0,'#5a070c'],[0.55,'#c8181e'],[1,'#ff6a2a']]);P([[-0.15,-0.84],[0.14,-0.86],[0.17,-0.56],[0.22,-0.47],[-0.2,-0.47],[-0.16,-0.56]]);g.fill();
 g.fillStyle='#f3e6c8';P([[0.0,-0.86],[0.06,-0.86],[0.05,-0.56],[0.01,-0.56]]);g.fill();
 g.strokeStyle='#e8b64a';g.lineWidth=Math.max(1.5,0.03*s);g.beginPath();g.moveTo(X(-0.12),Y(-0.84));g.lineTo(X(0.1),Y(-0.52));g.stroke();
 for(let i=0;i<5;i++){g.fillStyle='#ffd870';ell(X(-0.1+i*0.045),Y(-0.8+i*0.065),0.012*s,0.012*s);g.fill();}
 // throwing arm raised, rope loop sailing toward the road; coil at the hip
 g.strokeStyle='#b3141c';g.lineWidth=0.075*s;g.lineCap='round';g.beginPath();g.moveTo(X(0.1),Y(-0.82));g.lineTo(X(0.2),Y(-0.98));g.lineTo(X(0.18),Y(-1.12));g.stroke();
 g.fillStyle='#f6ecd6';ell(X(0.18),Y(-1.14),0.04*s,0.04*s);g.fill();
 g.strokeStyle='#e8cf98';g.lineWidth=Math.max(2,0.022*s);g.beginPath();g.moveTo(X(0.18),Y(-1.16));g.quadraticCurveTo(X(0.3),Y(-1.34),X(0.46),Y(-1.2));g.stroke();ell(X(0.5),Y(-1.1),0.08*s,0.1*s);g.stroke();
 ell(X(-0.2),Y(-0.5),0.07*s,0.09*s);g.stroke();ell(X(-0.18),Y(-0.52),0.06*s,0.08*s);g.stroke();
 // head: white visera crara, red kerchief under the chin, black berritta folded forward
 g.fillStyle='#c8181e';ell(X(0.03),Y(-0.94),0.1*s,0.11*s);g.fill();
 g.fillStyle='#f7eedb';ell(X(0.05),Y(-0.94),0.075*s,0.085*s);g.fill();
 g.fillStyle='#2a1a14';ell(X(0.08),Y(-0.95),0.014*s,0.007*s);g.fill();
 g.fillStyle='#0c0a0c';P([[-0.07,-0.99],[-0.05,-1.07],[0.06,-1.1],[0.16,-1.06],[0.17,-0.99]]);g.fill();P([[0.12,-1.06],[0.2,-1.03],[0.21,-0.95],[0.17,-0.95],[0.16,-1.0]]);g.fill();
 g.fillStyle='#ff8a2a';P([[0.2,-1.02],[0.215,-1.0],[0.215,-0.96],[0.2,-0.96]]);g.fill();}
