/* Optional UI checks. Requires Playwright and an installed Chromium browser.
   npm install --no-save playwright
   $env:BROWSER_EXECUTABLE = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
   node tests/browser-smoke.cjs
   API responses are mocked; no real backend is accessed or modified. */
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const accountID = i => `10000000-0000-4000-8000-${String(i).padStart(12, '0')}`;
const landlordID = '20000000-0000-4000-8000-000000000001';
const roomID = i => `30000000-0000-4000-8000-${String(i).padStart(12, '0')}`;
const names = ['Nguyễn Hoàng Anh', 'Trần Minh Thư', 'Lê Quốc Bảo', 'Phạm Ngọc Linh', 'Võ Thanh Tùng', 'Đặng Mai Chi', 'Bùi Gia Hân', 'Đỗ Minh Khang', '<img src=x onerror="window.xss=true">', 'Hoàng Thanh Hà', 'Ngô Tuấn Kiệt', 'Trần Nhật Nam'];
const members = names.map((full_name, i) => ({ id_account: accountID(i + 1), full_name, phone_number: `09012345${String(i).padStart(2, '0')}`, password: 'SECRET_PASSWORD_HASH_NEVER_RENDER', role: i === 0 || i === 3 ? 'LANDLORD' : i === 5 ? 'ADMIN' : 'TENANT', state: i === 4 ? 'not ok' : 'ok', is_verify: i === 0 ? 'false' : i === 3 ? 'true' : null }));
let rooms = [1, 2, 3].map(i => ({ id: roomID(i), name: `Phòng studio ${i}`, area: 24 + i, water_fee: 100000, electricity_fee: 3500, service_fee: 150000, parking_fee: 100000, rental_price: 3500000 + i * 100000, status: i === 3 ? 'RENTED' : 'AVAILABLE', room_type: 'STUDIO', location: { name: '25 Nguyễn Văn Cừ, Quận 5, TP. Hồ Chí Minh', longitude: 106.682, latitude: 10.763 }, amenities: [{ id: roomID(5), name: 'Wifi' }], interiors: [{ id: roomID(6), name: 'Máy lạnh' }], image: { response: [{ image_url: 'javascript:alert(1)', public_id: 'unsafe', is_thumbnail: false }] } }));
const requests = [];
let failDelete = false;
let memberError = 0;
let memberDelay = 0;
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.md': 'text/plain; charset=utf-8' };
const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const filename = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!filename.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.readFile(filename, (error, content) => {
    res.writeHead(error ? 404 : 200, { 'Content-Type': mime[path.extname(filename)] || 'application/octet-stream' });
    res.end(error ? 'Not found' : content);
  });
});
const check = async (label, fn) => { await fn(); console.log(`PASS ${label}`); };
let browser;
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  browser = await chromium.launch({ headless: true, ...(process.env.BROWSER_EXECUTABLE ? { executablePath: process.env.BROWSER_EXECUTABLE } : {}) });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1080 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('http://127.0.0.1:8000/**', async route => {
    const request = route.request(); const url = new URL(request.url()); const method = request.method();
    const body = request.postDataJSON(); requests.push({ pathname: url.pathname, method, body });
    const respond = (payload, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(payload) });
    if (url.pathname === '/admin/members') {
      const snapshot = members.map(user => ({ ...user }));
      const failure = memberError;
      if (memberDelay) await new Promise(resolve => setTimeout(resolve, memberDelay));
      if (failure) return respond({ detail: failure === 404 ? 'Not Found' : failure === 401 ? 'Expired token' : 'Server error' }, failure);
      const start = (Number(url.searchParams.get('page')) - 1) * Number(url.searchParams.get('limit'));
      return respond({ data: snapshot.slice(start, start + Number(url.searchParams.get('limit'))) });
    }
    if (url.pathname === '/admin/verify-landlord' && method === 'PATCH') {
      assert.deepEqual(body, { id_account: accountID(1) }); members[0].is_verify = 'true';
      return respond({ id_account: accountID(1), state: 'verified' });
    }
    if (url.pathname === '/admin/locked-user' && method === 'PATCH') {
      assert.deepEqual(Object.keys(body), ['id_user']); members.find(user => user.id_account === body.id_user).state = 'not ok';
      return respond({ message: 'Khóa tài khoản thành công' });
    }
    if (url.pathname === `/admin/rooms/${landlordID}` && method === 'GET') {
      const start = (Number(url.searchParams.get('page')) - 1) * Number(url.searchParams.get('limit'));
      return respond({ rooms: rooms.slice(start, start + Number(url.searchParams.get('limit'))) });
    }
    if (url.pathname === '/admin/rooms' && method === 'DELETE') {
      assert.deepEqual(Object.keys(body), ['data']);
      if (failDelete) return respond({ detail: 'Không thể xóa phòng do ràng buộc dữ liệu liên quan' }, 400);
      rooms = rooms.filter(room => !body.data.includes(room.id)); return respond({ message: 'Xóa phòng thành công' });
    }
    return respond({ detail: 'Not Found' }, 404);
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  // Fulfill local assets directly as well: works in environments where Chromium
  // cannot access loopback networking. The rendered files are the actual source.
  await page.route(`${origin}/**`, async route => {
    const pathname = decodeURIComponent(new URL(route.request().url()).pathname);
    const filename = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!filename.startsWith(root + path.sep) || !fs.existsSync(filename)) return route.fulfill({ status: 404, body: 'Not found' });
    return route.fulfill({ contentType: mime[path.extname(filename)] || 'application/octet-stream', body: fs.readFileSync(filename) });
  });
  if (process.env.BOOTSTRAP_CSS) await page.route('https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css', route => route.fulfill({ contentType: 'text/css', body: fs.readFileSync(process.env.BOOTSTRAP_CSS) }));
  await page.goto(origin, { waitUntil: 'networkidle' });
  await check('initial members, statistics, escaped names and password removal', async () => {
    await page.locator('#members-body tr').first().waitFor();
    assert.equal(await page.locator('#members-body tr').count(), 10);
    assert.equal(await page.locator('#stat-members').textContent(), '10');
    assert.equal(await page.locator('#stat-pending').textContent(), '1');
    assert.equal(await page.locator('#members-body img').count(), 0);
    assert.equal(await page.evaluate(() => window.xss), undefined);
    assert.equal((await page.content()).includes('SECRET_PASSWORD_HASH_NEVER_RENDER'), false);
    assert.equal(await page.evaluate(() => [...document.styleSheets].some(sheet => sheet.href?.includes('bootstrap'))), true);
  });
  if (process.env.ARTIFACT_DIR) { fs.mkdirSync(process.env.ARTIFACT_DIR, { recursive: true }); await page.screenshot({ path: path.join(process.env.ARTIFACT_DIR, 'admin-desktop.png'), fullPage: true }); }
  await check('Vietnamese search, filters and reset', async () => {
    await page.locator('#member-search').fill('nguyen hoang'); assert.equal(await page.locator('#members-body tr').count(), 1);
    await page.locator('#clear-member-filters').click();
    await page.locator('#state-filter').selectOption('pending'); assert.equal(await page.locator('#members-body tr').count(), 1);
    await page.locator('#clear-member-filters').click();
  });
  await check('verification uses the displayed account UUID and removes the obsolete warning', async () => {
    await page.locator('[data-view="landlords"]').click();
    assert.equal(await page.locator('#members-body tr').count(), 2);
    assert.equal(await page.locator('#role-filter').isDisabled(), true);
    await page.locator(`[data-action="verify"][data-id="${accountID(1)}"]`).click();
    assert.equal(await page.locator('#verify-account-id').inputValue(), accountID(1));
    assert.equal(await page.locator('#verify-account-id').getAttribute('readonly'), '');
    await page.locator('#dialog-cancel').click();
    assert.equal(requests.filter(item => item.pathname === '/admin/verify-landlord').length, 0);
    await page.locator(`[data-action="member-detail"][data-id="${accountID(1)}"]`).click();
    assert.equal(await page.locator('#member-account-id').textContent(), accountID(1));
    assert.equal((await page.locator('#dialog-content').textContent()).includes('API thành viên không trả ID hồ sơ chủ trọ'), false);
    await page.locator('#dialog-submit').click();
    await page.waitForFunction(() => !document.getElementById('action-dialog').open);
    await page.locator(`[data-action="verify"][data-id="${accountID(1)}"][disabled]`).waitFor();
    await page.locator(`[data-action="member-detail"][data-id="${accountID(1)}"]`).click();
    assert.equal(await page.locator('#dialog-submit').isVisible(), false);
    await page.locator('#dialog-cancel').click();
    await page.locator('#open-verify').click();
    await page.locator('#verify-account-id').fill('invalid');
    await page.locator('#dialog-submit').click();
    await page.locator('#dialog-error').waitFor({ state: 'visible' });
    assert.match(await page.locator('#dialog-error').textContent(), /ID tài khoản.*UUID/);
    await page.locator('#dialog-cancel').click();
  });
  await check('locking supports cancel and confirm', async () => {
    await page.locator('[data-view="members"]').click();
    await page.locator(`[data-action="lock"][data-id="${accountID(2)}"]`).click(); await page.locator('#dialog-cancel').click();
    assert.equal(requests.filter(item => item.pathname === '/admin/locked-user').length, 0);
    await page.locator(`[data-action="lock"][data-id="${accountID(2)}"]`).click(); await page.locator('#dialog-submit').click();
    await page.locator(`[data-action="lock"][data-id="${accountID(2)}"][disabled]`).waitFor();
  });
  await check('server pagination and page size without invented totals', async () => {
    await page.locator('#members-next').click(); await page.waitForFunction(() => document.querySelectorAll('#members-body tr').length === 2);
    assert.equal(await page.locator('#members-page').textContent(), '2'); assert.equal(await page.locator('#members-next').isDisabled(), true);
    await page.locator('#members-prev').click(); await page.waitForFunction(() => document.querySelectorAll('#members-body tr').length === 10);
    await page.locator('#members-limit').selectOption('25'); await page.waitForFunction(() => document.querySelectorAll('#members-body tr').length === 12);
    assert.equal(await page.locator('#members-page').textContent(), '1');
  });
  await check('room lookup, room detail and unsafe image URL rejection', async () => {
    await page.locator('[data-view="rooms"]').click();
    await page.locator('#landlord-id').fill('invalid'); await page.locator('#room-lookup-button').click();
    assert.equal(requests.filter(item => item.pathname.includes('/admin/rooms/')).length, 0);
    await page.locator('#landlord-id').fill(landlordID); await page.locator('#room-lookup-button').click();
    await page.waitForFunction(() => document.querySelectorAll('#rooms-body tr').length === 3);
    await page.locator(`[data-action="room-detail"][data-id="${roomID(1)}"]`).click();
    const content = await page.locator('#dialog-content').textContent();
    for (const text of ['Máy lạnh', 'Wifi', 'Kinh độ', 'Phí điện', 'Phí nước', 'Phí giữ xe', '106.682']) assert.ok(content.includes(text), text);
    assert.equal(await page.locator('#dialog-content [href^="javascript:"]').count(), 0);
    await page.locator('#dialog-cancel').click();
  });
  await check('bulk selection clears on filters, errors keep dialog open, successful DELETE refreshes', async () => {
    await page.locator('#select-all-rooms').check(); assert.match(await page.locator('#selection-count').textContent(), /3/);
    await page.locator('#room-search').fill('studio 1'); assert.equal(await page.locator('#delete-selected').isDisabled(), true);
    await page.locator('#room-search').fill('');
    await page.locator(`.room-checkbox[data-id="${roomID(1)}"]`).check(); await page.locator(`.room-checkbox[data-id="${roomID(2)}"]`).check();
    await page.locator('#delete-selected').click(); failDelete = true; await page.locator('#dialog-submit').click();
    await page.locator('#dialog-error').waitFor({ state: 'visible' }); assert.match(await page.locator('#dialog-error').textContent(), /ràng buộc/);
    assert.equal(await page.locator('#action-dialog').evaluate(el => el.open), true);
    failDelete = false; await page.locator('#dialog-submit').click(); await page.waitForFunction(() => document.querySelectorAll('#rooms-body tr').length === 1);
    assert.deepEqual(requests.filter(item => item.method === 'DELETE').at(-1).body, { data: [roomID(1), roomID(2)] });
    assert.equal(await page.locator('#delete-selected').isDisabled(), true);
  });
  await check('HTTP 404, 401, retry and successful configuration check', async () => {
    await page.locator('[data-view="members"]').click(); memberError = 404; await page.locator('#refresh-button').click();
    await page.locator('#members-feedback [data-retry]').waitFor(); assert.match(await page.locator('#members-feedback').textContent(), /admin_router/);
    memberError = 401; await page.locator('#members-feedback [data-retry]').click(); await page.waitForFunction(() => document.getElementById('members-feedback').textContent.includes('access token'));
    memberError = 0; await page.locator('[data-view="settings"]').click(); await page.locator('#access-token').fill('test-token');
    await page.locator('#settings-form [type="submit"]').click(); await page.waitForFunction(() => document.getElementById('settings-feedback').textContent.includes('kết nối thành công'));
    assert.equal(await page.evaluate(() => sessionStorage.getItem('troadmin.accessToken')), 'test-token');
    await page.locator('#clear-token').click(); assert.equal(await page.evaluate(() => sessionStorage.getItem('troadmin.accessToken')), null);
  });
  await check('mobile layout, sidebar and keyboard dialog dismissal', async () => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.locator('#menu-toggle').click(); await page.locator('[data-view="members"]').click();
    await page.locator('#members-body tr').first().waitFor();
    await page.waitForFunction(() => document.getElementById('sidebar').getBoundingClientRect().right <= 0);
    assert.equal(await page.locator('#sidebar').evaluate(el => el.classList.contains('is-open')), false);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.locator('#toast-region .icon-button').evaluateAll(buttons => buttons.forEach(button => button.click()));
    if (process.env.ARTIFACT_DIR) await page.screenshot({ path: path.join(process.env.ARTIFACT_DIR, 'admin-mobile.png'), fullPage: true });
    // Table actions are intentionally horizontally scrollable on phones.
    await page.locator('[data-action="member-detail"]').first().click(); await page.keyboard.press('Escape');
    assert.equal(await page.locator('#action-dialog').evaluate(el => el.open), false);
  });
  await check('slow previous page cannot overwrite new configuration data', async () => {
    await page.setViewportSize({ width: 1440, height: 1080 });
    memberDelay = 500;
    await page.locator('#refresh-button').click();
    await page.locator('[data-view="settings"]').click(); memberDelay = 0;
    await page.locator('#settings-form [type="submit"]').click();
    await page.waitForFunction(() => document.getElementById('settings-feedback').textContent.includes('kết nối thành công'));
    await page.locator('[data-view="members"]').click();
    assert.equal(await page.locator('#members-body tr').count(), 12);
  });
  assert.deepEqual(errors, []);
  console.log(`PASS no browser JavaScript errors; ${requests.length} mocked API requests`);
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(async () => { await browser?.close(); server.close(); });
