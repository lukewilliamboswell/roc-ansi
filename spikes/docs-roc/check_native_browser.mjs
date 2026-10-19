// Adapted from roc-automation dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e
// Optional real-browser acceptance audit. Uses Node and an installed Chrome only
// on the test host; the documentation utility has no browser or Node dependency.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';

const site = path.resolve(process.argv[2]);
const screenshots = process.argv[3];
const chrome = process.env.CHROME || (process.platform === 'darwin'
  ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'google-chrome');
const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'roc-docs-browser-'));
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const mime = { '.html': 'text/html', '.svg': 'image/svg+xml', '.png': 'image/png', '.pdf': 'application/pdf', '.ttf':'font/ttf' };
const server = http.createServer(async (req, res) => {
  try {
    const file = path.resolve(site, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname));
    if (!file.startsWith(site + path.sep)) throw new Error('Outside site');
    const data = await fs.readFile(file);
    res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream' }); res.end(data);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/`;
const child = spawn(chrome, ['--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  `--user-data-dir=${profile}`, '--remote-debugging-port=0', 'about:blank'], { stdio: 'ignore' });
let browserError;
child.on('error', error => { browserError = error; });
let ws;
try {
  let port;
  for (let n = 0; n < 100; n++) {
    if (browserError) throw browserError;
    try { port = (await fs.readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; }
    catch { await pause(100); }
  }
  assert.ok(port, 'Chrome did not expose a debugging port');
  const target = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json();
  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.addEventListener('open', resolve, { once: true }); ws.addEventListener('error', reject, { once: true }); });
  let serial = 0;
  const pending = new Map();
  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (!message.id) return;
    const request = pending.get(message.id); pending.delete(message.id);
    if (!request) return;
    clearTimeout(request.timeout);
    if (message.error) request.reject(message.error); else request.resolve(message.result);
  });
  const cdp = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++serial;
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error(`Browser timed out: ${method}`)); }, 10000);
    pending.set(id, { resolve, reject, timeout }); ws.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const response = await cdp('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (response.exceptionDetails) throw new Error(JSON.stringify(response.exceptionDetails));
    return response.result.value;
  };
  await cdp('Page.enable');
  await cdp('Page.bringToFront');
  await cdp('Emulation.setFocusEmulationEnabled', {enabled:true});
  await cdp('Emulation.setDeviceMetricsOverride', { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false });
  const pages = (await fs.readdir(site)).filter(name => name.endsWith('.html'));
  const inventory = {};
  for (const page of pages) {
    const url = base + page;
    await cdp('Page.navigate', { url });
    let ready = false;
    for (let n = 0; n < 100; n++) {
      await pause(50);
      ready = await evaluate(`location.href === ${JSON.stringify(url)} && document.readyState === 'complete'`);
      if (ready) break;
    }
    assert.ok(ready, `${page}: page did not finish loading`);
    await evaluate('document.fonts.ready.then(() => true)');
    const state = await evaluate(`({
      ids: [...document.querySelectorAll('[id]')].map(e => e.id),
      links: [...document.querySelectorAll('a[href]')].map(e => e.getAttribute('href')),
      images: [...document.querySelectorAll('img')].map(e => ({src:e.currentSrc,loaded:e.complete && e.naturalWidth > 0})),
      snippets: [...document.querySelectorAll('code[data-lang]')].map(e => ({lang:e.dataset.lang,coloured:!!e.querySelector('.syntax-name,.syntax-string,.syntax-keyword,.syntax-number,.syntax-comment')})),
      nav: document.querySelector('.toc') ? getComputedStyle(document.querySelector('.toc')).position : null,
      nested: document.querySelectorAll('.toc ul ul').length,
      mainY: document.querySelector('main').getBoundingClientRect().top,
      captions: [...document.querySelectorAll('figcaption')].map(e=>e.innerText),
      sidebars: document.querySelectorAll('aside.sidebar dl').length,
      overflow: document.documentElement.scrollWidth > innerWidth
    })`);
    assert.equal(state.ids.length, new Set(state.ids).size, `${page}: duplicate IDs`);
    assert.ok(state.images.every(image => image.loaded), `${page}: missing image`);
    assert.ok(!state.overflow, `${page}: desktop horizontal overflow`);
    assert.ok(state.mainY < 600, `${page}: content displaced by contents list`);
    if (state.nav) assert.equal(state.nav, 'fixed', `${page}: desktop navigation is not persistent`);
    for (const snippet of state.snippets) {
      if (['yaml','yml','sh','bash','json','diff'].includes(snippet.lang)) assert.ok(snippet.coloured, `${page}: missing ${snippet.lang} colours`);
    }
    inventory[page] = state;
  }
  for (const [page, state] of Object.entries(inventory)) {
    for (const href of state.links) {
      const url = new URL(href, base + page);
      if (url.origin !== new URL(base).origin || !url.hash) continue;
      const targetPage = inventory[url.pathname.slice(1)];
      if (targetPage) assert.ok(targetPage.ids.includes(decodeURIComponent(url.hash.slice(1))), `${page}: broken link ${href}`);
    }
  }
  await cdp('Page.navigate', { url: base + 'index.html' }); await pause(250);
  const index = inventory['index.html'];
  assert.ok(index.nested > 0, 'Manual TOC has no hierarchy');
  assert.ok(index.ids.includes('get-started') && index.ids.includes('maintain-and-release'), 'Legacy anchors missing');
  assert.equal(index.images.filter(image => image.src.endsWith('.png')).length, 5, 'Manual must retain five screenshots');
  assert.equal(await evaluate(`['Space Grotesk','Plus Jakarta Sans'].every(name => [...document.fonts].some(face => face.family.includes(name) && face.status === 'loaded'))`), true, 'Vendored reading fonts not loaded');
  assert.ok(index.sidebars > 0, 'Introduction lost its sidebar/description list');
  assert.equal(await evaluate(`document.querySelector('main h2 .section-number')?.innerText.trim()`), '1.', 'Body heading numbering missing');
  await evaluate(`document.querySelector('main h2 .anchor').focus()`);
  assert.equal(await evaluate(`document.activeElement === document.querySelector('main h2 .anchor')`), true, 'Permalink must receive keyboard focus');
  assert.equal(await evaluate(`getComputedStyle(document.querySelector('main h2 .anchor')).opacity`), '1', 'Keyboard-focused permalink must be visible');
  await evaluate('scrollTo({top:0,behavior:"instant"})');
  const proportions = await evaluate(`(()=>{const cells=[...document.querySelector('main table').querySelectorAll('th')];return cells[0].getBoundingClientRect().width/cells[1].getBoundingClientRect().width})()`);
  assert.ok(Math.abs(proportions - 1/3) < .02, 'Authored 1:3 column weights not respected');
  if (screenshots) {
    await fs.mkdir(screenshots, { recursive: true });
    await fs.writeFile(path.join(screenshots, 'desktop.png'), Buffer.from((await cdp('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
  }
  await cdp('Emulation.setEmulatedMedia', {features:[{name:'prefers-color-scheme',value:'dark'}]});
  assert.equal(await evaluate('getComputedStyle(document.body).backgroundColor'), 'rgb(22, 24, 26)', 'Dark background missing');
  assert.equal(await evaluate('getComputedStyle(document.body).color'), 'rgb(236, 236, 234)', 'Dark text colour missing');
  if (screenshots) await fs.writeFile(path.join(screenshots,'dark.png'), Buffer.from((await cdp('Page.captureScreenshot',{format:'png'})).data,'base64'));
  await cdp('Emulation.setEmulatedMedia', {features:[{name:'prefers-color-scheme',value:'light'}]});
  await cdp('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await evaluate('scrollTo({top:0,behavior:"instant"})'); await pause(100);
  const mobile = await evaluate(`({width:innerWidth,documentWidth:document.documentElement.scrollWidth,open:document.querySelector('.toc details').open,mainY:document.querySelector('main').getBoundingClientRect().top,titleY:document.querySelector('header h1').getBoundingClientRect().top})`);
  assert.equal(mobile.width, 390, 'Mobile viewport expands beyond device width');
  assert.ok(mobile.documentWidth <= 390, 'Mobile page overflows horizontally');
  assert.equal(mobile.open, false, 'Mobile TOC should start collapsed');
  assert.ok(mobile.mainY < 600 && mobile.titleY < 100, 'Title and introduction must be visible on mobile');
  await evaluate(`document.querySelector('.toc summary').click()`);
  assert.equal(await evaluate(`document.querySelector('.toc details').open`), true, 'Mobile TOC must expand');
  assert.equal(await evaluate(`getComputedStyle(document.querySelector('.toc ul')).columnCount`), 'auto', 'Mobile TOC must use one column');
  await evaluate(`document.querySelector('.toc a').click()`); await pause(100);
  assert.equal(await evaluate(`document.querySelector('.toc details').open`), false, 'Choosing a mobile destination closes TOC');
  if (screenshots) {
    await evaluate('scrollTo({top:0,behavior:"instant"})');
    await fs.writeFile(path.join(screenshots, 'mobile.png'), Buffer.from((await cdp('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
  }
  console.log(JSON.stringify({pages:pages.length,desktop:'passed',mobile:'passed',screenshots:5,darkMode:'passed',fonts:'passed',links:'passed',highlighting:'passed'}, null, 2));
} finally {
  // Let Chrome flush its profile and stop renderers before removing it. A
  // parent-only SIGTERM can leave Linux helper processes briefly writing files.
  if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify({id: 2147483647, method:'Browser.close'}));
  await new Promise(resolve => {
    if (!child.pid || child.exitCode !== null || child.signalCode !== null) { resolve(); return; }
    const timeout = setTimeout(() => { child.kill(); resolve(); }, 5000);
    child.once('exit', () => { clearTimeout(timeout); resolve(); });
  });
  ws?.close(); server.close();
  await fs.rm(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
}
