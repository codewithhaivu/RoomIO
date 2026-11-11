/* Data layer: no DOM access. Exact contracts from Backend/app/api/v1/admin.py. */
window.AdminAPI = (() => {
  'use strict';
  const DEFAULT_BASE_URL = 'http://127.0.0.1:8000';
  const BASE_KEY = 'troadmin.baseURL';
  const TOKEN_KEY = 'troadmin.accessToken';
  const TIMEOUT_MS = 20000;
  const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const readStorage = (storage, key) => { try { return window[storage].getItem(key) || ''; } catch { return ''; } };
  const writeStorage = (storage, key, value) => {
    try { if (value) window[storage].setItem(key, value); else window[storage].removeItem(key); } catch { /* Memory configuration still works when storage is disabled. */ }
  };
  function normalizeBaseURL(value) {
    const url = new URL(value.trim());
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) {
      throw new Error('Base URL phải dùng HTTP/HTTPS, không chứa tài khoản, query hoặc fragment.');
    }
    return url.href.replace(/\/+$/, '');
  }
  let baseURL;
  try { baseURL = normalizeBaseURL(readStorage('localStorage', BASE_KEY) || DEFAULT_BASE_URL); }
  catch { baseURL = DEFAULT_BASE_URL; }
  let accessToken = readStorage('sessionStorage', TOKEN_KEY);

  class APIError extends Error {
    constructor(message, status = 0, detail = null) {
      super(message); this.name = 'APIError'; this.status = status; this.detail = detail;
    }
  }
  function isUUID(value) { return UUID_PATTERN.test(String(value).trim()); }
  function uuid(value, label) {
    const id = String(value ?? '').trim();
    if (!isUUID(id)) throw new APIError(`${label} phải là UUID hợp lệ (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`);
    return id;
  }
  function pagination(page, limit) {
    if (!Number.isInteger(page) || page < 1 || !Number.isInteger(limit) || limit < 1 || limit > 100) {
      throw new APIError('Trang phải ≥ 1; số bản ghi mỗi trang phải từ 1 đến 100.');
    }
    return new URLSearchParams({ page: String(page), limit: String(limit) });
  }
  function errorDetail(detail) {
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail)) return detail.map(item => `${(item.loc || []).join('.')}: ${item.msg || 'Dữ liệu không hợp lệ'}`).join('\n');
    return '';
  }
  async function request(path, { method = 'GET', body, signal } = {}) {
    const controller = new AbortController();
    let timedOut = false;
    const abort = () => controller.abort();
    if (signal?.aborted) controller.abort();
    signal?.addEventListener('abort', abort, { once: true });
    const timeout = setTimeout(() => { timedOut = true; controller.abort(); }, TIMEOUT_MS);
    const headers = { Accept: 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
    try {
      const response = await fetch(`${baseURL}${path}`, {
        method, headers, signal: controller.signal, cache: 'no-store', credentials: 'omit',
        ...(body !== undefined ? { body: JSON.stringify(body) } : {})
      });
      const raw = await response.text();
      let payload = null;
      try { payload = raw ? JSON.parse(raw) : null; } catch { /* Do not expose raw HTML error pages. */ }
      if (!response.ok) {
        let message = errorDetail(payload?.detail) || payload?.message || `Yêu cầu thất bại (HTTP ${response.status}).`;
        if (response.status === 404 && (!payload?.detail || payload.detail === 'Not Found')) {
          message = 'Không tìm thấy endpoint quản trị (404). Kiểm tra Base URL và đăng ký admin_router trong app/api/router.py.';
        } else if (response.status === 401) {
          message = `Phiên xác thực không hợp lệ hoặc đã hết hạn. Cập nhật access token trong Cài đặt kết nối.\n${message}`;
        } else if (response.status === 403) {
          message = `Không có quyền thực hiện thao tác.\n${message}`;
        }
        throw new APIError(message, response.status, payload?.detail);
      }
      if (!payload || typeof payload !== 'object') throw new APIError('Backend không trả JSON hợp lệ. Kiểm tra Base URL.', response.status);
      return payload;
    } catch (error) {
      if (error instanceof APIError) throw error;
      if (error.name === 'AbortError') {
        if (!timedOut) throw error;
        throw new APIError('Backend phản hồi quá lâu (20 giây). Hãy kiểm tra kết nối và thử lại.');
      }
      throw new APIError('Không kết nối được backend. Kiểm tra Base URL, backend đang chạy, CORS và HTTP/HTTPS của giao diện.');
    } finally {
      clearTimeout(timeout);
      signal?.removeEventListener('abort', abort);
    }
  }
  return Object.freeze({
    APIError, isUUID,
    getConfig: () => ({ baseURL, accessToken }),
    configure({ baseURL: nextURL, accessToken: nextToken = '' }) {
      let normalized;
      try { normalized = normalizeBaseURL(nextURL); }
      catch { throw new APIError('Base URL không hợp lệ. Ví dụ: http://127.0.0.1:8000'); }
      const token = nextToken.trim().replace(/^Bearer\s+/i, '');
      if (/[\r\n]/.test(token)) throw new APIError('Access token không được chứa ký tự xuống dòng.');
      baseURL = normalized; accessToken = token;
      writeStorage('localStorage', BASE_KEY, baseURL);
      writeStorage('sessionStorage', TOKEN_KEY, accessToken);
      return { baseURL, accessToken };
    },
    async getMembers({ page = 1, limit = 10, signal } = {}) {
      const payload = await request(`/admin/members?${pagination(page, limit)}`, { signal });
      if (!Array.isArray(payload.data)) throw new APIError('Sai cấu trúc phản hồi: cần { data: User[] }.');
      // Explicit allowlist: the backend includes password, which must never reach the UI.
      return payload.data.map(user => ({
        id_account: user.id_account, phone_number: user.phone_number, full_name: user.full_name,
        role: user.role, state: user.state, is_verify: user.is_verify
      }));
    },
    verifyLandlord(idAccount) {
      return request('/admin/verify-landlord', { method: 'PATCH', body: { id_account: uuid(idAccount, 'ID tài khoản') } });
    },
    lockUser(id) {
      return request('/admin/locked-user', { method: 'PATCH', body: { id_user: uuid(id, 'ID tài khoản') } });
    },
    async getRooms(id, { page = 1, limit = 10, signal } = {}) {
      const id_account = uuid(id, 'ID tài khoản chủ trọ');
      const payload = await request(`/admin/rooms/${encodeURIComponent(id_account)}?${pagination(page, limit)}`, { signal });
      if (payload.rooms === null) return [];
      if (!Array.isArray(payload.rooms)) throw new APIError('Sai cấu trúc phản hồi: cần { rooms: RoomResponse[] | null }.');
      return payload.rooms;
    },
    deleteRooms(ids) {
      if (!Array.isArray(ids) || !ids.length) throw new APIError('Chọn ít nhất một phòng cần xóa.');
      const data = [...new Set(ids.map(id => uuid(id, 'ID phòng')))];
      return request('/admin/rooms', { method: 'DELETE', body: { data } });
    }
  });
})();
