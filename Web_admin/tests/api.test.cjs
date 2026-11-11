/* Run: node --test tests/api.test.cjs (Node.js 18+). No external dependencies. */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../js/api.js'), 'utf8');
const ID = '20000000-0000-4000-8000-000000000001';
function setup(fetchImpl, timers = {}) {
  const storage = () => { const data = new Map(); return { getItem: key => data.get(key), setItem: (key, value) => data.set(key, value), removeItem: key => data.delete(key) }; };
  const window = { localStorage: storage(), sessionStorage: storage() };
  vm.runInNewContext(source, { window, URL, URLSearchParams, AbortController, setTimeout, clearTimeout, fetch: fetchImpl, ...timers });
  return window;
}
const reply = (body, status = 200) => ({ ok: status >= 200 && status < 300, status, text: async () => typeof body === 'string' ? body : JSON.stringify(body) });

test('member response strips password and attaches centralized Bearer headers', async () => {
  let call;
  const win = setup(async (url, options) => { call = { url, options }; return reply({ data: [{ id_account: ID, full_name: 'Test', password: 'SECRET_HASH', role: 'LANDLORD', is_verify: 'false' }] }); });
  win.AdminAPI.configure({ baseURL: 'http://localhost:8000/api/v1/', accessToken: 'Bearer abc' });
  const members = await win.AdminAPI.getMembers({ page: 2, limit: 25 });
  assert.equal(call.url, 'http://localhost:8000/api/v1/admin/members?page=2&limit=25');
  assert.equal(call.options.headers.Authorization, 'Bearer abc');
  assert.equal(call.options.headers['Content-Type'], undefined);
  assert.equal('password' in members[0], false);
  assert.equal(win.sessionStorage.getItem('troadmin.accessToken'), 'abc');
  assert.equal(win.localStorage.getItem('troadmin.accessToken'), undefined);
});

test('mutations send strict schema bodies and deduplicate batch deletion IDs', async () => {
  const calls = [];
  const { AdminAPI: api } = setup(async (url, options) => { calls.push({ url, method: options.method, body: JSON.parse(options.body), headers: options.headers }); return reply({ message: 'ok' }); });
  await api.verifyLandlord(ID); await api.lockUser(ID); await api.deleteRooms([ID, ID]);
  assert.deepEqual(calls.map(call => [call.url.split('8000')[1], call.method, call.body]), [
    ['/admin/verify-landlord', 'PATCH', { id_account: ID }],
    ['/admin/locked-user', 'PATCH', { id_user: ID }],
    ['/admin/rooms', 'DELETE', { data: [ID] }]
  ]);
  assert.ok(calls.every(call => call.headers['Content-Type'] === 'application/json'));
});

test('validates UUIDs, pagination and base URLs before sending requests', async () => {
  let calls = 0;
  const { AdminAPI: api } = setup(async () => { calls++; return reply({}); });
  assert.throws(() => api.verifyLandlord('invalid'), /UUID/);
  assert.throws(() => api.lockUser('invalid'), /UUID/);
  assert.throws(() => api.deleteRooms([]), /ít nhất/);
  await assert.rejects(api.getRooms('invalid'), /UUID/);
  await assert.rejects(api.getMembers({ page: 0 }), /Trang/);
  await assert.rejects(api.getMembers({ limit: 101 }), /Trang/);
  for (const baseURL of ['javascript:alert(1)', 'http://user:pass@localhost', 'http://localhost?q=1', 'http://localhost#x']) assert.throws(() => api.configure({ baseURL }), /Base URL/);
  assert.equal(calls, 0);
});

test('handles nullable rooms and rejects unexpected success response schemas', async () => {
  const { AdminAPI: api } = setup(async () => reply({ rooms: null }));
  assert.equal((await api.getRooms(ID)).length, 0);
  await assert.rejects(api.getMembers(), /cấu trúc/);
  const bad = setup(async () => reply('<html>not JSON</html>')).AdminAPI;
  await assert.rejects(bad.getMembers(), /JSON/);
});

test('formats FastAPI 422 validation errors and actionable 404 / 401 errors', async () => {
  const invalid = setup(async () => reply({ detail: [{ loc: ['body', 'id_account'], msg: 'Invalid UUID' }] }, 422)).AdminAPI;
  await assert.rejects(invalid.verifyLandlord(ID), error => error.status === 422 && /body.id_account: Invalid UUID/.test(error.message));
  const missing = setup(async () => reply({ detail: 'Not Found' }, 404)).AdminAPI;
  await assert.rejects(missing.getMembers(), /admin_router/);
  const expired = setup(async () => reply({ detail: 'Expired token' }, 401)).AdminAPI;
  await assert.rejects(expired.getMembers(), error => error.status === 401 && /access token/.test(error.message));
});

test('distinguishes request cancellation, timeouts and network errors', async () => {
  const abortedFetch = async (_url, options) => new Promise((_resolve, reject) => {
    const abort = () => { const error = new Error('Aborted'); error.name = 'AbortError'; reject(error); };
    if (options.signal.aborted) abort(); else options.signal.addEventListener('abort', abort, { once: true });
  });
  const api = setup(abortedFetch).AdminAPI;
  const controller = new AbortController(); const pending = api.getMembers({ signal: controller.signal }); controller.abort();
  await assert.rejects(pending, error => error.name === 'AbortError');
  const timeout = setup(abortedFetch, { setTimeout: callback => setTimeout(callback, 1) }).AdminAPI;
  await assert.rejects(timeout.getMembers(), /20 giây/);
  const offline = setup(async () => { throw new TypeError('Failed to fetch'); }).AdminAPI;
  await assert.rejects(offline.getMembers(), /CORS/);
});
