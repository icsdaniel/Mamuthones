// Fire Night sprites for the play screen, cut from the approved mockup's own drawing code (mock.js,
// figs.js). Each job draws into its own canvas at `s` times its size in reference pixels (the
// mockup's 720x1440 frame); render.js saves them to game/art/fire/ and writes the anchors the game
// needs to fire_sprites.json. The moving parts (flames, sparks, beads, bursts) are drawn by the game.

function job(name, w, h, s, draw, extra) { return Object.assign({ name, w, h, s, draw }, extra || {}); }

// ---------- background ----------
// Sky, stars, smoke and the village skyline down to just below the road's far end (TOPY).
const SKY_H = 260;
function skyJob() { sky(); skyline(); hudShade(); }
// A dark band behind the right of the HUD, so the unison meter reads over the fire's glow.
function hudShade() { g.fillStyle = rg(560, 50, 0, 220, [[0, 'rgba(4,3,12,0.55)'], [1, 'rgba(4,3,12,0)']]); g.fillRect(340, 0, 380, 150); }
// The square: fire-warmed cobbles, the crowd at its edge, darkening toward the player. Starts GROUND_Y0
// above the far end so the crowd's heads fit; ends at the buttons.
const GROUND_Y0 = 150, GROUND_Y1 = BTN_Y;
function groundJob() {
  g.translate(0, -GROUND_Y0);
  ground(false);
  g.fillStyle = '#07060c'; g.fillRect(0, HITY, W, GROUND_Y1 - HITY);
  // the mockup's vignette, only on the ground
  g.globalCompositeOperation = 'source-atop';
  g.fillStyle = rg(360, 640, 300, 900, [[0, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,0,0.55)']]); g.fillRect(0, GROUND_Y0, W, GROUND_Y1);
  g.globalCompositeOperation = 'source-over';
}
// The pyre: heaped logs silhouetted at the fire's base, rims glowing (the flames are a shader).
function pyreJob() {
  g.translate(-160, -150); const bx = 360, by = 200; const r = rng(21);
  for (let i = 0; i < 12; i++) { const t = r(), lx = bx + (r() - 0.5) * 260 * (1 - t * 0.4), ly = by - 2 - t * 12, len = 40 + r() * 50, a = (r() - 0.5) * 0.7; g.save(); g.translate(lx, ly); g.rotate(a); g.fillStyle = '#1a0c08'; g.fillRect(-len / 2, -4, len, 8); g.fillStyle = `rgba(255,${130 + r() * 90},50,${0.55 + r() * 0.4})`; g.fillRect(-len / 2, -5, len, 2); g.restore(); }
}

// ---------- notes ----------
// gem(): the step, at its size on the hit line of the mockup (a 240 px lane). Centre at GEM_C.
const GEM_C = [128, 62];
function gemJob() { gem(GEM_C[0], GEM_C[1], 1); }
// The off-beat step (the Issohadore's call): the same gem with a hot ember face and a dark lozenge.
function gemCallJob() {
  const x = GEM_C[0], y = GEM_C[1], sc = 1; gem(x, y, sc);
  const rx = 0.3 * 240 * sc, ry = rx * 0.38;
  g.fillStyle = rg(x - rx * 0.15, y - ry * 0.35, 0, rx * 0.8, [[0, '#fff4d0'], [0.35, '#ffb040'], [0.8, '#e0421f'], [1, '#a0101a']]); ell(x, y - ry * 0.05, rx * 0.78, ry * 0.72); g.fill();
  g.strokeStyle = 'rgba(90,10,10,0.9)'; g.lineWidth = 2; ell(x, y - ry * 0.05, rx * 0.78, ry * 0.72); g.stroke();
  const d = ry * 0.5; g.beginPath(); g.moveTo(x, y - d - 1); g.lineTo(x + d * 2.2, y - 1); g.lineTo(x, y + d - 1); g.lineTo(x - d * 2.2, y - 1); g.closePath();
  g.fillStyle = '#3a0508'; g.fill(); g.strokeStyle = '#ffd27a'; g.lineWidth = 2; g.stroke();
  g.fillStyle = 'rgba(255,255,255,0.95)'; ell(x - rx * 0.4, y - ry * 0.34, rx * 0.12, ry * 0.11); g.fill();
}
// End of a hold: the hollow gold ring.
const RING_C = [80, 40];
function ringJob() { const x = RING_C[0], y = RING_C[1], rx = 0.24 * 240, ry = rx * 0.38; g.save(); g.shadowColor = 'rgba(255,200,90,0.9)'; g.shadowBlur = 14; g.strokeStyle = '#ffd27a'; g.lineWidth = 8; ell(x, y, rx, ry); g.stroke(); g.restore(); g.strokeStyle = 'rgba(255,250,225,0.9)'; g.lineWidth = 2; g.beginPath(); g.ellipse(x, y, rx, ry, 0, Math.PI * 1.1, Math.PI * 1.9); g.stroke(); }
// The woven sash of a hold, one repeat, in flat road pixels (a 240 px lane, 0.34 of it wide): red
// weave, a gold lozenge down the middle. Tiled down the hold's length in the game.
const SASH_W = 82, SASH_H = 64;
function sashJob() {
  g.fillStyle = lg(0, 0, SASH_W, 0, [[0, '#8a0d14'], [0.35, '#d01d1f'], [0.65, '#d8201f'], [1, '#8a0d14']]); g.fillRect(0, 0, SASH_W, SASH_H);
  for (let y = 0; y < SASH_H; y += 8) { g.fillStyle = 'rgba(60,0,8,0.32)'; g.fillRect(0, y, SASH_W, 3); }
  for (let x = 4; x < SASH_W; x += 10) { g.fillStyle = 'rgba(255,120,90,0.08)'; g.fillRect(x, 0, 2, SASH_H); }
  const cx = SASH_W / 2, cy = SASH_H / 2, hw = 21, hh = 17;
  g.beginPath(); g.moveTo(cx, cy - hh); g.lineTo(cx + hw, cy); g.lineTo(cx, cy + hh); g.lineTo(cx - hw, cy); g.closePath();
  g.fillStyle = lg(0, cy - hh, 0, cy + hh, [[0, '#ffe7a0'], [0.5, '#ffc84a'], [1, '#d88a20']]); g.fill(); g.strokeStyle = '#5a0710'; g.lineWidth = 2; g.stroke();
}
// The bell bar in flat road pixels (720 wide, BAR_H 46 tall, centred at 45): bronze to gold, dark
// chevrons pointing the swing, a gap in the middle for the badge (drawn upright by the game).
const BAR_CELL = [720, 90, 45], BAR_T = 46;
function barJob(dir) {
  return () => {
    const y0 = BAR_CELL[2] - BAR_T / 2, y1 = BAR_CELL[2] + BAR_T / 2, ym = BAR_CELL[2];
    g.fillStyle = 'rgba(0,0,0,0.5)'; g.fillRect(0, y0 + 10, 720, BAR_T + 14);
    g.save(); g.shadowColor = 'rgba(255,170,60,0.8)'; g.shadowBlur = 16; g.fillStyle = '#5a3208'; g.fillRect(2, y0 + 6, 716, BAR_T); g.restore();
    g.fillStyle = lg(0, y0, 0, y1, [[0, '#fff1c0'], [0.35, '#f2b64a'], [1, '#b0681c']]); g.fillRect(2, y0, 716, BAR_T);
    g.strokeStyle = '#2a1204'; g.lineWidth = 3; g.strokeRect(2, y0, 716, BAR_T);
    g.fillStyle = 'rgba(255,255,240,0.7)'; g.fillRect(4, y0 + 3, 712, 3);
    const n = 6, hh = BAR_T * 0.3;
    for (let i = 0; i < n; i++) { const u = -0.86 + i * (1.72 / (n - 1)); if (Math.abs(u) < 0.2) continue; const x = 360 + u * 360, wd = hh * 1.8;
      g.strokeStyle = '#3a1604'; g.lineWidth = 6; g.lineJoin = 'round'; g.lineCap = 'round'; g.beginPath(); g.moveTo(x - wd, ym + hh * dir); g.lineTo(x, ym - hh * dir); g.lineTo(x + wd, ym + hh * dir); g.stroke(); }
  };
}
// The bar's red bell badge, upright on screen.
const BADGE_C = [60, 52], BADGE_R = 30;
function badgeJob() {
  const x = BADGE_C[0], ym = BADGE_C[1], r = BADGE_R;
  g.save(); g.shadowColor = 'rgba(255,60,30,0.9)'; g.shadowBlur = 16; g.fillStyle = '#c8181e'; ell(x, ym, r * 1.2, r); g.fill(); g.restore();
  g.fillStyle = rg(x - r * 0.3, ym - r * 0.4, 0, r * 1.3, [[0, 'rgba(255,140,110,0.6)'], [1, 'rgba(0,0,0,0)']]); ell(x, ym, r * 1.2, r); g.fill();
  g.strokeStyle = '#ffe0a0'; g.lineWidth = 4; ell(x, ym, r * 1.2, r); g.stroke();
  g.fillStyle = '#ffe0a0'; g.beginPath(); g.moveTo(x - r * 0.5, ym + r * 0.45); g.quadraticCurveTo(x - r * 0.45, ym - r * 0.55, x, ym - r * 0.6); g.quadraticCurveTo(x + r * 0.45, ym - r * 0.55, x + r * 0.5, ym + r * 0.45); g.closePath(); g.fill(); ell(x, ym + r * 0.55, r * 0.12, r * 0.1); g.fill();
}
// The rope swipe across the road at the hit line's width (720), arrowhead toward `dir`.
const ROPE_CELL = [720, 110, 55];
function ropeJob(dir) {
  return () => {
    if (dir < 0) { g.translate(720, 0); g.scale(-1, 1); }
    const y = ROPE_CELL[2], xa = 40, xb = 650, th = 22;
    g.fillStyle = 'rgba(0,0,0,0.5)'; ell((xa + xb) / 2, y + th * 0.9, (xb - xa) / 2, th * 0.5); g.fill();
    const path = () => { g.beginPath(); g.moveTo(xa, y); g.bezierCurveTo(xa + (xb - xa) * 0.3, y - th * 0.8, xa + (xb - xa) * 0.6, y + th * 0.8, xb - th, y); };
    g.save(); g.shadowColor = 'rgba(255,210,140,0.8)'; g.shadowBlur = 14; g.lineCap = 'round'; g.strokeStyle = '#6b4a22'; g.lineWidth = th + 4; path(); g.stroke(); g.restore();
    g.strokeStyle = '#f0d9a4'; g.lineWidth = th; g.lineCap = 'round'; path(); g.stroke();
    for (let i = 1; i < 26; i++) { const t = i / 26, u = 1 - t; const px = u * u * u * xa + 3 * u * u * t * (xa + (xb - xa) * 0.3) + 3 * u * t * t * (xa + (xb - xa) * 0.6) + t * t * t * (xb - th), py = u * u * u * y + 3 * u * u * t * (y - th * 0.8) + 3 * u * t * t * (y + th * 0.8) + t * t * t * y; g.strokeStyle = '#8a6230'; g.lineWidth = 3; g.beginPath(); g.moveTo(px - th * 0.3, py + th * 0.45); g.lineTo(px + th * 0.3, py - th * 0.45); g.stroke(); }
    g.save(); g.shadowColor = 'rgba(255,230,160,1)'; g.shadowBlur = 16; g.fillStyle = '#fff3cf'; g.beginPath(); g.moveTo(xb + th * 1.6, y); g.lineTo(xb - th * 1.1, y - th * 1.5); g.lineTo(xb - th * 0.6, y); g.lineTo(xb - th * 1.1, y + th * 1.5); g.closePath(); g.fill(); g.restore();
    g.strokeStyle = '#6b4a22'; g.lineWidth = 2; g.beginPath(); g.moveTo(xb + th * 1.6, y); g.lineTo(xb - th * 1.1, y - th * 1.5); g.lineTo(xb - th * 0.6, y); g.lineTo(xb - th * 1.1, y + th * 1.5); g.closePath(); g.stroke();
  };
}
// Stand-still hatching, one tile (flat road pixels), repeated over the band.
function hatchJob() { g.strokeStyle = 'rgba(190,205,255,0.8)'; g.lineWidth = 5; for (let k = -2; k < 3; k++) { g.beginPath(); g.moveTo(k * 32 - 4, 36); g.lineTo(k * 32 + 36, -4); g.stroke(); } }

// ---------- step buttons ----------
// A panel per state (the glyph is drawn over it by the game), with room around it for the glow.
const BTN = [220, 176], BTN_M = 26;
function buttonJob(state) {
  return () => {
    const x = BTN_M, y = BTN_M, bw = BTN[0], h = BTN[1], rr = 18;
    const hot = state == 'pressed' || state == 'hit';
    const fills = { idle: ['#241a30', '#120d1c'], cued: ['#342236', '#1a1020'], pressed: ['#e0321f', '#6a0a10'], hit: ['#ff5a26', '#9a1410'], miss: ['#1a1719', '#0d0b0e'] };
    const rims = { idle: '#b8782a', cued: '#ffc84a', pressed: '#ffe0a0', hit: '#fff0c0', miss: '#5a5058' };
    const inner = { idle: 'rgba(255,180,90,0.25)', cued: 'rgba(255,200,110,0.5)', pressed: 'rgba(255,240,200,0.6)', hit: 'rgba(255,250,220,0.75)', miss: 'rgba(160,150,160,0.2)' };
    const glow = { cued: ['rgba(255,150,40,0.7)', 18], pressed: ['rgba(255,90,30,0.9)', 26], hit: ['rgba(255,150,50,1)', 26] }[state];
    g.save(); if (glow) { g.shadowColor = glow[0]; g.shadowBlur = glow[1]; }
    g.beginPath(); g.roundRect(x, y, bw, h, rr); g.fillStyle = lg(0, y, 0, y + h, [[0, fills[state][0]], [1, fills[state][1]]]); g.fill(); g.restore();
    // a soft sheen across the top and a darker lip at the bottom: a chunky, raised panel
    g.save(); g.beginPath(); g.roundRect(x, y, bw, h, rr); g.clip();
    g.fillStyle = lg(0, y, 0, y + h * 0.5, [[0, hot ? 'rgba(255,220,180,0.28)' : 'rgba(255,220,180,0.07)'], [1, 'rgba(255,220,180,0)']]); g.fillRect(x, y, bw, h * 0.5);
    g.fillStyle = 'rgba(0,0,0,0.3)'; g.fillRect(x, y + h - 10, bw, 10); g.restore();
    g.lineWidth = 3.5; g.strokeStyle = rims[state]; g.beginPath(); g.roundRect(x + 1.5, y + 1.5, bw - 3, h - 3, rr); g.stroke();
    g.lineWidth = 1.5; g.strokeStyle = inner[state]; g.beginPath(); g.roundRect(x + 9, y + 9, bw - 18, h - 18, 12); g.stroke();
    // bronze corner studs
    if (state != 'miss') for (const [cx, cy] of [[x + 16, y + 16], [x + bw - 16, y + 16], [x + 16, y + h - 16], [x + bw - 16, y + h - 16]]) { g.fillStyle = hot ? '#ffe0a0' : '#b8782a'; ell(cx, cy, 2.5, 2.5); g.fill(); }
  };
}
// Footprints, white (tinted by the game): a right foot and its mirror.
const FOOT_C = [30, 50];
function footJob(mirror) { return () => { g.fillStyle = '#ffffff'; foot(FOOT_C[0], FOOT_C[1], 1.0, mirror); }; }

// ---------- figures ----------
// The files beside the road, facing right (the game mirrors the right-hand file). Feet at FIG_A in a
// FIG cell, drawn FIG_H tall. No shadow: the game draws it, so it stays on the ground in a jump.
const FIG_H = 180, FIG = [234, 261], FIG_A = [119, 252];
const FLEECE = { black: ['#0d0a0c', 0], dark_brown: ['#22160f', 1] };
function mamuthoneFig(x, y, s, up, seed, fleece) {
  const f = 1; const X = u => x + u * s * f, Y = v => y + v * s; const brown = FLEECE[fleece][1];
  const P = (pts) => { g.beginPath(); pts.forEach(([u, v], i) => i ? g.lineTo(X(u), Y(v)) : g.moveTo(X(u), Y(v))); g.closePath(); };
  g.fillStyle = '#0b080a'; P([[-0.13, -0.32], [-0.03, -0.32], [-0.04, -0.05], [-0.12, -0.05]]); g.fill();
  P([[0.02, -0.32], [0.12, -0.32], up ? [0.16, -0.14] : [0.11, -0.05], up ? [0.08, -0.12] : [0.03, -0.05]]); g.fill();
  g.fillStyle = '#4a2c16'; P([[-0.15, -0.07], [-0.02, -0.07], [0.0, 0], [-0.16, 0]]); g.fill(); P(up ? [[0.06, -0.15], [0.18, -0.16], [0.22, -0.1], [0.08, -0.09]] : [[0.02, -0.07], [0.13, -0.07], [0.17, 0], [0.01, 0]]); g.fill();
  const r = rng(seed); const pts = []; const N = 34;
  for (let i = 0; i < N; i++) { const a = i / N * Math.PI * 2; let ru = 0.29, rv = 0.3; const cu = 0.0, cv = -0.56; let u = cu + Math.cos(a) * ru * (1 + 0.05 * Math.sin(a * 3)), v = cv + Math.sin(a) * rv; if (v < -0.72) u += 0.05; const sp = (i % 2) ? 0.05 + r() * 0.04 : 0; pts.push([u + Math.cos(a) * sp, v + Math.sin(a) * sp]); }
  P(pts); g.fillStyle = FLEECE[fleece][0]; g.fill();
  g.save(); P(pts); g.clip();
  g.globalCompositeOperation = 'lighter'; g.fillStyle = lg(X(0.34), Y(-0.9), X(0.0), Y(-0.5), [[0, 'rgba(255,150,60,0.85)'], [0.5, 'rgba(200,70,30,0.25)'], [1, 'rgba(0,0,0,0)']]); g.fillRect(x - s, y - 1.2 * s, 2 * s, 1.2 * s);
  // the cool rim of the night on the far side
  g.fillStyle = lg(X(-0.34), 0, X(-0.12), 0, [[0, 'rgba(120,130,255,0.35)'], [1, 'rgba(0,0,0,0)']]); g.fillRect(x - s, y - 1.2 * s, 2 * s, 1.2 * s); g.globalCompositeOperation = 'source-over';
  for (let i = 0; i < 70; i++) { const u = -0.28 + r() * 0.56, v = -0.84 + r() * 0.56; const tx = X(u), ty = Y(v); const warm = (u * 1 + 0.3) / 0.6; g.strokeStyle = `rgba(${60 + warm * 150 + brown * 20},${40 + warm * 70 + brown * 10},${40 + warm * 20 - brown * 10},${0.35 + r() * 0.3})`; g.lineWidth = Math.max(1, s * 0.014); g.beginPath(); g.moveTo(tx, ty); g.quadraticCurveTo(tx + 0.02 * s * f, ty + 0.03 * s, tx + (r() - 0.3) * 0.04 * s * f, ty + 0.07 * s); g.stroke(); }
  g.restore();
  const phase = up ? 1.2 : 4.0;
  const bl = [[-0.3, -0.74], [-0.36, -0.62], [-0.33, -0.5], [-0.26, -0.4], [-0.22, -0.66], [-0.25, -0.54], [-0.18, -0.46], [-0.16, -0.76]];
  bl.forEach(([u, v], i) => { const bx = X(u), by = Y(v) + Math.sin(phase + i * 0.9) * 0.012 * s, rb = 0.065 * s;
    g.fillStyle = '#1a0c04'; ell(bx, by + rb * 0.1, rb * 1.08, rb * 1.02); g.fill();
    g.fillStyle = rg(bx + rb * 0.35 * f, by - rb * 0.35, 0, rb * 1.2, [[0, '#fff0b8'], [0.3, '#e3a23c'], [0.75, '#8a4e16'], [1, '#2a1406']]); ell(bx, by, rb, rb * 0.95); g.fill();
    g.fillStyle = '#120804'; ell(bx, by + rb * 0.6, rb * 0.55, rb * 0.2); g.fill(); });
  g.strokeStyle = 'rgba(255,220,150,0.55)'; g.lineWidth = Math.max(1, 0.015 * s); for (const k of [0, 1]) { g.beginPath(); g.arc(X(-0.42 - k * 0.06), Y(-0.58), 0.08 * s + k * 0.05 * s, Math.PI * 0.7, Math.PI * 1.3); g.stroke(); }
  g.fillStyle = '#0a0709'; P([[-0.05, -0.76], [-0.04, -1.02], [0.08, -1.12], [0.22, -1.08], [0.28, -0.9], [0.2, -0.72]]); g.fill();
  const MP = [[0.08, -1.02], [0.24, -1.03], [0.31, -0.94], [0.31, -0.82], [0.24, -0.72], [0.13, -0.74], [0.08, -0.86]];
  g.fillStyle = lg(X(0.06), 0, X(0.32), 0, [[0, '#1c0d06'], [0.5, '#6a3618'], [1, '#e08a48']]); P(MP); g.fill();
  g.strokeStyle = '#080403'; g.lineWidth = Math.max(1, 0.012 * s); P(MP); g.stroke();
  g.fillStyle = '#070302'; ell(X(0.15), Y(-0.92), 0.03 * s, 0.02 * s); g.fill(); ell(X(0.25), Y(-0.92), 0.026 * s, 0.019 * s); g.fill();
  g.strokeStyle = '#ffc58a'; g.lineWidth = Math.max(1, 0.016 * s); g.beginPath(); g.moveTo(X(0.1), Y(-0.96)); g.quadraticCurveTo(X(0.2), Y(-0.99), X(0.3), Y(-0.955)); g.stroke();
  g.fillStyle = '#ffb877'; P([[0.2, -0.93], [0.34, -0.82], [0.23, -0.82]]); g.fill();
  g.strokeStyle = '#070302'; g.lineWidth = Math.max(1, 0.014 * s); g.beginPath(); g.moveTo(X(0.14), Y(-0.78)); g.lineTo(X(0.26), Y(-0.77)); g.stroke();
  // cool night rim on the hood's far edge
  g.strokeStyle = 'rgba(140,150,255,0.45)'; g.lineWidth = Math.max(1, 0.012 * s); g.beginPath(); g.moveTo(X(-0.05), Y(-0.78)); g.lineTo(X(-0.04), Y(-1.02)); g.lineTo(X(0.08), Y(-1.12)); g.stroke();
}
function mamuthoneJob(fleece, up) { return () => mamuthoneFig(FIG_A[0], FIG_A[1], FIG_H, up, 37, fleece); }
function issohadoreJob() {
  // issohadore() from figs.js draws its own shadow first; paint it on a scratch canvas and drop the
  // shadow by clearing the ground strip under the feet before the legs are drawn.
  const x = FIG_A[0], y = FIG_A[1], s = FIG_H;
  const save = g.fill.bind(g); let first = true;
  g.fill = function () { if (first) { first = false; return; } return save.apply(g, arguments); };
  issohadore(x, y, s, 1, 90);
  g.fill = save;
  // cool night rim on the back
  g.globalCompositeOperation = 'source-atop'; g.fillStyle = lg(x - 0.25 * s, 0, x - 0.08 * s, 0, [[0, 'rgba(120,130,255,0.35)'], [1, 'rgba(0,0,0,0)']]); g.fillRect(x - 0.4 * s, y - 1.5 * s, 0.4 * s, 1.5 * s); g.globalCompositeOperation = 'source-over';
}

const JOBS = [
  job('sky', W, SKY_H, 1, skyJob),
  job('ground', W, GROUND_Y1 - GROUND_Y0, 1, groundJob),
  job('pyre', 400, 80, 2, pyreJob),
  job('gem', 256, 140, 2, gemJob),
  job('gem_call', 256, 140, 2, gemCallJob),
  job('hold_ring', 160, 80, 2, ringJob),
  job('sash', SASH_W, SASH_H, 2, sashJob),
  job('bar_up', BAR_CELL[0], BAR_CELL[1], 2, barJob(1)),
  job('bar_down', BAR_CELL[0], BAR_CELL[1], 2, barJob(-1)),
  job('badge', 120, 104, 2, badgeJob),
  job('rope_r', ROPE_CELL[0], ROPE_CELL[1], 2, ropeJob(1)),
  job('rope_l', ROPE_CELL[0], ROPE_CELL[1], 2, ropeJob(-1)),
  job('hatch', 32, 32, 2, hatchJob),
  ...['idle', 'cued', 'pressed', 'hit', 'miss'].map(st => job('button_' + st, BTN[0] + 2 * BTN_M, BTN[1] + 2 * BTN_M, 2, buttonJob(st))),
  job('foot_r', 60, 100, 2, footJob(false)),
  job('foot_l', 60, 100, 2, footJob(true)),
  job('mamuthone_black_a', FIG[0], FIG[1], 1.5, mamuthoneJob('black', false)),
  job('mamuthone_black_b', FIG[0], FIG[1], 1.5, mamuthoneJob('black', true)),
  job('mamuthone_dark_brown_a', FIG[0], FIG[1], 1.5, mamuthoneJob('dark_brown', false)),
  job('mamuthone_dark_brown_b', FIG[0], FIG[1], 1.5, mamuthoneJob('dark_brown', true)),
  job('issohadore', FIG[0], FIG[1], 1.5, issohadoreJob),
];

// Draws one job into a fresh canvas and returns its PNG as a data URL.
function renderJob(name) {
  const j = JOBS.find(q => q.name == name);
  const c = document.createElement('canvas'); c.width = Math.round(j.w * j.s); c.height = Math.round(j.h * j.s);
  g = c.getContext('2d'); g.scale(j.s, j.s); j.draw(); return c.toDataURL('image/png');
}
function manifest() {
  return { ref_w: W, topy: TOPY, hity: HITY, sky_h: SKY_H, ground_y0: GROUND_Y0, gem_c: GEM_C, ring_c: RING_C, sash: [SASH_W, SASH_H], bar_cell: BAR_CELL, bar_t: BAR_T,
    badge_c: BADGE_C, badge_r: BADGE_R, rope_cell: ROPE_CELL, btn: BTN, btn_m: BTN_M, foot_c: FOOT_C, fig_h: FIG_H, fig: FIG, fig_a: FIG_A,
    sprites: JOBS.map(j => ({ name: j.name, w: j.w, h: j.h, s: j.s })) };
}
