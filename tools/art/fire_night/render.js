// Renders every Fire Night sprite of the play screen into game/art/fire/ from one place:
//   node tools/art/fire_night/render.js [out_dir]      (needs Playwright's Chromium, as a global npm module)
// To swap in new art, change the drawing in mock.js / figs.js / sprites.js (the JOBS list names every
// sprite, its cell size and scale) and re-run this; then `godot --headless --path game --import`.
// Cell sizes and anchors are written to fire_sprites.json next to this script; FireSkin's constants
// (game/scripts/art/fire_skin.gd) must match it if a cell changes. mock.html draws the mockup itself.
const path = require('path'), fs = require('fs');
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
(async () => {
  const out = process.argv[2] || path.resolve(__dirname, '../../../game/art/fire');
  fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto('file://' + path.resolve(__dirname, 'sprites.html'));
  const man = await p.evaluate(() => manifest());
  for (const s of man.sprites) {
    const url = await p.evaluate(n => renderJob(n), s.name);
    fs.writeFileSync(path.join(out, s.name + '.png'), Buffer.from(url.split(',')[1], 'base64'));
  }
  fs.writeFileSync(path.join(__dirname, 'fire_sprites.json'), JSON.stringify(man, null, 1) + '\n');
  console.log('rendered', man.sprites.length, 'sprites to', out);
  await b.close();
})();
