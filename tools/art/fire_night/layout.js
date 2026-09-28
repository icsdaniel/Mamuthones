// Shared layout geometry (720x1440 portrait), taken from the current game.
const W=720,H=1440;
const HITY=1068;            // hit line (about 84% of the field height)
const TOPY=195;             // far end of the road (42% of the width)
const FIELD_TOP=150;        // HUD sits above
const BTN_Y=1244;           // step buttons span the bottom, 196 px tall
const VPY=-436,KP=1504;     // straight road edges converge at (360,-436)
const ZMAX=1.381;           // z: distance ahead of the hit line, 0 = hit line, ZMAX = far end
const yOfZ=z=>VPY+KP/(1+z);
const zOfY=y=>KP/(y-VPY)-1;
const wOfY=y=>720*(y-VPY)/KP;          // road width at screen y (720 at the hit line)
const edgeL=y=>360-wOfY(y)/2, edgeR=y=>360+wOfY(y)/2;
const laneX=(l,y)=>360+l*wOfY(y)/3;    // lane centres, l = -1, 0, 1
const laneW=y=>wOfY(y)/3;
function rng(seed){let a=seed>>>0;return ()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
