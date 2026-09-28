// Fire Night sprites for the play screen, cut from the approved mockup's own drawing code (mock.js,
// lib2.js, mam.js, iss.js). Each job draws into its own canvas at `s` times its size in reference
// pixels (the mockup's 720x1440 frame). render.js saves them to game/art/fire/ and writes their cells
// (size, anchor, and the drawn part's bounds) to game/scripts/art/fire_cells.gd for the game.
// The moving parts (flames, sparks, beads, bursts) are drawn by the game.
//
// A job: { name, w, h, s, ax, ay, draw } — w x h reference pixels, anchor (ax, ay) = the point the game
// places (a note's centre, a figure's feet), drawn at scale s.

function job(name, w, h, s, ax, ay, draw) { return { name, w, h, s, ax, ay, draw }; }

// ---------- background ----------
const SKY_H = 260;
// Sky, stars, smoke and the village skyline down to just below the road's far end (TOPY), with the
// dark shade behind the two HUD corners (the mockup's hud() shading).
function skyJob() {
  sky(); skyline();
  g.fillStyle = rg(110, 52, 0, 190, [[0, 'rgba(4,3,12,0.72)'], [1, 'rgba(4,3,12,0)']]); g.fillRect(0, 0, 320, 130);
  g.fillStyle = rg(610, 52, 0, 190, [[0, 'rgba(4,3,12,0.72)'], [1, 'rgba(4,3,12,0)']]); g.fillRect(400, 0, 320, 130);
}
// The square: fire-warmed cobbles, the crowd at its edge, darkening toward the player. Starts GROUND_Y0
// above the far end so the crowd's heads fit; ends at the buttons. (The beat rings are the game's.)
const GROUND_Y0 = 150, GROUND_Y1 = BTN_Y;
function groundJob() {
  g.translate(0, -GROUND_Y0);
  ground(false);
  g.fillStyle = '#07060c'; g.fillRect(0, HITY, W, GROUND_Y1 - HITY);
  g.globalCompositeOperation = 'source-atop';
  g.fillStyle = rg(360, 640, 300, 900, [[0, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,0,0.55)']]); g.fillRect(0, GROUND_Y0, W, GROUND_Y1);
  g.globalCompositeOperation = 'source-over';
}
// The pyre: stacked logs at the fire's base, rims glowing (the flames are a shader). The mockup's
// bonfire() draws them after its flame field, from the same random sequence.
function pyreJob() {
  g.translate(-160, -150); const bx = 360, by = 198; const r = rng(21);
  for (let i = 0; i < 16; i++) { const t = r(), lx = bx + (r() - 0.5) * 240 * (1 - t * 0.4), ly = by - 3 - t * 14, len = 34 + r() * 40, a = (r() - 0.5) * 0.8; g.save(); g.translate(lx, ly); g.rotate(a); g.fillStyle = '#1a0c08'; g.fillRect(-len / 2, -3.5, len, 7); g.fillStyle = `rgba(255,${130 + r() * 90},50,${0.55 + r() * 0.4})`; g.fillRect(-len / 2, -4.5, len, 2); g.restore(); }
}
// The road's basalt setts, flat (the game lays the road back in perspective): 12 blocks across the road,
// staggered courses, each block within a few percent of the stone's value, dark grout. Tiles down.
const SETT_W = 720, SETT_H = 208, SETT_ROWS = 8;
function settsJob() {
  const rr = rng(77), ch = SETT_H / SETT_ROWS, n = 12, bw = SETT_W / n;
  for (let row = 0; row < SETT_ROWS; row++) {
    const y = row * ch, off = row % 2 ? 0.5 : 0;
    for (let k = -1; k <= n; k++) {
      const x0 = (k + off) * bw, t = rr(), v = t < 0.5 ? 255 : 0;
      g.fillStyle = `rgba(${v},${v},${v},${0.018 + 0.028 * rr()})`; g.fillRect(x0, y, bw, ch);
      g.strokeStyle = 'rgba(0,0,0,0.30)'; g.lineWidth = 1.6; g.strokeRect(x0, y, bw, ch);
    }
  }
}

// ---------- notes ----------
// The step: matte deep red with an ember core, its halo and its reflection on the stone. At its size
// on the mockup's hit line (a 240 px lane).
function gemJob(off) { return () => gem(128, 62, 1, { off }); }
// End of a hold: the hollow gold ring.
function ringJob() { const x = 80, y = 40, rx = 0.24 * 240, ry = rx * 0.38; g.save(); g.shadowColor = 'rgba(255,200,90,0.9)'; g.shadowBlur = 14; g.strokeStyle = '#ffd27a'; g.lineWidth = 8; ell(x, y, rx, ry); g.stroke(); g.restore(); g.strokeStyle = 'rgba(255,250,225,0.9)'; g.lineWidth = 2; g.beginPath(); g.ellipse(x, y, rx, ry, 0, Math.PI * 1.1, Math.PI * 1.9); g.stroke(); }
// The woven sash of a hold, one repeat, in flat road pixels (a 240 px lane, 0.34 of it wide).
const SASH_W = 82, SASH_H = 64;
function sashJob() {
  g.fillStyle = lg(0, 0, SASH_W, 0, [[0, '#8a0d14'], [0.35, '#d01d1f'], [0.65, '#d8201f'], [1, '#8a0d14']]); g.fillRect(0, 0, SASH_W, SASH_H);
  for (let y = 0; y < SASH_H; y += 8) { g.fillStyle = 'rgba(60,0,8,0.32)'; g.fillRect(0, y, SASH_W, 3); }
  for (let x = 4; x < SASH_W; x += 10) { g.fillStyle = 'rgba(255,120,90,0.08)'; g.fillRect(x, 0, 2, SASH_H); }
  const cx = SASH_W / 2, cy = SASH_H / 2, hw = 21, hh = 17;
  g.beginPath(); g.moveTo(cx, cy - hh); g.lineTo(cx + hw, cy); g.lineTo(cx, cy + hh); g.lineTo(cx - hw, cy); g.closePath();
  g.fillStyle = lg(0, cy - hh, 0, cy + hh, [[0, '#ffe7a0'], [0.5, '#ffc84a'], [1, '#d88a20']]); g.fill(); g.strokeStyle = '#5a0710'; g.lineWidth = 2; g.stroke();
}
// The bell band in flat road pixels (720 wide, 46 tall, centred at 45): bronze to gold, chevrons at the
// two ends pointing the swing. The words and the badge are drawn upright by the game.
const BAR_T = 46;
function barJob(dir) {
  return () => {
    const y0 = 45 - BAR_T / 2, y1 = 45 + BAR_T / 2, ym = 45;
    g.fillStyle = 'rgba(0,0,0,0.5)'; g.fillRect(0, y0 + 10, 720, BAR_T + 14);
    g.save(); g.shadowColor = 'rgba(255,170,60,0.8)'; g.shadowBlur = 16; g.fillStyle = '#5a3208'; g.fillRect(2, y0 + 6, 716, BAR_T); g.restore();
    g.fillStyle = lg(0, y0, 0, y1, [[0, '#fff1c0'], [0.35, '#f2b64a'], [1, '#b0681c']]); g.fillRect(2, y0, 716, BAR_T);
    g.strokeStyle = '#2a1204'; g.lineWidth = 3; g.strokeRect(2, y0, 716, BAR_T);
    const hh = BAR_T * 0.3;
    for (const u of [-0.86, 0.86]) { const x = 360 + u * 360, wd = hh * 1.8;
      g.strokeStyle = '#3a1604'; g.lineWidth = 6; g.lineJoin = 'round'; g.lineCap = 'round'; g.beginPath(); g.moveTo(x - wd, ym + hh * dir); g.lineTo(x, ym - hh * dir); g.lineTo(x + wd, ym + hh * dir); g.stroke(); }
  };
}
// The band's red bell badge, upright.
function badgeJob() {
  const x = 60, ym = 52, r = 30;
  g.save(); g.shadowColor = 'rgba(255,60,30,0.9)'; g.shadowBlur = 16; g.fillStyle = '#c8181e'; ell(x, ym, r * 1.2, r); g.fill(); g.restore();
  g.strokeStyle = '#ffe0a0'; g.lineWidth = 4; ell(x, ym, r * 1.2, r); g.stroke();
  g.fillStyle = '#ffe0a0'; g.beginPath(); g.moveTo(x - r * 0.5, ym + r * 0.45); g.quadraticCurveTo(x - r * 0.45, ym - r * 0.55, x, ym - r * 0.6); g.quadraticCurveTo(x + r * 0.45, ym - r * 0.55, x + r * 0.5, ym + r * 0.45); g.closePath(); g.fill(); ell(x, ym + r * 0.55, r * 0.12, r * 0.1); g.fill();
}
// The rope swipe across the road at the hit line's width (720), arrowhead toward `dir`.
function ropeJob(dir) {
  return () => {
    if (dir < 0) { g.translate(720, 0); g.scale(-1, 1); }
    const y = 55, xa = 40, xb = 650, th = 22;
    g.fillStyle = 'rgba(0,0,0,0.5)'; ell((xa + xb) / 2, y + th * 0.9, (xb - xa) / 2, th * 0.5); g.fill();
    const path = () => { g.beginPath(); g.moveTo(xa, y); g.bezierCurveTo(xa + (xb - xa) * 0.3, y - th * 0.8, xa + (xb - xa) * 0.6, y + th * 0.8, xb - th, y); };
    g.save(); g.shadowColor = 'rgba(255,210,140,0.8)'; g.shadowBlur = 14; g.lineCap = 'round'; g.strokeStyle = '#6b4a22'; g.lineWidth = th + 4; path(); g.stroke(); g.restore();
    g.strokeStyle = '#f0d9a4'; g.lineWidth = th; g.lineCap = 'round'; path(); g.stroke();
    for (let i = 1; i < 26; i++) { const t = i / 26, u = 1 - t; const px = u * u * u * xa + 3 * u * u * t * (xa + (xb - xa) * 0.3) + 3 * u * t * t * (xa + (xb - xa) * 0.6) + t * t * t * (xb - th), py = u * u * u * y + 3 * u * u * t * (y - th * 0.8) + 3 * u * t * t * (y + th * 0.8) + t * t * t * y; g.strokeStyle = '#8a6230'; g.lineWidth = 3; g.beginPath(); g.moveTo(px - th * 0.3, py + th * 0.45); g.lineTo(px + th * 0.3, py - th * 0.45); g.stroke(); }
    g.save(); g.shadowColor = 'rgba(255,230,160,1)'; g.shadowBlur = 16; g.fillStyle = '#fff3cf'; g.beginPath(); g.moveTo(xb + th * 1.6, y); g.lineTo(xb - th * 1.1, y - th * 1.5); g.lineTo(xb - th * 0.6, y); g.lineTo(xb - th * 1.1, y + th * 1.5); g.closePath(); g.fill(); g.restore();
  };
}
// Stand-still hatching, one tile (flat road pixels), repeated over the band.
function hatchJob() { g.strokeStyle = 'rgba(190,205,255,0.8)'; g.lineWidth = 5; for (let k = -2; k < 3; k++) { g.beginPath(); g.moveTo(k * 32 - 4, 36); g.lineTo(k * 32 + 36, -4); g.stroke(); } }

// ---------- step buttons ----------
// A plate per state (the soles are drawn over it by the game), with room around it for the glow:
// lacquered dark (or hot red) with a grain, the Issohadore sash's lozenge band along the top, a bronze
// bevel frame with two studs.
const BTN_W = 220, BTN_H = 176, BTN_M = 30;
function buttonJob(state) {
  return () => {
    const x = BTN_M, y = BTN_M, bw = BTN_W, h = BTN_H, rr = 18;
    const on = state == 'pressed' || state == 'hit', miss = state == 'miss', cued = state == 'cued';
    g.save();
    if (on) { g.shadowColor = state == 'hit' ? 'rgba(255,150,50,1)' : 'rgba(255,90,30,0.95)'; g.shadowBlur = 30; }
    else if (cued) { g.shadowColor = 'rgba(255,150,40,0.7)'; g.shadowBlur = 18; }
    else { g.shadowColor = 'rgba(0,0,0,0.8)'; g.shadowBlur = 12; g.shadowOffsetY = 6; }
    const fill = on ? (state == 'hit' ? [[0, '#ff6a36'], [0.55, '#c01c1a'], [1, '#6a0a10']] : [[0, '#f0402a'], [0.55, '#a8141a'], [1, '#560710']])
      : miss ? [[0, '#1c1a20'], [0.5, '#131117'], [1, '#0b0a0e']] : cued ? [[0, '#3a2838'], [0.5, '#221626'], [1, '#140c18']] : [[0, '#2c1f36'], [0.5, '#1a1224'], [1, '#0f0a16']];
    g.beginPath(); g.roundRect(x, y, bw, h, rr); g.fillStyle = lg(0, y, 0, y + h, fill); g.fill(); g.restore();
    g.save(); g.beginPath(); g.roundRect(x, y, bw, h, rr); g.clip();
    g.fillStyle = lg(0, y, 0, y + h * 0.45, [[0, on ? 'rgba(255,220,170,0.35)' : 'rgba(255,200,160,0.10)'], [1, 'rgba(255,255,255,0)']]); g.fillRect(x, y, bw, h * 0.45);
    const gr = rng(41); for (let k = 0; k < 26; k++) { const yy = y + gr() * h; g.strokeStyle = on ? 'rgba(60,0,0,0.12)' : 'rgba(255,190,140,0.035)'; g.lineWidth = 1 + gr() * 2; g.beginPath(); g.moveTo(x, yy); g.bezierCurveTo(x + bw * 0.3, yy + (gr() - 0.5) * 8, x + bw * 0.7, yy + (gr() - 0.5) * 8, x + bw, yy + (gr() - 0.5) * 6); g.stroke(); }
    g.fillStyle = on ? 'rgba(80,0,8,0.45)' : 'rgba(0,0,0,0.35)'; g.fillRect(x, y + 16, bw, 16);
    lozengeBand(x + 14, y + 18, bw - 28, 12, on ? 'rgba(255,214,140,0.95)' : miss ? 'rgba(120,110,120,0.4)' : cued ? 'rgba(255,190,90,0.8)' : 'rgba(214,150,70,0.55)');
    g.fillStyle = lg(0, y, 0, y + 60, [[0, on ? 'rgba(255,230,160,0.35)' : 'rgba(255,140,60,0.16)'], [1, 'rgba(0,0,0,0)']]); g.fillRect(x, y, bw, 60);
    g.restore();
    const frame = on ? [[0, '#fff0c0'], [0.5, '#ffb04a'], [1, '#b8561a']] : miss ? [[0, '#6a6070'], [1, '#2a2430']] : cued ? [[0, '#ffe0a0'], [0.5, '#e0902a'], [1, '#7a4010']] : [[0, '#e0a050'], [0.5, '#8a5220'], [1, '#4a2810']];
    g.lineWidth = 4; g.strokeStyle = lg(x, y, x, y + h, frame); g.beginPath(); g.roundRect(x + 2, y + 2, bw - 4, h - 4, rr - 1); g.stroke();
    g.lineWidth = 1.2; g.strokeStyle = on ? 'rgba(255,245,210,0.7)' : 'rgba(255,200,130,0.28)'; g.beginPath(); g.roundRect(x + 9, y + 9, bw - 18, h - 18, 12); g.stroke();
    if (!miss) for (const [sx, sy] of [[x + 16, y + h - 16], [x + bw - 16, y + h - 16]]) { g.fillStyle = rg(sx - 1, sy - 1, 0, 5, [[0, on ? '#fff4d0' : '#f0c070'], [0.6, on ? '#e08030' : '#8a5220'], [1, '#2a1406']]); ell(sx, sy, 4.5, 4.5); g.fill(); }
  };
}
// A toeless sole, engraved bone (the game tints it per state); `mirror` for the left foot.
function footJob(mirror) { return () => { g.fillStyle = lg(0, 10, 0, 90, [[0, '#f6e6c6'], [1, '#b89868']]); foot(30, 50, 1.0, mirror); }; }

// ---------- figures ----------
// The files beside the road, each lit from the fire's side: the plain names face right with the fire on
// their right (the left-hand file); the *_r names are baked mirrored, facing left and lit from the left
// (the right-hand file), so the rim always falls on the road side. The Issohadore swings the soha
// overhead and back, away from the road. Drawn FIG_H tall with the mockup's lighting: warm #FF9A4A rim on the fire side, violet fill on
// the far side. No ground shadow: the game draws it, so it stays on the ground in a jump.
const FIG_H = 300, FIG_W = 480, FIG_CH = 480, FIG_AX = 240, FIG_AY = 450;
const FLEECE = { black: {}, dark_brown: { fl0: '#130c08', fl1: '#2c1f17', fl2: '#4a3322' } };
function mamuthoneJob(fleece, jump, side = 1) {
  return () => {
    const keep = Object.assign({}, MC); Object.assign(MC, FLEECE[fleece]); SMALL = true;
    figure(g, o => mamuthone({ view: 'q', step: 0.15, jump, dens: 0.7 }), FIG_AX, FIG_AY, FIG_H,
      Object.assign({ flip: side, light: side, shadow: false, rimW: 0.016, form: true, formA: 0.3, dodgeA: 0.2, key: 0.3 }, FIG));
    SMALL = false; Object.assign(MC, keep);
  };
}
function issohadoreJob(side = 1) { return () => {
  const keep = Object.assign({}, IC);
  Object.assign(IC, { red0: '#5a0610', red1: '#a8101a', red2: '#e8261e', red3: '#ff9a5a', wh0: '#9a8a78', wh1: '#d4c6ac', wh2: '#ede3cf', wh3: '#fff4de', bk1: '#1a1418', bk2: '#3a2e34' });
  SMALL = true;
  figure(g, o => issohadore({ view: 'q', twirl: true }), FIG_AX, FIG_AY, FIG_H,
    Object.assign({ flip: side, light: side, shadow: false, rimW: 0.012, form: true, formA: 0.35, dodgeA: 0.25, key: 0.2, brush: true, brushA: 0.15, lostA: 0.3 }, FIG, { shadowTint: 'rgba(150,130,190,1)' }));
  SMALL = false; Object.assign(IC, keep);
}; }

const JOBS = [
  job('sky', W, SKY_H, 1, 0, TOPY, skyJob),
  job('ground', W, GROUND_Y1 - GROUND_Y0, 1, 0, TOPY - GROUND_Y0, groundJob),
  job('pyre', 400, 80, 2, 200, 48, pyreJob),
  job('setts', SETT_W, SETT_H, 1.5, 0, 0, settsJob),
  job('gem', 256, 250, 2, 128, 62, gemJob(false)),
  job('gem_call', 256, 250, 2, 128, 62, gemJob(true)),
  job('hold_ring', 160, 80, 2, 80, 40, ringJob),
  job('sash', SASH_W, SASH_H, 2, 0, 0, sashJob),
  job('bar_up', 720, 90, 2, 360, 45, barJob(1)),
  job('bar_down', 720, 90, 2, 360, 45, barJob(-1)),
  job('badge', 120, 104, 2, 60, 52, badgeJob),
  job('rope_r', 720, 110, 2, 360, 55, ropeJob(1)),
  job('rope_l', 720, 110, 2, 360, 55, ropeJob(-1)),
  job('hatch', 32, 32, 2, 0, 0, hatchJob),
  ...['idle', 'cued', 'pressed', 'hit', 'miss'].map(st => job('button_' + st, BTN_W + 2 * BTN_M, BTN_H + 2 * BTN_M, 2, BTN_M, BTN_M, buttonJob(st))),
  job('foot_r', 60, 100, 2, 30, 50, footJob(false)),
  job('foot_l', 60, 100, 2, 30, 50, footJob(true)),
  ...[['', 1], ['_r', -1]].flatMap(([suf, side]) => [
    ...['black', 'dark_brown'].flatMap(f => [
      job('mamuthone_' + f + '_a' + suf, FIG_W, FIG_CH, 1, FIG_AX, FIG_AY, mamuthoneJob(f, false, side)),
      job('mamuthone_' + f + '_b' + suf, FIG_W, FIG_CH, 1, FIG_AX, FIG_AY, mamuthoneJob(f, true, side))]),
    job('issohadore' + suf, FIG_W, FIG_CH, 1, FIG_AX, FIG_AY, issohadoreJob(side))]),
];

// Draws one job into a fresh canvas; returns its PNG (data URL) and the bounds of what it drew
// (alpha > 24), in reference pixels relative to its anchor.
function renderJob(name) {
  const j = JOBS.find(q => q.name == name);
  const c = document.createElement('canvas'); c.width = Math.round(j.w * j.s); c.height = Math.round(j.h * j.s);
  g = c.getContext('2d', { willReadFrequently: true }); g.save(); g.scale(j.s, j.s); j.draw(); g.restore();
  const d = g.getImageData(0, 0, c.width, c.height).data; let x0 = c.width, y0 = c.height, x1 = -1, y1 = -1;
  for (let y = 0; y < c.height; y++) for (let x = 0; x < c.width; x++) if (d[(y * c.width + x) * 4 + 3] > 24) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  const b = x1 < 0 ? [0, 0, 0, 0] : [x0 / j.s - j.ax, y0 / j.s - j.ay, (x1 + 1) / j.s - j.ax, (y1 + 1) / j.s - j.ay];
  return { url: c.toDataURL('image/png'), bounds: b.map(v => Math.round(v * 10) / 10) };
}
function manifest() { return { fig_h: FIG_H, sprites: JOBS.map(j => ({ name: j.name, w: j.w, h: j.h, s: j.s, ax: j.ax, ay: j.ay })) }; }
