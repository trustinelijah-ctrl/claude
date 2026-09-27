// Renders each phone mockup in index.html to screens/<id>.png. Usage: node render.cjs "$PWD"
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
(async () => {
  const out = process.argv[2];
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1320, height: 1000 }, deviceScaleFactor: 2 });
  await page.goto('file://' + out + '/index.html', { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  for (const id of ['today','session','plan','journal','map','chords','welcome','justplay']) {
    await page.locator('#' + id).screenshot({ path: `${out}/screens/${id}.png`, omitBackground: true });
  }
  await page.setViewportSize({ width: 1320, height: 1000 });
  await page.screenshot({ path: `${out}/screens/overview.png`, fullPage: true });
  await browser.close();
})();
