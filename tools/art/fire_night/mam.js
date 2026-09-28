// Mamuthone, drawn in unit space (see lib2.js). view: 'front' | 'q' (3/4 facing +x). opts.step (0..1 gait), opts.jump
const MC={fl0:'#0b090a',fl1:'#1d1718',fl2:'#3a2c2a',flW:'#8a4a26',flH:'#e0874a',
 wd0:'#080504',wd1:'#1a0e09',wd2:'#4a2816',wdH:'#c47a44',
 kr0:'#140b07',kr1:'#2c180d',kr2:'#553018',kr3:'#8a5530',
 tr0:'#170e09',tr1:'#35200f',tr2:'#6a4428',ga0:'#0d0907',ga1:'#2c1d14',ga2:'#6a4a32'};

// ---------- head: soot-black carved mask framed by a brown kerchief knotted under the chin.
// Hand-designed front and 3/4 (facing +x) versions; (hx,hy) = centre, s = head size
function woodC(k){k=Math.max(0,Math.min(1,k));const A=[10,6,5],B=[70,40,26],C=[196,128,80];const m=k<0.6?A.map((v,i)=>v+(B[i]-v)*k/0.6):B.map((v,i)=>v+(C[i]-v)*(k-0.6)/0.4);return `rgb(${m.map(Math.round)})`;}
function mamHead(hx,hy,s,th,o={}){const q=th>0.3;const Q=(x,y)=>[hx+x*s,hy+y*s];const QP=pts=>pts.map(([x,y,f])=>[hx+x*s,hy+y*s,f]);
 const lk=x=>Math.max(0,Math.min(1,0.5+(L>0?x:-x)*1.1)); // how much a point at local x faces the fire
 // kerchief
 const K=q?[[-0.5,-0.02],[-0.46,-0.42],[-0.24,-0.64],[0.1,-0.67],[0.34,-0.52],[0.42,-0.3],[0.46,0.02],[0.44,0.34],[0.3,0.52],[0.06,0.58],[-0.24,0.46],[-0.44,0.26]]
          :[[-0.5,-0.05],[-0.46,-0.45],[-0.22,-0.66],[0.22,-0.66],[0.46,-0.45],[0.5,-0.05],[0.42,0.34],[0.16,0.56],[-0.16,0.56],[-0.42,0.34]];
 const KP=QP(K);fillP(KP,sh(hx-0.5*s,hx+0.5*s,SMALL?['#0a0604','#160c07','#2a170c','#4a2a16']:['#120a06','#2a170c','#4e2e18','#7e4c2a']));
 cx.save();path(KP);cx.clip();
 const folds=q?[[[-0.42,-0.4],[-0.1,-0.5],[0.3,-0.46]],[[-0.46,0.0],[-0.36,0.3],[-0.1,0.5]],[[-0.3,-0.56],[-0.05,-0.6],[0.2,-0.62]],[[-0.44,-0.2],[-0.3,0.1],[-0.25,0.42]]]
              :[[[-0.4,-0.5],[0,-0.6],[0.4,-0.5]],[[-0.46,-0.1],[-0.4,0.25],[-0.14,0.5]],[[0.46,-0.1],[0.4,0.25],[0.14,0.5]],[[-0.3,-0.58],[0,-0.54],[0.3,-0.58]]];
 folds.forEach(([a,b,c])=>{const pa=Q(...a),pb=Q(...b),pc=Q(...c);cx.lineCap='round';
  cx.beginPath();cx.moveTo(...pa);cx.quadraticCurveTo(...pb,...pc);cx.strokeStyle='rgba(8,4,2,0.6)';cx.lineWidth=0.04*s;cx.stroke();
  cx.beginPath();cx.moveTo(pa[0],pa[1]-0.035*s);cx.quadraticCurveTo(pb[0],pb[1]-0.035*s,pc[0],pc[1]-0.035*s);cx.strokeStyle=`rgba(200,130,80,${0.12+0.3*lk(b[0])})`;cx.lineWidth=0.025*s;cx.stroke();});
 cx.restore();
 // mask
 const M=q?[[-0.22,-0.44],[0.1,-0.48],[0.3,-0.41],[0.36,-0.26],[0.42,-0.17],[0.34,-0.08],[0.38,0.0],[0.47,0.1],[0.4,0.17],[0.35,0.2],[0.37,0.27],[0.33,0.33],[0.33,0.4],[0.18,0.47],[-0.04,0.44],[-0.22,0.3],[-0.29,0.02],[-0.28,-0.24]]
          :[[0,-0.47],[0.3,-0.43],[0.38,-0.2],[0.37,0.05],[0.3,0.28],[0.16,0.42],[0,0.46],[-0.16,0.42],[-0.3,0.28],[-0.37,0.05],[-0.38,-0.2],[-0.3,-0.43]];
 const MPts=QP(M);fillP(MPts,sh(hx+(q?-0.29:-0.38)*s,hx+(q?0.47:0.38)*s,[woodC(0.0),woodC(0.12),woodC(0.32),woodC(0.5)]));
 cx.save();path(MPts);cx.clip();
 const plane=(pts,k,a=1)=>{fillP(QP(pts),woodC(k),true);};
 const soft=(x,y,r,col)=>{const [X,Y]=Q(x,y);cx.fillStyle=rgr(X,Y,r*s,[[0,col],[1,'rgba(0,0,0,0)']]);cx.fillRect(X-r*s,Y-r*s,2*r*s,2*r*s);};
 if(!q){
  // forehead and cheek planes catch the fire
  soft(0.12,-0.34,0.24,`rgba(170,100,60,${0.3+0.45*lk(0.2)})`);soft(0.24,0.1,0.15,`rgba(190,110,65,${0.3+0.6*lk(0.3)})`);soft(-0.24,0.1,0.14,`rgba(130,76,48,${0.2+0.4*lk(-0.3)})`);
  for(const yy of [-0.36,-0.3]){const pp=[];for(let x=-0.24;x<=0.2401;x+=0.06)pp.push(Q(x,yy+0.015*Math.cos(x*10)));strokeP(pp,'rgba(0,0,0,0.6)',0.018*s);}
  // eye sockets and holes (drooping outward: grave)
  for(const sx of [-1,1]){fillP(QP([[sx*0.05,-0.1],[sx*0.2,-0.13],[sx*0.32,-0.07],[sx*0.28,0.02],[sx*0.12,0.02]]),'rgba(0,0,0,0.55)');
   fillP(QP([[sx*0.08,-0.06],[sx*0.17,-0.085],[sx*0.27,-0.04],[sx*0.24,-0.02],[sx*0.16,-0.02],[sx*0.09,-0.035]]),'#010000');}
  // heavy brow: a knotted frown
  const BR=[[-0.37,-0.2],[-0.2,-0.265],[-0.05,-0.215],[0,-0.17],[0.05,-0.215],[0.2,-0.265],[0.37,-0.2],[0.35,-0.14],[0.2,-0.155],[0.06,-0.12],[0,-0.1],[-0.06,-0.12],[-0.2,-0.155],[-0.35,-0.14]];
  fillP(QP(BR),sh(hx-0.37*s,hx+0.37*s,[woodC(0.12),woodC(0.3),woodC(0.62)]));
  fillP(QP([[0.05,-0.215],[0.2,-0.265],[0.37,-0.2],[0.2,-0.235]]),woodC(0.55+0.35*lk(0.3)));fillP(QP([[-0.05,-0.215],[-0.2,-0.265],[-0.37,-0.2],[-0.2,-0.235]]),woodC(0.3+0.2*lk(-0.3)));
  // nose
  fillP(QP([[-0.04,-0.12],[0.04,-0.12],[0.07,0.08],[0.13,0.15],[0.08,0.2],[0,0.19],[-0.08,0.2],[-0.13,0.15],[-0.07,0.08]]),sh(hx-0.13*s,hx+0.13*s,[woodC(0.1),woodC(0.28),woodC(0.7)]));
  fillP(QP([[0.01,-0.1],[0.04,-0.1],[0.06,0.1],[0.02,0.14]]),woodC(0.5+0.4*lk(0.1)));
  cx.fillStyle='#010000';ellU(...Q(-0.055,0.17),0.03*s,0.015*s);cx.fill();ellU(...Q(0.055,0.17),0.03*s,0.015*s);cx.fill();
  // nasolabial grooves, small closed mouth, chin
  for(const sx of [-1,1])strokeP([Q(sx*0.12,0.14),Q(sx*0.17,0.24),Q(sx*0.15,0.33)],'rgba(0,0,0,0.85)',0.028*s);
  strokeP([Q(-0.09,0.3),Q(0,0.285),Q(0.09,0.3)],'#010000',0.024*s);fillP(QP([[-0.07,0.315],[0.07,0.315],[0.04,0.34],[-0.04,0.34]]),woodC(0.3+0.3*lk(0)));
  soft(0.03,0.39,0.08,`rgba(150,90,55,${0.35*lk(0.1)})`);
 }else{
  soft(0.2,-0.32,0.22,`rgba(180,105,62,${0.35+0.5*lk(0.3)})`);soft(0.25,0.12,0.14,`rgba(200,118,68,${0.35+0.55*lk(0.4)})`);soft(-0.12,0.14,0.16,'rgba(90,55,35,0.35)');
  for(const yy of [-0.35,-0.29]){const pp=[];for(let x=-0.18;x<=0.301;x+=0.06)pp.push(Q(x,yy+0.015*Math.cos(x*10)));strokeP(pp,'rgba(0,0,0,0.6)',0.018*s);}
  // near eye (large) and far eye (foreshortened)
  fillP(QP([[-0.2,-0.1],[-0.02,-0.13],[0.12,-0.07],[0.08,0.02],[-0.14,0.02]]),'rgba(0,0,0,0.55)');
  fillP(QP([[-0.14,-0.055],[-0.04,-0.085],[0.07,-0.045],[0.04,-0.02],[-0.05,-0.02],[-0.13,-0.035]]),'#010000');
  fillP(QP([[0.2,-0.1],[0.3,-0.11],[0.33,-0.06],[0.3,0.0],[0.2,0.0]]),'rgba(0,0,0,0.55)');
  fillP(QP([[0.23,-0.06],[0.3,-0.075],[0.32,-0.045],[0.29,-0.025],[0.24,-0.03]]),'#010000');
  // brow ridge sweeping to the far side, overhanging
  const BR=[[-0.28,-0.2],[-0.1,-0.26],[0.1,-0.2],[0.16,-0.17],[0.28,-0.23],[0.42,-0.17],[0.36,-0.12],[0.26,-0.14],[0.16,-0.11],[0.08,-0.12],[-0.08,-0.15],[-0.26,-0.14]];
  fillP(QP(BR),sh(hx-0.28*s,hx+0.42*s,[woodC(0.12),woodC(0.3),woodC(0.7)]));
  fillP(QP([[0.16,-0.17],[0.28,-0.23],[0.42,-0.17],[0.3,-0.2]]),woodC(0.6+0.35*lk(0.4)));fillP(QP([[-0.1,-0.26],[0.1,-0.2],[-0.05,-0.22]]),woodC(0.35+0.3*lk(0)));
  // nose: side plane toward us, ridge catching the fire, protruding past the far cheek
  fillP(QP([[0.16,-0.12],[0.22,-0.1],[0.47,0.1],[0.4,0.17],[0.3,0.18],[0.18,0.15],[0.2,0.05]]),sh(hx+0.16*s,hx+0.47*s,[woodC(0.12),woodC(0.28),woodC(0.55)]));
  strokeP([Q(0.22,-0.1),Q(0.34,0.0),Q(0.45,0.095)],`rgba(200,125,75,${0.3+0.4*lk(0.4)})`,0.018*s);
  cx.fillStyle='#010000';ellU(...Q(0.33,0.155),0.035*s,0.016*s,0.2);cx.fill();
  strokeP([Q(0.18,0.15),Q(0.2,0.25),Q(0.18,0.34)],'rgba(0,0,0,0.85)',0.028*s);
  strokeP([Q(0.2,0.3),Q(0.28,0.285),Q(0.35,0.28)],'#010000',0.024*s);
  soft(0.26,0.4,0.08,`rgba(150,90,55,${0.4*lk(0.3)})`);
 }
 if(!SMALL){// full size: a warm sheen of firelight across the carved planes
  cx.globalCompositeOperation='soft-light';cx.fillStyle=sh(hx-0.4*s,hx+0.5*s,['rgba(0,0,0,0)','rgba(255,150,80,0.35)','rgba(255,170,100,0.9)']);cx.fillRect(hx-0.6*s,hy-0.6*s,1.2*s,1.2*s);cx.globalCompositeOperation='source-over';}
 if(SMALL){// game size: the carved face catches the fire so it reads as a mask against the dark kerchief
  cx.fillStyle=sh(hx-0.3*s,hx+0.45*s,['rgba(110,60,34,0.95)','rgba(190,110,60,0.95)','rgba(245,165,95,1)']);cx.fillRect(hx-0.6*s,hy-0.6*s,1.2*s,1.2*s);
  cx.fillStyle='rgba(40,18,10,0.9)';cx.fillRect(hx-0.6*s,hy-0.2*s,1.2*s,0.05*s);
  cx.fillStyle='#050202';ellU(...Q(q?-0.03:-0.17,-0.06),0.09*s,0.05*s);cx.fill();ellU(...Q(q?0.26:0.17,-0.06),(q?0.05:0.09)*s,0.045*s);cx.fill();
  strokeP([Q(q?0.18:-0.1,0.3),Q(q?0.33:0.1,0.29)],'#1a0a05',0.05*s);
  if(q){fillP(QP([[0.2,-0.1],[0.47,0.12],[0.36,0.2],[0.2,0.14]]),'rgba(255,200,140,0.9)');}}
 cx.restore();
 path(MPts);cx.strokeStyle='rgba(0,0,0,0.75)';cx.lineWidth=0.014*s;cx.stroke();
 // knot under the chin with two short ends
 const [kx,ky]=Q(q?0.12:0,0.58);ellU(kx,ky,0.1*s,0.075*s);cx.fillStyle=sh(kx-0.1*s,kx+0.1*s,['#140b06','#3a2010','#6a3e20']);cx.fill();
 fillP([[kx-0.04*s,ky+0.04*s],[kx-0.12*s,ky+0.26*s],[kx-0.04*s,ky+0.24*s],[kx,ky+0.06*s]],'#2a170c');
 fillP([[kx+0.03*s,ky+0.04*s],[kx+0.1*s,ky+0.3*s],[kx+0.16*s,ky+0.26*s],[kx+0.08*s,ky+0.04*s]],sh(kx,kx+0.16*s,['#2a170c','#4e2e18','#7e4c2a']));}

// ---------- body
// fleece volume: core shadow, bounce and a warm lit shoulder, so the black mass has form
function fleeceForm(B,x0,x1,y0,y1){if(SMALL)return;cx.save();path(B);cx.clip();
 cx.globalCompositeOperation='multiply';cx.fillStyle=sh(x0,x1,['rgb(120,120,160)','rgb(70,62,80)','rgb(150,135,140)','rgb(255,255,255)','rgb(255,255,255)']);cx.fillRect(x0-0.1,y0-0.1,x1-x0+0.2,y1-y0+0.2);
 cx.fillStyle=lgr(0,y0,0,y1,[[0,'rgb(255,255,255)'],[0.7,'rgb(230,225,235)'],[1,'rgb(120,110,130)']]);cx.fillRect(x0-0.1,y0-0.1,x1-x0+0.2,y1-y0+0.2);
 cx.globalCompositeOperation='screen';const lx=L>0?x1-0.06:x0+0.06;cx.fillStyle=rgr(lx,y0+0.12,0.22,[[0,'rgba(170,80,35,0.35)'],[1,'rgba(0,0,0,0)']]);cx.fillRect(x0-0.1,y0-0.1,x1-x0+0.2,y1-y0+0.2);
 cx.restore();}
function carriga(pts,bells,seed){fillP(pts,MC.fl0);
 bells.sort((a,b)=>(a[4]||0)-(b[4]||0)).forEach(([x,y,s,a,d],i)=>cowbell(x,y,s,a,seed+i,d==null?1:Math.max(0.15,1-d)));}
function legPair(o,view){const st=o.step??0;const up=o.jump?0.05:0;
 const leg=(hipX,kneeX,ankX,footDX,yl)=>{const K=SMALL?1.4:1;cx.save();cx.translate(ankX,0);cx.scale(K,1);cx.translate(-ankX,0);
  // dark brown velvet trousers, baggy, bunching over the gaiters
  const TR=[[hipX-0.05,-0.4-yl],[hipX+0.05,-0.4-yl],[kneeX+0.047,-0.27-yl],[ankX+0.043,-0.21-yl],[ankX+0.02,-0.195-yl],[ankX-0.02,-0.2-yl],[ankX-0.045,-0.21-yl],[kneeX-0.047,-0.27-yl]];
  fillP(TR,sh(hipX-0.05,hipX+0.05,['#0a0604','#140c07','#24160c','#4a2e1a']));
  cx.save();path(TR);cx.clip();cx.fillStyle=lgr(0,-0.4-yl,0,-0.3-yl,[[0,'rgba(0,0,0,0.85)'],[1,'rgba(0,0,0,0)']]);cx.fillRect(hipX-0.1,-0.42-yl,0.2,0.14);
  cx.strokeStyle='rgba(0,0,0,0.5)';cx.lineWidth=px(1.6);for(const d of [0,0.025,0.05]){cx.beginPath();cx.moveTo(kneeX-0.035,-0.28-yl+d);cx.quadraticCurveTo(kneeX,-0.255-yl+d,kneeX+0.04,-0.275-yl+d);cx.stroke();}
  cx.restore();
  // leather cambales: shaped to the calf, buttoned on the outer side
  const G=[[ankX-0.037,-0.215-yl],[ankX+0.037,-0.215-yl],[ankX+0.041,-0.15-yl],[ankX+0.03,-0.07-yl],[ankX+0.027,-0.04-yl],[ankX-0.027,-0.04-yl],[ankX-0.03,-0.07-yl],[ankX-0.041,-0.15-yl]];
  fillP(G,sh(ankX-0.041,ankX+0.041,['#050303','#0c0806','#1a120c','#3e2a1a']));
  const bs=ankX>0?1:-1;for(const yy of [-0.19,-0.155,-0.12,-0.085,-0.055]){ellU(ankX+bs*0.028,yy-yl,0.005,0.005);cx.fillStyle=L*bs>0?'#c08a50':'#3a2a1c';cx.fill();}
  cx.strokeStyle='rgba(120,80,50,0.4)';cx.lineWidth=px(1.2);cx.beginPath();cx.moveTo(ankX-0.037,-0.212-yl);cx.lineTo(ankX+0.037,-0.212-yl);cx.stroke();
  // boot
  fillP([[ankX-0.03,-0.05-yl],[ankX+0.03,-0.05-yl],[ankX+0.045+footDX,-0.022-yl],[ankX+0.045+footDX,0-yl,1],[ankX-0.038,0-yl,1]],sh(ankX-0.04,ankX+0.05+footDX,['#050303','#140c08','#3a2618']));cx.restore();};
 if(view=='front'){leg(-0.065,-0.072,-0.078,-0.012,up);leg(0.065,0.072,0.078,0.012,up);}
 else{const a=Math.sin(st*Math.PI*2)*0.05;leg(-0.04,-0.06-a,-0.075-a,0.045,up+Math.max(0,-a)*0.4);leg(0.05,0.065+a,0.075+a,0.06,up+Math.max(0,a)*0.4);}}

function mamuthone(o={}){const view=o.view||'front';const up=o.jump?0.05:0;const T=(pts)=>pts.map(([x,y,f])=>[x,y-up,f]);const dens=o.dens??1;
 legPair(o,view);
 if(view=='front'){
  // carriga: a dark dome rising behind the head, bells hanging mouth-down at its rim
  // carriga seen from the front: only a dark hump rising behind the shoulders; a few bell mouths
  // hang down and outward past each shoulder, and the big bells bulge at the hips
  const hump=T([[-0.23,-0.5],[-0.235,-0.72],[-0.19,-0.84],[-0.08,-0.905],[0.08,-0.905],[0.19,-0.84],[0.235,-0.72],[0.23,-0.5]]);
  fillP(hump,MC.fl0);
  const fb=[];for(const sx of [-1,1]){fb.push([sx*0.225,-0.74-up,0.07,-sx*0.55,0.5+sx*0.2*L],[sx*0.245,-0.64-up,0.08,-sx*0.45,0.4+sx*0.2*L],[sx*0.19,-0.8-up,0.06,-sx*0.65,0.6+sx*0.2*L],[sx*0.235,-0.5-up,0.1,-sx*0.12,0.35+sx*0.2*L]);}
  fb.forEach(([x,y,sz,a,d],i)=>cowbell(x,y,sz,a,3+i,Math.max(0.15,1-d)));
  locks(T([[-0.2,-0.8],[-0.1,-0.88],[0.1,-0.88],[0.2,-0.8],[0.21,-0.72],[-0.21,-0.72]]),-0.21,-0.9-up,0.21,-0.72-up,17,{n:46*dens,len:0.09,wid:0.055});
  // mastruca with the arms inside; hands show at the sides
  const B=T([[-0.06,-0.815],[0.06,-0.815],[0.16,-0.795],[0.205,-0.72],[0.215,-0.58],[0.23,-0.42],[0.21,-0.33],[0.1,-0.315],[0,-0.31],[-0.1,-0.315],[-0.21,-0.33],[-0.23,-0.42],[-0.215,-0.58],[-0.205,-0.72],[-0.16,-0.795]]);
  fillP(B,MC.fl0);
  for(const sx of [-1,1]){ellU(sx*0.215,-0.455-up,0.024,0.03);cx.fillStyle=sh(sx*0.215-0.03,sx*0.215+0.03,['#140a06','#4a2a18','#b06a3c']);cx.fill();}
  locks(B,-0.24,-0.83-up,0.24,-0.35-up,5,{n:150*dens,len:0.1,wid:0.05});fleeceForm(B,-0.24,0.24,-0.83-up,-0.3-up);
  // arm contours under the fleece
  for(const sx of [-1,1])strokeP(T([[sx*0.16,-0.74],[sx*0.19,-0.6],[sx*0.2,-0.48]]),'rgba(0,0,0,0.55)',0.012);
  // carriga straps over the shoulders
  for(const sx of [-1,1]){strokeP(T([[sx*0.085,-0.815],[sx*0.13,-0.72],[sx*0.16,-0.6]]),'#241208',0.022);strokeP(T([[sx*0.085+0.008,-0.817],[sx*0.13+0.008,-0.722],[sx*0.16+0.008,-0.602]]),sx*L>0?'rgba(220,150,90,0.75)':'rgba(120,100,130,0.35)',px(1.4));}
  // sonajolos hung from a chest strap
  strokeP(T([[-0.11,-0.735],[0,-0.715],[0.11,-0.735]]),'#241208',0.016);
  const r=rngS(4);const sj=[];for(let i=0;i<13;i++){const a=r()*Math.PI*2,d=Math.sqrt(r())*0.05;sj.push([Math.cos(a)*d*1.3,-0.665-up+Math.sin(a)*d*0.75]);}sj.sort((a,b)=>a[1]-b[1]).forEach(([x,y])=>sonajo(x,y,0.016));
  mamHead(0,-0.875-up,SMALL?0.16:0.14,0);
 }else{
  // hunched forward: fleece body, a big rounded hump of tiered cowbells on the back, head low and forward
  const B=T([[0.05,-0.81],[0.15,-0.76],[0.2,-0.64],[0.22,-0.48],[0.2,-0.34],[0.1,-0.315],[-0.04,-0.31],[-0.15,-0.33],[-0.2,-0.46],[-0.2,-0.66],[-0.12,-0.8],[-0.03,-0.84]]);
  fillP(B,MC.fl0);
  ellU(0.2,-0.455-up,0.024,0.03,0.3);cx.fillStyle=sh(0.175,0.225,['#140a06','#4a2a18','#c07a48']);cx.fill();
  locks(B,-0.21,-0.85-up,0.23,-0.35-up,6,{n:130*dens,len:0.1,wid:0.05,lean:0.1});fleeceForm(B,-0.21,0.23,-0.85-up,-0.3-up);
  strokeP(T([[0.1,-0.74],[0.16,-0.62],[0.19,-0.48]]),'rgba(0,0,0,0.5)',0.012);
  const hump=T([[-0.03,-0.84],[-0.12,-0.9],[-0.25,-0.87],[-0.33,-0.77],[-0.345,-0.62],[-0.31,-0.5],[-0.21,-0.46],[-0.1,-0.49],[-0.05,-0.62]]);
  const r=rngS(12);const bl=[];const hp=hump.map(p=>[p[0],p[1]]);
  for(let t=0;t<900&&bl.length<26;t++){const x=-0.37+r()*0.34,y=-0.93-up+r()*0.5;if(!ipp(hp,x,y+0.02))continue;const yy=(y+up+0.93)/0.5;const sz=0.066+0.04*yy;
   if(bl.some(b=>Math.hypot(b[0]-x,(b[1]-y)*1.2)<Math.min(sz,b[2])*0.62))continue;bl.push([x,y,sz*(0.9+r()*0.2),0.2+(x+0.2)*-1.2+(r()-0.5)*0.4,-(y+up)*0.4+r()*0.1]);}
  bl.sort((p,q)=>p[1]-q[1]);bl.forEach((b,i)=>b[4]=i/bl.length*-1+1.2-(b[0]+0.37)*1.2);carriga(hump,bl,9);
  for(const y of [-0.55,-0.66,-0.77])strokeP(T([[-0.36,y+0.02],[-0.22,y],[-0.06,y+0.015]]),'rgba(18,9,4,0.85)',0.012);
  strokeP(T([[-0.02,-0.83],[0.08,-0.77],[0.15,-0.63]]),'#241208',0.022);strokeP(T([[-0.012,-0.835],[0.088,-0.775],[0.158,-0.635]]),L>0?'rgba(230,160,100,0.8)':'rgba(120,100,130,0.35)',px(1.4));
  const r2=rngS(8);const sj=[];for(let i=0;i<11;i++){const a=r2()*Math.PI*2,d=Math.sqrt(r2())*0.045;sj.push([0.165+Math.cos(a)*d*0.7,-0.65-up+Math.sin(a)*d]);}sj.sort((a,b)=>a[1]-b[1]).forEach(([x,y])=>sonajo(x,y,0.015));
  mamHead(0.1,-0.855-up,SMALL?0.16:0.14,0.75);}
}
