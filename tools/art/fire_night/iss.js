// Issohadore, drawn in unit space (see lib2.js). view: 'front' | 'q' (3/4 facing +x, throwing the soha)
const IC={kr0:'#2a0808',kr1:'#5a1216',kr2:'#8a2020',kr3:'#c04a30',red0:'#3a0306',red1:'#7e0a10',red2:'#c8161c',red3:'#ff5a2e',wh0:'#8a7c6c',wh1:'#c8baa0',wh2:'#ede3cf',wh3:'#fff3dc',
 bk0:'#050405',bk1:'#141116',bk2:'#2e2830',och0:'#4a2a08',och1:'#9a6210',och2:'#e0a030',rope:'#cdb57a',ropeD:'#7a6436'};

function issHead(hx,hy,s,q){const Q=(x,y)=>[hx+x*s,hy+y*s];const QP=pts=>pts.map(([x,y,f])=>[hx+x*s,hy+y*s,f]);
 const lk=x=>Math.max(0,Math.min(1,0.5+(L>0?x:-x)*1.1));
 // berritta tail folded back and hanging behind the head
 // coloured kerchief framing the face, tied under the chin
 const K=q?[[-0.42,-0.2],[-0.36,-0.42],[0.1,-0.5],[0.36,-0.36],[0.42,0.0],[0.38,0.3],[0.2,0.5],[0.0,0.52],[-0.28,0.36],[-0.42,0.1]]
          :[[-0.44,-0.2],[-0.38,-0.42],[0.38,-0.42],[0.44,-0.2],[0.44,0.1],[0.34,0.36],[0.12,0.52],[-0.12,0.52],[-0.34,0.36],[-0.44,0.1]];
 const KP=QP(K);fillP(KP,sh(hx-0.44*s,hx+0.44*s,[IC.kr0,IC.kr1,IC.kr2,IC.kr3]));
 cx.save();path(KP);cx.clip();{const r=rngS(3);for(let yy=-0.5;yy<0.6;yy+=0.09)for(let xx=-0.46+((Math.round(yy/0.09))%2)*0.045;xx<0.5;xx+=0.09){const [x,y]=Q(xx+(r()-0.5)*0.01,yy);
   for(let p=0;p<4;p++){const a=p/4*Math.PI*2+0.4;ellU(x+Math.cos(a)*0.013*s,y+Math.sin(a)*0.013*s,0.009*s,0.009*s);cx.fillStyle='rgba(240,214,160,0.75)';cx.fill();}ellU(x,y,0.006*s,0.006*s);cx.fillStyle='#e0a030';cx.fill();}
  // folds radiating to the knot
  for(const [a,b] of [[[-0.42,-0.1],[-0.2,0.4]],[[0.42,-0.1],[0.2,0.42]],[[-0.36,0.2],[-0.08,0.5]],[[0.36,0.22],[0.1,0.5]]]){strokeP([Q(...a),Q((a[0]+b[0])/2-0.05,(a[1]+b[1])/2),Q(...b)],'rgba(20,0,0,0.55)',0.035*s);}}
 cx.restore();
 // white visera crara: gentle, smooth
 const M=q?[[-0.2,-0.3],[0.1,-0.34],[0.28,-0.26],[0.33,-0.1],[0.36,0.02],[0.4,0.1],[0.35,0.14],[0.34,0.2],[0.33,0.26],[0.28,0.36],[0.12,0.42],[-0.08,0.38],[-0.2,0.24],[-0.25,0.0]]
          :[[0,-0.34],[0.24,-0.3],[0.31,-0.1],[0.3,0.12],[0.22,0.32],[0.1,0.41],[0,0.43],[-0.1,0.41],[-0.22,0.32],[-0.3,0.12],[-0.31,-0.1],[-0.24,-0.3]];
 const MP=QP(M);fillP(MP,sh(hx+(q?-0.25:-0.31)*s,hx+(q?0.4:0.31)*s,['#8a8090','#d8cfc4','#fff4e2','#fffaf0']));
 cx.save();path(MP);cx.clip();
 const soft=(x,y,rr,col)=>{const [X,Y]=Q(x,y);cx.fillStyle=rgr(X,Y,rr*s,[[0,col],[1,'rgba(0,0,0,0)']]);cx.fillRect(X-rr*s,Y-rr*s,2*rr*s,2*rr*s);};
 if(!q){
  for(const sx of [-1,1]){strokeP([Q(sx*0.06,-0.13),Q(sx*0.15,-0.16),Q(sx*0.24,-0.12)],'rgba(90,70,70,0.6)',0.02*s);
   fillP(QP([[sx*0.08,-0.05],[sx*0.15,-0.075],[sx*0.22,-0.05],[sx*0.15,-0.03]]),'#1a1214');}
  fillP(QP([[-0.03,-0.08],[0.03,-0.08],[0.06,0.12],[0,0.15],[-0.06,0.12]]),sh(hx-0.06*s,hx+0.06*s,['rgba(120,110,120,0.5)','rgba(255,255,255,0)','rgba(255,255,255,0.6)']));
  strokeP([Q(-0.07,0.27),Q(0,0.268),Q(0.07,0.27)],'rgba(70,50,55,0.7)',0.016*s);}
 else{
  strokeP([Q(-0.14,-0.14),Q(-0.04,-0.17),Q(0.06,-0.13)],'rgba(90,70,70,0.6)',0.02*s);strokeP([Q(0.18,-0.14),Q(0.25,-0.16),Q(0.3,-0.13)],'rgba(90,70,70,0.6)',0.018*s);
  fillP(QP([[-0.12,-0.06],[-0.03,-0.085],[0.05,-0.06],[-0.03,-0.035]]),'#1a1214');fillP(QP([[0.21,-0.065],[0.26,-0.08],[0.3,-0.06],[0.26,-0.045]]),'#1a1214');
  fillP(QP([[0.24,-0.06],[0.37,0.1],[0.33,0.13],[0.25,0.11]]),'rgba(120,110,125,0.18)');strokeP([Q(0.25,-0.06),Q(0.36,0.09),Q(0.32,0.13)],'rgba(90,80,95,0.4)',0.012*s);
  strokeP([Q(0.18,0.275),Q(0.25,0.272),Q(0.31,0.27)],'rgba(70,50,55,0.7)',0.016*s);}
 cx.restore();path(MP);cx.strokeStyle='rgba(60,50,60,0.55)';cx.lineWidth=0.012*s;cx.stroke();
 // berritta crown on top of the head
 const B=q?[[-0.42,-0.34],[-0.36,-0.66],[-0.1,-0.8],[0.2,-0.76],[0.4,-0.56],[0.42,-0.36],[0.1,-0.42]]:[[-0.45,-0.34],[-0.38,-0.66],[-0.1,-0.8],[0.2,-0.78],[0.4,-0.62],[0.45,-0.34],[0,-0.42]];
 fillP(QP(B),sh(hx-0.44*s,hx+0.44*s,['#141016','#1c181e','#28222a','#3a3038']));
 strokeP(QP(q?[[-0.3,-0.58],[0.0,-0.66],[0.3,-0.56]]:[[-0.32,-0.6],[0,-0.68],[0.32,-0.6]]),`rgba(255,170,100,${0.2+0.4*lk(0.3)})`,0.02*s);
 // the long end of the berritta: the cap's own black cloth, folded forward and lying flat over the crown
 const FC=q?[[-0.36,-0.62],[-0.2,-0.8],[0.02,-0.87],[0.2,-0.84],[0.33,-0.7],[0.34,-0.54]]:[[-0.34,-0.64],[-0.18,-0.82],[0.04,-0.88],[0.22,-0.84],[0.34,-0.7],[0.35,-0.54]];
 const F=(()=>{const a=[],b=[];FC.forEach((p,i)=>{const q2=FC[Math.min(FC.length-1,i+1)],q0=FC[Math.max(0,i-1)];let nx=-(q2[1]-q0[1]),ny=q2[0]-q0[0];const d=Math.hypot(nx,ny)||1;nx/=d;ny/=d;const hw=0.085-0.035*i/(FC.length-1);a.push([p[0]+nx*hw,p[1]+ny*hw]);b.unshift([p[0]-nx*hw,p[1]-ny*hw]);});return a.concat(b);})();
 fillP(QP(F).map(([x,y])=>[x+0.015*s,y+0.045*s]),'rgba(0,0,0,0.75)'); // cast shadow of the flap on the crown
 fillP(QP(F),sh(hx-0.4*s,hx+0.4*s,['#040304','#0a080a','#121014','#1c181e']));
 path(QP(F));cx.strokeStyle='rgba(0,0,0,0.9)';cx.lineWidth=0.018*s;cx.stroke();
 path(QP(F));cx.strokeStyle='rgba(140,130,165,0.35)';cx.lineWidth=0.008*s;cx.stroke();
 strokeP(QP([[FC[5][0]-0.06,FC[5][1]+0.03],[FC[5][0]+0.05,FC[5][1]+0.02]]),'rgba(120,110,140,0.45)',0.012*s);
 // soft wool folds: dark creases across the flap, a cool sheen along its top, the tip tucked
 cx.save();path(QP(F));cx.clip();
 for(const t of [0.3,0.55,0.78]){const i=Math.floor(t*(FC.length-1)),f=t*(FC.length-1)-i;const p0=FC[i],p1=FC[Math.min(FC.length-1,i+1)];const c=[p0[0]+(p1[0]-p0[0])*f,p0[1]+(p1[1]-p0[1])*f];
  strokeP(QP([[c[0]-0.05,c[1]-0.07],[c[0]+0.01,c[1]],[c[0]-0.03,c[1]+0.08]]),'rgba(0,0,0,0.6)',0.022*s);}
 strokeP(QP(FC.slice(1,5).map(([x,y])=>[x,y-0.045])),'rgba(150,140,175,0.22)',0.03*s);
 strokeP(QP(FC.slice(2,5).map(([x,y])=>[x+0.01,y-0.06])),`rgba(255,190,140,${0.06+0.12*lk(0.4)})`,0.012*s);
 cx.restore();
 // knot under the chin
 const [kx,ky]=Q(q?0.14:0,0.54);ellU(kx,ky,0.08*s,0.06*s);cx.fillStyle=sh(kx-0.08*s,kx+0.08*s,[IC.kr0,IC.kr2,IC.kr3]);cx.fill();ellU(kx,ky,0.08*s,0.06*s);cx.strokeStyle='rgba(20,0,0,0.6)';cx.lineWidth=0.012*s;cx.stroke();
 fillP([[kx-0.03*s,ky+0.03*s],[kx-0.12*s,ky+0.26*s],[kx-0.02*s,ky+0.22*s]],IC.kr1);fillP([[kx+0.02*s,ky+0.03*s],[kx+0.09*s,ky+0.28*s],[kx+0.15*s,ky+0.22*s]],IC.kr2);}

function issLeg(hip,knee,ank,foot,o={}){// white wide trousers into black wool gaiters, leather boots. points [x,y]
 const [hx,hy]=hip,[kx,ky]=knee,[ax,ay]=ank;const tw=o.tw??0.062;
 const mx=hx+(kx-hx)*0.45,my=hy+(ky-hy)*0.45;
 const TR=[[hx-tw*0.95,hy],[hx+tw*0.95,hy],[mx+tw*1.12,my],[kx+tw*1.05,ky-0.035],[kx+tw*1.3,ky-0.012],[kx+tw*1.0,ky+0.03],[kx+tw*0.3,ky+0.042],[kx-tw*0.5,ky+0.04],[kx-tw*1.05,ky+0.03],[kx-tw*1.34,ky-0.012],[kx-tw*1.0,ky-0.035],[mx-tw*1.02,my]];
 fillP(TR,sh(Math.min(hx,kx)-tw,Math.max(hx,kx)+tw,[IC.wh0,IC.wh1,IC.wh2,IC.wh3]));
 cx.save();path(TR);cx.clip();cx.strokeStyle='rgba(70,60,90,0.45)';cx.lineWidth=px(1.6);
 for(let i=0;i<4;i++){const t=0.2+i*0.2;cx.beginPath();cx.moveTo(hx+(kx-hx)*t-tw*0.6,hy+(ky-hy)*t);cx.quadraticCurveTo(hx+(kx-hx)*(t+0.1),hy+(ky-hy)*(t+0.05)+0.01,hx+(kx-hx)*(t+0.05)+tw*0.7,hy+(ky-hy)*(t+0.12));cx.stroke();}
 // cast shadow under the jacket/shawl, lit crease down the fire side, knee blouse shadow
 cx.fillStyle=lgr(0,hy,0,hy+0.06,[[0,'rgba(40,30,60,0.6)'],[1,'rgba(40,30,60,0)']]);cx.fillRect(hx-0.2,hy,0.4,0.06);
 const sg=L>0?1:-1;cx.strokeStyle='rgba(255,236,200,0.7)';cx.lineWidth=px(2);cx.beginPath();cx.moveTo(hx+sg*tw*0.6,hy+0.02);cx.quadraticCurveTo(mx+sg*tw*0.85,my,kx+sg*tw*1.0,ky-0.02);cx.stroke();
 cx.fillStyle='rgba(60,50,90,0.35)';cx.beginPath();cx.ellipse(kx,ky+0.02,tw*1.2,0.018,0,0,7);cx.fill();
 cx.restore();
 const gw=0.028;const cxl=kx+(ax-kx)*0.3,cyl=ky+(ay-ky)*0.3;const G=[[kx-gw*1.05,ky+0.01],[kx+gw*1.05,ky+0.01],[cxl+gw*1.3,cyl],[ax+gw*0.8,ay],[ax-gw*0.8,ay],[cxl-gw*1.25,cyl]];
 fillP(G,sh(Math.min(kx,ax)-gw,Math.max(kx,ax)+gw,[IC.bk0,IC.bk0,IC.bk1,'#3a3040']));
 cx.strokeStyle='rgba(90,80,100,0.5)';cx.lineWidth=px(1.2);for(let t=0.25;t<1;t+=0.25){cx.beginPath();cx.moveTo(kx+(ax-kx)*t-gw,ky+(ay-ky)*t);cx.lineTo(kx+(ax-kx)*t+gw,ky+(ay-ky)*t-0.004);cx.stroke();}
 {const bs=(ax+kx)/2>0?1:-1;for(let t=0.15;t<0.95;t+=0.2){ellU(kx+(ax-kx)*t+bs*gw*1.0,ky+(ay-ky)*t,0.0045,0.0045);cx.fillStyle=L*bs>0?'#d8b070':'#4a3a2a';cx.fill();}}
 const [fx,fy]=foot;fillP([[ax-0.03,ay-0.005],[ax+0.03,ay-0.005],[fx+0.05,fy-0.022],[fx+0.05,fy,1],[ax-0.038,fy,1]],sh(ax-0.04,fx+0.05,['#050303','#16100c','#4a3424']));}

function shawl(pts,seed){// black shawl with bright floral embroidery and a fringe
 fillP(pts,IC.bk1);cx.save();path(pts);cx.clip();const r=rngS(seed);const xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]);const x0=Math.min(...xs),x1=Math.max(...xs),y0=Math.min(...ys),y1=Math.max(...ys);
 const cols=['#ff3a4a','#ffb020','#2fb86a','#ff7ab0','#f4f0e0','#4a8aff'];
 for(let i=0;i<22;i++){const x=x0+r()*(x1-x0),y=y0+r()*(y1-y0),rr=0.008+r()*0.01;const c=cols[Math.floor(r()*cols.length)];
  for(let p=0;p<5;p++){const a=p/5*Math.PI*2;ellU(x+Math.cos(a)*rr,y+Math.sin(a)*rr,rr*0.7,rr*0.45,a);cx.fillStyle=c;cx.fill();}ellU(x,y,rr*0.4,rr*0.4);cx.fillStyle='#ffe070';cx.fill();
  cx.strokeStyle='rgba(40,140,70,0.8)';cx.lineWidth=px(1.2);cx.beginPath();cx.moveTo(x+rr,y+rr);cx.quadraticCurveTo(x+rr*2.5,y+rr*1.2,x+rr*3,y+rr*2.6);cx.stroke();}
 cx.fillStyle=sh(x0,x1,['rgba(0,0,0,0.5)','rgba(0,0,0,0)','rgba(255,140,60,0.15)']);cx.fillRect(x0,y0,x1-x0,y1-y0);cx.restore();}

function bandolier(a,b,n,seed){// leather strap with small bronze bells
 strokeP([a,b],'#2a1608',0.024);strokeP([[a[0]+0.004,a[1]-0.006],[b[0]+0.004,b[1]-0.006]],L>0?'rgba(220,150,90,0.6)':'rgba(120,100,130,0.3)',px(1.3));
 for(let i=0;i<n;i++){const t=(i+0.5)/n;sonajo(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t+0.016,0.014);}}

function ropeLine(pts,w=0.012){strokeP(pts,IC.ropeD,w*1.4);strokeP(pts,IC.rope,w);
 // twist marks
 cx.save();cx.setLineDash([w*0.8,w*1.2]);strokeP(pts,'rgba(90,70,30,0.8)',w*0.6);cx.restore();}


function sleeveArm(S,E,W,o={}){// jointed sleeve: deltoid, bicep, elbow point on the outside of the bend, forearm taper, white cuff
 const ws=o.ws??0.033,we=o.we??0.025,ww=o.ww??0.019;const nrm=(a,b)=>{let x=-(b[1]-a[1]),y=b[0]-a[0];const d=Math.hypot(x,y)||1;return [x/d,y/d];};
 const n1=nrm(S,E),n2=nrm(E,W);let ne=[n1[0]+n2[0],n1[1]+n2[1]];{const d=Math.hypot(...ne)||1;ne=[ne[0]/d,ne[1]/d];}
 const turn=Math.sign((E[0]-S[0])*(W[1]-E[1])-(E[1]-S[1])*(W[0]-E[0]))||1; // outside of the bend is -turn*normal
 const M1=[S[0]+(E[0]-S[0])*0.45,S[1]+(E[1]-S[1])*0.45],M2=[E[0]+(W[0]-E[0])*0.4,E[1]+(W[1]-E[1])*0.4];
 const at=(p,n,w)=>[p[0]+n[0]*w,p[1]+n[1]*w];
 const outs=-turn;const A=[at(S,n1,ws),at(M1,n1,ws*0.95),at(E,ne,we*(outs>0?1.25:0.9)),at(M2,n2,we*1.02),at(W,n2,ww)];
 const B=[at(W,n2,-ww),at(M2,n2,-we*1.05),at(E,ne,-we*(outs<0?1.25:0.9)),at(M1,n1,-ws*0.92),at(S,n1,-ws)];
 const xs=[S,E,W].map(p=>p[0]);const x0=Math.min(...xs)-ws,x1=Math.max(...xs)+ws;
 const red=sh(x0,x1,[IC.red0,IC.red1,IC.red2,IC.red3]);
 const P=A.concat(B);fillP(P,red);ellU(S[0],S[1],ws*1.05,ws*0.95);cx.fillStyle=red;cx.fill();
 cx.save();path(P);cx.clip();
 // elbow crease on the inside of the bend, drag folds on the forearm, light ridge along the fire side
 {const e0=at(E,ne,turn*we*1.0),e1=at(E,ne,turn*we*0.15);strokeP([[e0[0]-(W[0]-S[0])*0.06,e0[1]-(W[1]-S[1])*0.06],e1],'rgba(40,0,4,0.6)',0.006);strokeP([[e0[0]+(W[0]-S[0])*0.05,e0[1]+(W[1]-S[1])*0.05],e1],'rgba(40,0,4,0.45)',0.005);}
 for(const t of [0.3,0.6]){const p=[E[0]+(W[0]-E[0])*t,E[1]+(W[1]-E[1])*t];strokeP([at(p,n2,-we*0.9),[p[0]+(W[0]-E[0])*0.08,p[1]+(W[1]-E[1])*0.08],at(p,n2,we*0.6)],'rgba(40,0,4,0.4)',0.004);}
 const lsn=(n)=>n[0]*L>0?1:-1;strokeP([at(S,n1,lsn(n1)*ws*0.6),at(M1,n1,lsn(n1)*ws*0.62),at(E,ne,lsn(ne)*we*0.7),at(W,n2,lsn(n2)*ww*0.6)],'rgba(255,150,110,0.35)',0.006);
 cx.restore();
 // white cuff
 const d=[W[0]-E[0],W[1]-E[1]];const dl=Math.hypot(...d);const u=[d[0]/dl,d[1]/dl];const c0=[W[0]-u[0]*0.012,W[1]-u[1]*0.012];
 fillP([at(c0,n2,ww*1.15),at(W,n2,ww*1.2),at(W,n2,-ww*1.2),at(c0,n2,-ww*1.15)].map((p,i)=>i<2?p:p),sh(x0,x1,[IC.wh0,IC.wh1,IC.wh2,IC.wh3]));
 return Math.atan2(u[1],u[0]);}

function fist(x,y,ang,o={}){// closed fist gripping a rope; +x of the local frame runs along the forearm
 cx.save();cx.translate(x,y);cx.rotate(ang);const s=o.s??1;cx.scale(s,s);
 const col=lgr(0,-0.02,0,0.02,[[0,L>0?'#e0a070':'#6a4030'],[0.5,'#a06a48'],[1,'#3a2016']]);
 // back of the hand (wrist -> knuckles)
 fillP([[-0.004,-0.016],[0.018,-0.019],[0.03,-0.016],[0.034,0.0],[0.03,0.017],[0.012,0.019],[-0.004,0.015]],col);
 // four curled fingers as ridged bands on the palm side
 for(let i=0;i<4;i++){const yy=-0.013+i*0.0088;ellU(0.03,yy,0.0075,0.0048);cx.fillStyle=col;cx.fill();ellU(0.03,yy,0.0075,0.0048);cx.strokeStyle='rgba(30,12,4,0.85)';cx.lineWidth=0.0018;cx.stroke();}
 // knuckle highlights
 for(let i=0;i<4;i++){ellU(0.026,-0.013+i*0.0088,0.0028,0.002);cx.fillStyle='rgba(255,210,160,0.35)';cx.fill();}
 // thumb wrapped over the fingers
 fillP([[0.006,0.014],[0.02,0.02],[0.034,0.014],[0.037,0.006],[0.03,0.006],[0.02,0.01]],lgr(0,0,0,0.02,[[0,'#b07850'],[1,'#4a2a18']]));
 strokeP([[0.008,0.012],[0.022,0.016],[0.034,0.011]],'rgba(40,18,8,0.5)',0.0012);
 cx.restore();}

function issohadore(o={}){const view=o.view||'front';const skin=(x,y,rx,ry,rot=0)=>{const col=sh(x-rx*1.4,x+rx*1.4,['#2a1a12','#8a5a3e','#d8966a']);
  // palm, four fingers curled around (or hanging), and a thumb
  ellU(x,y,rx*0.95,ry*0.8,rot);cx.fillStyle=col;cx.fill();
  cx.save();cx.translate(x,y);cx.rotate(rot);cx.lineCap='round';cx.strokeStyle=col;cx.lineWidth=rx*0.42;
  for(let i=0;i<4;i++){const fx=-rx*0.6+i*rx*0.4;cx.beginPath();cx.moveTo(fx,ry*0.4);cx.lineTo(fx+rx*0.05,ry*1.25-Math.abs(i-1.5)*ry*0.12);cx.stroke();}
  cx.beginPath();cx.moveTo(rx*0.7,0);cx.lineTo(rx*1.15,ry*0.55);cx.stroke();
  cx.strokeStyle='rgba(40,20,10,0.5)';cx.lineWidth=px(0.8);for(let i=1;i<4;i++){const fx=-rx*0.8+i*rx*0.4;cx.beginPath();cx.moveTo(fx,ry*0.5);cx.lineTo(fx,ry*1.1);cx.stroke();}
  cx.restore();};
 const red=(x0,x1)=>sh(x0,x1,[IC.red0,IC.red1,IC.red2,IC.red3]);
 if(view=='front'){
  // relaxed stance: weight on the left leg, right knee eased and foot turned out; hips and shoulders counter-tilted
  issLeg([0.05,-0.553],[0.088,-0.283],[0.108,-0.046],[0.13,0],{tw:0.05});
  issLeg([-0.042,-0.575],[-0.034,-0.295],[-0.028,-0.05],[-0.04,0],{tw:0.05});
  cx.save();cx.translate(0,-0.565);cx.rotate(0.05);cx.translate(0,0.565);
  shawl([[-0.1,-0.6],[0.1,-0.6],[0.105,-0.53],[-0.02,-0.5],[-0.09,-0.36],[-0.12,-0.37],[-0.11,-0.52]],5);
  for(let i=0;i<10;i++){const t=i/9;strokeP([[-0.02-0.07*t,-0.5+0.13*t],[-0.03-0.07*t,-0.47+0.13*t]],'#1a141c',0.005);}
  cx.restore();
  cx.save();cx.translate(-0.008,-0.57);cx.rotate(-0.045);cx.translate(0,0.57);
  // shirt
  fillP([[-0.07,-0.815],[0.07,-0.815],[0.085,-0.575],[-0.085,-0.575]],sh(-0.09,0.09,[IC.wh1,IC.wh2,IC.wh3]));
  for(const sx of [-1,1]){const J=[[sx*0.025,-0.825],[sx*0.09,-0.815],[sx*0.105,-0.76],[sx*0.1,-0.61],[sx*0.095,-0.59],[sx*0.04,-0.595],[sx*0.035,-0.76]];fillP(J,red(-0.11,0.11));
   for(let i=0;i<5;i++){ellU(sx*0.043,-0.79+i*0.045,0.0055,0.0055);cx.fillStyle=sx*L>0?'#ffe08a':'#b88a3a';cx.fill();}}
  bandolier([-0.075,-0.815],[0.09,-0.59],6,2);
  // left hand rests on the hip over the shawl knot (akimbo), right arm hangs easy with the coiled soha
  const aL=sleeveArm([-0.09,-0.8],[-0.17,-0.685],[-0.118,-0.6],{ws:0.03,we:0.024,ww:0.019});
  skin(-0.105,-0.588,0.02,0.024,aL-Math.PI/2);
  const aR=sleeveArm([0.09,-0.8],[0.128,-0.675],[0.138,-0.548],{ws:0.03,we:0.024,ww:0.019});
  for(let i=0;i<4;i++){ellU(0.152,-0.455+i*0.005,0.035+i*0.003,0.058+i*0.004,-0.12);cx.strokeStyle=i%2?IC.rope:IC.ropeD;cx.lineWidth=0.008;cx.stroke();}
  fist(0.139,-0.548,aR,{s:1.15});
  cx.save();cx.translate(0,-0.84);cx.rotate(0.07);cx.translate(0,0.84);
  issHead(0,-0.893,0.108,false);cx.restore();
  cx.restore();
 }else{
  // striding, upright, throwing: far arm raised and bent, fist gripping the soha; near hand holds the coil
  issLeg([-0.03,-0.56],[-0.08,-0.3],[-0.13,-0.06],[-0.12,0],{tw:0.048});
  issLeg([0.04,-0.56],[0.1,-0.3],[0.09,-0.05],[0.1,0],{tw:0.05});
  const S=[0.045,-0.8],E=[0.15,-0.895],W=[0.158,-1.035];
  const RT=[W[0]+0.028*Math.cos(Math.atan2(W[1]-E[1],W[0]-E[0])),W[1]+0.028*Math.sin(Math.atan2(W[1]-E[1],W[0]-E[0]))];
  if(o.twirl){ropeLine([[RT[0],RT[1]+0.01],[RT[0]-0.02,RT[1]-0.07],[0.02,-1.17]],0.008);ellU(-0.06,-1.19,0.17,0.05,-0.12);cx.strokeStyle=IC.ropeD;cx.lineWidth=0.016;cx.stroke();cx.strokeStyle=IC.rope;cx.lineWidth=0.01;cx.stroke();}
  else{ropeLine([[RT[0],RT[1]+0.01],[RT[0]+0.04,RT[1]-0.1],[0.3,-1.2],[0.37,-1.14]],0.008);
  ellU(0.41,-1.02,0.075,0.12,0.35);cx.strokeStyle=IC.ropeD;cx.lineWidth=0.014;cx.stroke();cx.strokeStyle=IC.rope;cx.lineWidth=0.009;cx.stroke();}
  const aT=sleeveArm(S,E,W,{ws:0.032,we:0.025,ww:0.019});
  fist(W[0],W[1],aT,{s:1.25});
  fillP([[-0.06,-0.815],[0.06,-0.815],[0.07,-0.56],[-0.07,-0.56]],sh(-0.07,0.07,[IC.wh1,IC.wh2,IC.wh3]));
  shawl([[-0.08,-0.6],[0.075,-0.6],[0.08,-0.53],[-0.03,-0.5],[-0.1,-0.37],[-0.125,-0.39],[-0.1,-0.52]],7);
  for(let i=0;i<10;i++){const t=i/9;strokeP([[-0.03-0.07*t,-0.5+0.12*t],[-0.04-0.07*t,-0.47+0.12*t]],'#1a141c',0.005);}
  const J=[[-0.075,-0.82],[0.02,-0.83],[0.05,-0.81],[0.08,-0.75],[0.08,-0.61],[0.02,-0.59],[-0.085,-0.595],[-0.09,-0.72]];fillP(J,red(-0.09,0.08));
  fillP([[0.035,-0.815],[0.08,-0.78],[0.08,-0.61],[0.045,-0.605]],sh(0.035,0.08,[IC.wh1,IC.wh2,IC.wh3]));
  for(let i=0;i<5;i++){ellU(0.043,-0.79+i*0.045,0.0055,0.0055);cx.fillStyle='#ffe08a';cx.fill();}
  bandolier([-0.055,-0.815],[0.075,-0.595],5,4);
  const aN=sleeveArm([-0.07,-0.8],[-0.108,-0.68],[-0.07,-0.59],{ws:0.03,we:0.024,ww:0.018});
  for(let i=0;i<4;i++){ellU(-0.06,-0.505+i*0.005,0.034+i*0.003,0.052+i*0.004,0.2);cx.strokeStyle=i%2?IC.rope:IC.ropeD;cx.lineWidth=0.008;cx.stroke();}
  fist(-0.07,-0.59,aN,{s:1.15});
  issHead(0.025,-0.893,0.108,true);}
}
