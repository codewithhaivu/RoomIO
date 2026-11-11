/* Presentation layer: DOM, navigation, state and user interactions. */
(() => {
  'use strict';
  const API = window.AdminAPI;
  const $ = id => document.getElementById(id);
  const icons = {
    building: '<path d="M4 21V5l8-3 8 3v16M9 21v-5h6v5M2 21h20M8 7h1m6 0h1M8 11h1m6 0h1"/>',
    users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/><circle cx="9" cy="7" r="4"/>',
    shield: '<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z"/><path d="m8 12 3 3 5-5"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    settings: '<path d="m9 3-1 3-3 1-2 3 2 2-1 4 3 2 3-1 3 3 3-2 1-3 4-1v-4l-3-1-1-3-3-2-2 2-3-1Z"/><circle cx="12" cy="12" r="3"/>',
    sparkles: '<path d="m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3ZM20 2v4m-2-2h4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2"/>',
    refresh: '<path d="M20 7v5h-5M4 17v-5h5"/><path d="M6.1 6a8 8 0 0 1 13 2L20 12M4 12l.9 4a8 8 0 0 0 13 2"/>',
    search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    filter: '<path d="M4 7h16M7 12h10M10 17h4"/>',
    database: '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v14c0 4 16 4 16 0V5M4 12c0 4 16 4 16 0"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.01"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    trash: '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7"/>',
    eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    close: '<path d="m6 6 12 12M6 18 18 6"/>',
    menu: '<path d="M4 6h16M4 12h16M4 18h16"/>'
  };
  const icon = name => `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.info}</svg>`;
  document.querySelectorAll('[data-icon]').forEach(el => { el.innerHTML = icon(el.dataset.icon); });
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
  const normalize = value => String(value ?? '').trim().toLowerCase();
  const searchable = value => normalize(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd');
  const verified = value => value === true || normalize(value) === 'true';
  const landlord = user => normalize(user.role) === 'landlord';
  const locked = user => normalize(user.state) === 'not ok';
  const money = value => Number.isFinite(Number(value)) && value !== null ? new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND', maximumFractionDigits: 0 }).format(value) : '—';
  const number = value => Number.isFinite(Number(value)) && value !== null ? new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(value) : '—';
  const displayName = user => String(user.full_name || '').trim() || 'Chưa có tên';
  const initials = name => (String(name).trim().split(/\s+/).filter(Boolean).slice(-2).map(part => Array.from(part)[0]).join('') || '?').toUpperCase();
  const state = {
    view: 'members',
    members: { data: [], page: 1, limit: 10, loaded: false, loading: false, error: '', controller: null, revision: 0 },
    rooms: { data: [], page: 1, limit: 10, loaded: false, loading: false, error: '', controller: null, revision: 0, landlordID: '', selected: new Set() },
    dialogAction: null, dialogBusy: false, connectionRevision: 0
  };
  function badge(text, tone = '', dot = false) {
    return `<span class="badge-soft ${tone ? `badge-${tone}` : ''}">${dot ? '<span class="badge-dot"></span>' : ''}${escape(text)}</span>`;
  }
  function roleBadge(role) {
    const key = normalize(role);
    if (key === 'landlord') return badge('Chủ trọ', 'purple');
    if (key === 'tenant' || key === 'customer') return badge('Người thuê', 'blue');
    if (key === 'admin') return badge('Quản trị viên', 'amber');
    return badge(role || 'Chưa phân loại');
  }
  function stateBadge(user) {
    if (locked(user)) return badge('Đã khóa', 'red', true);
    if (normalize(user.state) === 'ok') return badge('Hoạt động', 'green', true);
    return badge(user.state || 'Chưa rõ', '', true);
  }
  function verifyBadge(user) {
    if (!landlord(user)) return '<span class="text-secondary">—</span>';
    return verified(user.is_verify) ? badge('Đã xác minh', 'green') : badge('Chờ xác minh', 'amber');
  }
  function roomStatus(status) {
    const key = normalize(status);
    const known = { available: ['Còn phòng', 'green'], rented: ['Đã cho thuê', 'blue'], unavailable: ['Hết phòng', 'red'], occupied: ['Đã có người ở', 'blue'], pending: ['Chờ duyệt', 'amber'] };
    return known[key] ? badge(...known[key], true) : badge(status || 'Chưa rõ', '', true);
  }
  function actionButton(action, id, label, name, danger = false, disabled = false) {
    return `<button type="button" class="icon-button ${danger ? 'danger' : ''}" data-action="${action}" data-id="${escape(id)}" title="${escape(label)}" aria-label="${escape(label)}" ${disabled ? 'disabled' : ''}>${icon(name)}</button>`;
  }
  function toast(message, error = false) {
    const element = document.createElement('div');
    element.className = `app-toast${error ? ' error' : ''}`;
    element.innerHTML = `${icon(error ? 'info' : 'check')}<span>${escape(message)}</span><button class="icon-button" aria-label="Đóng thông báo">${icon('close')}</button>`;
    element.querySelector('button').addEventListener('click', () => element.remove());
    $('toast-region').append(element);
    while ($('toast-region').children.length > 4) $('toast-region').firstElementChild.remove();
    setTimeout(() => element.remove(), error ? 14000 : 6500);
  }
  function setConnection(status) {
    $('connection-dot').className = `status-dot ${status === 'online' ? 'online' : status === 'offline' ? 'offline' : ''}`;
    $('connection-label').textContent = ({ online: 'Đã kết nối API', offline: 'Lỗi kết nối API', waiting: 'Đang kết nối…', idle: 'Chưa kết nối' })[status];
  }
  function feedback(resource, type, title = '', message = '') {
    const el = $(`${resource}-feedback`);
    el.hidden = !type;
    if (!type) { el.innerHTML = ''; return; }
    if (type === 'loading') { el.innerHTML = '<span class="spinner" aria-hidden="true"></span>Đang tải dữ liệu…'; return; }
    el.innerHTML = `<div class="empty-icon">${icon(type === 'error' ? 'info' : resource === 'rooms' ? 'building' : 'users')}</div><h3>${escape(title)}</h3><p>${escape(message)}</p>${type === 'error' ? `<button class="btn btn-white" data-retry="${resource}">${icon('refresh')}Thử lại</button> <a href="#settings" class="btn btn-white">Cài đặt kết nối</a>` : ''}`;
  }
  function updatePagination(resource, filteredCount) {
    const data = state[resource];
    $(`${resource}-page`).textContent = data.page;
    $(`${resource}-prev`).disabled = data.loading || data.page <= 1;
    // Responses contain no total: a full page only indicates that another page MAY exist.
    $(`${resource}-next`).disabled = data.loading || !data.loaded || !!data.error || data.data.length < data.limit;
    $(`${resource}-limit`).disabled = data.loading;
    $(`${resource}-summary`).textContent = data.loading ? 'Đang tải dữ liệu…' : data.error ? 'Không tải được dữ liệu' : data.loaded ? `Trang ${data.page} · Hiển thị ${filteredCount} / ${data.data.length} ${resource === 'members' ? 'thành viên' : 'phòng'}` : 'Chưa tải dữ liệu';
    $(`${resource}-view`)?.setAttribute('aria-busy', String(data.loading));
    if (resource === 'members') $('members-view').setAttribute('aria-busy', String(data.loading));
  }
  function visibleMembers() {
    const query = searchable($('member-search').value);
    const role = state.view === 'landlords' ? 'landlord' : $('role-filter').value;
    const filter = $('state-filter').value;
    return state.members.data.filter(user => {
      const matchRole = !role || normalize(user.role) === role || (role === 'tenant' && normalize(user.role) === 'customer');
      const matchState = !filter || (filter === 'pending' ? landlord(user) && !verified(user.is_verify) : normalize(user.state) === filter);
      return matchRole && matchState && (!query || searchable(`${user.full_name} ${user.phone_number} ${user.id_account}`).includes(query));
    });
  }
  function renderMembers() {
    const data = state.members;
    const users = visibleMembers();
    $('member-count').textContent = data.loaded && !data.loading && !data.error ? users.length : '—';
    const stats = {
      'stat-members': data.data.length,
      'stat-landlords': data.data.filter(landlord).length,
      'stat-pending': data.data.filter(user => landlord(user) && !verified(user.is_verify)).length,
      'stat-locked': data.data.filter(locked).length
    };
    Object.entries(stats).forEach(([id, value]) => { $(id).textContent = data.loaded && !data.loading && !data.error ? value : '—'; });
    $('members-body').innerHTML = !data.loading && !data.error ? users.map((user, index) => `<tr><td><div class="member-cell"><span class="avatar avatar-tone-${index % 5}">${escape(initials(displayName(user)))}</span><div><span class="member-name">${escape(displayName(user))}</span><span class="member-id" title="${escape(user.id_account)}">${escape(user.id_account)}</span></div></div></td><td>${escape(user.phone_number || '—')}</td><td>${roleBadge(user.role)}</td><td>${stateBadge(user)}</td><td>${verifyBadge(user)}</td><td><div class="row-actions">${actionButton('member-detail', user.id_account, 'Chi tiết thành viên', 'eye')}${landlord(user) ? actionButton('verify', user.id_account, verified(user.is_verify) ? 'Chủ trọ đã được xác minh' : 'Xác minh bằng ID tài khoản', 'shield', false, verified(user.is_verify)) + actionButton('landlord-rooms', user.id_account, 'Tra cứu phòng bằng ID hồ sơ chủ trọ', 'building') : ''}${actionButton('lock', user.id_account, locked(user) ? 'Tài khoản đã khóa' : 'Khóa tài khoản', 'lock', true, locked(user))}</div></td></tr>`).join('') : '';
    if (data.loading) feedback('members', 'loading');
    else if (data.error) feedback('members', 'error', 'Chưa thể tải danh sách thành viên', data.error);
    else if (!users.length) feedback('members', 'empty', data.data.length ? 'Không có kết quả phù hợp' : 'Trang này chưa có thành viên', data.data.length ? 'Thử thay đổi hoặc đặt lại bộ lọc. Bộ lọc chỉ áp dụng trong trang hiện tại.' : data.page > 1 ? 'Đã đến cuối danh sách. Quay lại trang trước để tiếp tục quản lý.' : 'Danh sách tài khoản từ backend hiện đang trống.');
    else feedback('members', '');
    updatePagination('members', users.length);
  }
  async function loadMembers() {
    const data = state.members;
    data.controller?.abort();
    const controller = new AbortController();
    data.controller = controller;
    const revision = ++data.revision;
    const connectionRevision = state.connectionRevision;
    data.loading = true; data.error = ''; renderMembers(); setConnection('waiting');
    try {
      const result = await API.getMembers({ page: data.page, limit: data.limit, signal: controller.signal });
      if (revision !== data.revision || connectionRevision !== state.connectionRevision) return;
      data.data = result; data.loaded = true; setConnection('online');
    } catch (error) {
      if (revision !== data.revision || connectionRevision !== state.connectionRevision || error.name === 'AbortError') return;
      data.data = []; data.error = error.message; data.loaded = false; setConnection('offline');
    } finally {
      if (revision === data.revision && connectionRevision === state.connectionRevision) { data.loading = false; renderMembers(); }
    }
  }
  function safeImageURL(value) {
    try { const url = new URL(value); return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password ? url.href : ''; } catch { return ''; }
  }
  function roomImages(room) { return (room.image?.response || []).filter(image => safeImageURL(image.image_url)); }
  function visibleRooms() {
    const query = searchable($('room-search').value);
    const status = $('room-status-filter').value;
    return state.rooms.data.filter(room => (!status || room.status === status) && (!query || searchable(`${room.name} ${room.location?.name || ''} ${room.id}`).includes(query)));
  }
  function renderSelection() {
    const data = state.rooms;
    const visible = visibleRooms();
    const count = visible.filter(room => data.selected.has(room.id)).length;
    $('select-all-rooms').checked = visible.length > 0 && count === visible.length;
    $('select-all-rooms').indeterminate = count > 0 && count < visible.length;
    $('select-all-rooms').disabled = data.loading || !visible.length;
    $('delete-selected').disabled = data.loading || !data.selected.size;
    $('selection-count').textContent = `(${data.selected.size})`;
  }
  function bindImageFallbacks(container) {
    container.querySelectorAll('img').forEach(img => {
      img.addEventListener('error', () => { const fallback = document.createElement('span'); fallback.className = 'room-thumb'; fallback.innerHTML = icon('building'); fallback.setAttribute('aria-label', 'Không tải được ảnh phòng'); img.replaceWith(fallback); }, { once: true });
    });
  }
  function renderRooms() {
    const data = state.rooms;
    const rooms = visibleRooms();
    $('room-count').textContent = data.loaded && !data.error && !data.loading ? rooms.length : '—';
    $('room-owner-label').textContent = data.landlordID ? `ID chủ trọ: ${data.landlordID}` : 'Chọn chủ trọ để bắt đầu tra cứu';
    $('room-lookup-button').disabled = data.loading;
    $('rooms-body').innerHTML = !data.loading && !data.error ? rooms.map(room => {
      const images = roomImages(room);
      const thumbnail = images.find(image => image.is_thumbnail) || images[0];
      return `<tr><td class="checkbox-cell"><input class="form-check-input room-checkbox" type="checkbox" data-id="${escape(room.id)}" aria-label="Chọn phòng ${escape(room.name)}" ${data.selected.has(room.id) ? 'checked' : ''}></td><td><div class="member-cell">${thumbnail ? `<img class="room-thumb" src="${escape(safeImageURL(thumbnail.image_url))}" alt="" loading="lazy" referrerpolicy="no-referrer">` : `<span class="room-thumb">${icon('building')}</span>`}<div class="room-title"><span class="member-name">${escape(room.name)}</span><div class="room-address" title="${escape(room.location?.name)}">${escape(room.location?.name || 'Chưa có địa chỉ')}</div></div></div></td><td class="price">${money(room.rental_price)}</td><td>${number(room.area)} m²</td><td>${roomStatus(room.status)}</td><td><div class="row-actions">${actionButton('room-detail', room.id, 'Xem chi tiết phòng', 'eye')}${actionButton('delete-room', room.id, 'Xóa phòng', 'trash', true)}</div></td></tr>`;
    }).join('') : '';
    bindImageFallbacks($('rooms-body'));
    if (data.loading) feedback('rooms', 'loading');
    else if (data.error) feedback('rooms', 'error', 'Chưa thể tải danh sách phòng', data.error);
    else if (!data.landlordID) feedback('rooms', 'empty', 'Tìm một chủ trọ để bắt đầu', 'Nhập UUID hồ sơ chủ trọ vào ô tra cứu phía trên để xem các phòng và bài đăng.');
    else if (!rooms.length) feedback('rooms', 'empty', data.data.length ? 'Không có phòng phù hợp' : 'Trang này chưa có phòng', data.data.length ? 'Thử thay đổi từ khóa hoặc trạng thái lọc.' : data.page > 1 ? 'Đã đến cuối danh sách. Quay lại trang trước để xem phòng.' : 'Chủ trọ chưa có phòng hoặc ID hồ sơ không tồn tại. Kiểm tra lại ID chủ trọ.');
    else feedback('rooms', '');
    renderSelection(); updatePagination('rooms', rooms.length);
  }
  async function loadRooms() {
    const data = state.rooms;
    if (!data.landlordID) { renderRooms(); return; }
    data.controller?.abort();
    const controller = new AbortController(); data.controller = controller;
    const revision = ++data.revision;
    const connectionRevision = state.connectionRevision;
    data.loading = true; data.error = ''; data.selected.clear(); renderRooms(); setConnection('waiting');
    try {
      const result = await API.getRooms(data.landlordID, { page: data.page, limit: data.limit, signal: controller.signal });
      if (revision !== data.revision || connectionRevision !== state.connectionRevision) return;
      data.data = result; data.loaded = true; setConnection('online');
      const previousStatus = $('room-status-filter').value;
      $('room-status-filter').innerHTML = '<option value="">Tất cả trạng thái</option>' + [...new Set(result.map(room => room.status))].filter(Boolean).map(status => `<option value="${escape(status)}">${escape(status)}</option>`).join('');
      if (result.some(room => room.status === previousStatus)) $('room-status-filter').value = previousStatus;
    } catch (error) {
      if (revision !== data.revision || connectionRevision !== state.connectionRevision || error.name === 'AbortError') return;
      data.data = []; data.loaded = false; data.error = error.message; setConnection('offline');
    } finally {
      if (revision === data.revision && connectionRevision === state.connectionRevision) { data.loading = false; renderRooms(); }
    }
  }
  const views = {
    members: ['Thành viên', 'Quản lý thành viên', 'Theo dõi tài khoản và quản lý cộng đồng của bạn.'],
    landlords: ['Duyệt chủ trọ', 'Xác minh chủ trọ', 'Duyệt hồ sơ để chủ trọ có thể sử dụng đầy đủ chức năng.'],
    rooms: ['Phòng & bài đăng', 'Quản lý phòng & bài đăng', 'Tra cứu phòng theo chủ trọ và kiểm duyệt nội dung đăng tải.'],
    settings: ['Cài đặt kết nối', 'Cài đặt kết nối', 'Thiết lập kết nối đến backend FastAPI của bạn.']
  };
  function closeMenu() { $('sidebar').classList.remove('is-open'); $('sidebar-overlay').hidden = true; $('menu-toggle').setAttribute('aria-expanded', 'false'); }
  function navigate() {
    const route = location.hash.slice(1);
    const view = views[route] ? route : 'members';
    state.view = view;
    const [label, title, description] = views[view];
    $('breadcrumb-current').textContent = label;
    $('page-title').innerHTML = `${escape(title)}<span class="heading-dot">.</span>`;
    $('page-description').textContent = description;
    document.title = `${label} · Trọ Admin`;
    document.querySelectorAll('[data-view]').forEach(link => { const active = link.dataset.view === view; link.classList.toggle('active', active); if (active) link.setAttribute('aria-current', 'page'); else link.removeAttribute('aria-current'); });
    $('members-view').hidden = !['members', 'landlords'].includes(view);
    $('rooms-view').hidden = view !== 'rooms'; $('settings-view').hidden = view !== 'settings';
    $('refresh-button').hidden = view === 'settings';
    $('member-stats').hidden = view === 'landlords'; $('landlord-banner').hidden = view !== 'landlords';
    $('role-filter').disabled = view === 'landlords';
    $('role-filter').value = view === 'landlords' ? 'landlord' : '';
    $('member-list-title').innerHTML = `${view === 'landlords' ? 'Danh sách chủ trọ' : 'Danh sách thành viên'} <span class="count-pill" id="member-count">—</span>`;
    $('member-list-description').textContent = view === 'landlords' ? 'Chủ trọ được lọc từ trang thành viên hiện tại' : 'Tất cả tài khoản trong trang dữ liệu hiện tại';
    if (view === 'members' || view === 'landlords') { if (!state.members.loaded && !state.members.loading) loadMembers(); else renderMembers(); }
    if (view === 'rooms') renderRooms();
    if (view === 'settings') { const config = API.getConfig(); $('base-url').value = config.baseURL; $('access-token').value = config.accessToken; }
    closeMenu();
  }
  function openDialog(title, content, { label = 'Xác nhận', danger = false, action = null } = {}) {
    $('dialog-title').textContent = title; $('dialog-content').innerHTML = content;
    $('dialog-error').hidden = true; $('dialog-error').textContent = '';
    $('dialog-submit').textContent = label; $('dialog-submit').className = `btn ${danger ? 'btn-danger' : 'btn-primary'}`;
    $('dialog-submit').hidden = !action;
    $('dialog-cancel').textContent = action ? 'Hủy' : 'Đóng';
    state.dialogAction = action;
    $('action-dialog').showModal(); document.body.classList.add('modal-open');
    bindImageFallbacks($('dialog-content'));
  }
  function closeDialog() { if (!state.dialogBusy) $('action-dialog').close(); }
  function detail(label, value, wide = false) { return `<div class="detail-item${wide ? ' detail-wide' : ''}"><span>${escape(label)}</span><strong>${escape(value ?? '—')}</strong></div>`; }
  async function verifyAccount(idAccount) {
    const result = await API.verifyLandlord(idAccount);
    return {
      message: `Đã xác minh chủ trọ có ID tài khoản ${result.id_account || idAccount}.`,
      refresh: loadMembers
    };
  }
  function showMember(user) {
    const canVerify = landlord(user) && !verified(user.is_verify);
    openDialog('Chi tiết thành viên', `
      <div class="member-cell">
        <span class="avatar">${escape(initials(displayName(user)))}</span>
        <div><strong>${escape(displayName(user))}</strong><div>${roleBadge(user.role)}</div></div>
      </div>
      <div class="detail-grid">
        <div class="detail-item detail-wide">
          <span>ID tài khoản (accounts.id)</span>
          <strong id="member-account-id">${escape(user.id_account)}</strong>
        </div>
        ${detail('Số điện thoại', user.phone_number)}
        ${detail('Vai trò gốc', user.role)}
        ${detail('Trạng thái gốc', user.state)}
        ${detail('Xác minh chủ trọ', landlord(user) ? verified(user.is_verify) ? 'Đã xác minh' : 'Chưa xác minh' : 'Không áp dụng')}
      </div>`, {
      label: 'Xác minh chủ trọ',
      action: canVerify
        ? () => verifyAccount($('member-account-id').textContent.trim())
        : null
    });
  }
  function openVerify(user = null) {
    openDialog('Xác minh chủ trọ', `
      <p>Duyệt hồ sơ để chủ trọ có thể sử dụng các chức năng của hệ thống.</p>
      ${user ? `<p>Chủ trọ: <strong>${escape(displayName(user))}</strong></p>` : ''}
      <label for="verify-account-id" class="form-label">ID tài khoản (accounts.id)</label>
      <input id="verify-account-id" class="form-control font-monospace" required
        value="${escape(user?.id_account || '')}" ${user ? 'readonly' : ''}
        placeholder="UUID tài khoản chủ trọ" autocomplete="off">`, {
      label: 'Xác minh chủ trọ',
      action: () => verifyAccount($('verify-account-id').value.trim())
    });
  }
  function openLock(user) {
    openDialog('Khóa tài khoản này?', `<p>Tài khoản <strong>${escape(displayName(user))}</strong> (${escape(user.phone_number)}) sẽ chuyển sang trạng thái <code>not ok</code> và không thể đăng nhập.</p><div class="detail-grid">${detail('ID tài khoản', user.id_account, true)}</div><p class="mb-0">Backend hiện chưa có thao tác mở khóa tài khoản. Hãy kiểm tra kỹ trước khi xác nhận.</p>`, {
      label: 'Xác nhận khóa', danger: true,
      action: async () => { const result = await API.lockUser(user.id_account); return { message: result.message || 'Khóa tài khoản thành công.', refresh: loadMembers }; }
    });
  }
  function openLandlordRooms(user) {
    openDialog('Tra cứu phòng của chủ trọ', `<p>Tra cứu bài đăng của <strong>${escape(displayName(user))}</strong>.</p><small class="d-block mb-3">ID tài khoản tham chiếu: <code>${escape(user.id_account)}</code></small><label for="lookup-dialog-id" class="form-label">ID hồ sơ chủ trọ</label><input id="lookup-dialog-id" class="form-control font-monospace" placeholder="UUID từ landlords.id" required autocomplete="off"><div class="form-text">API dùng ID hồ sơ chủ trọ, khác ID tài khoản trong danh sách.</div>`, {
      label: 'Xem danh sách phòng',
      action: async () => {
        const id = $('lookup-dialog-id').value.trim();
        if (!API.isUUID(id)) throw new Error('Vui lòng nhập UUID hồ sơ chủ trọ hợp lệ.');
        if (normalize(id) === normalize(user.id_account)) throw new Error('Hãy nhập landlords.id thay vì ID tài khoản đang tham chiếu.');
        $('landlord-id').value = id; state.rooms.landlordID = id; state.rooms.page = 1;
        $('room-search').value = ''; $('room-status-filter').value = '';
        location.hash = 'rooms';
        return { refresh: loadRooms };
      }
    });
  }
  function showRoom(room) {
    const gallery = roomImages(room).map(image => `<a href="${escape(safeImageURL(image.image_url))}" target="_blank" rel="noopener noreferrer"><img src="${escape(safeImageURL(image.image_url))}" alt="${escape(room.name)}" loading="lazy" referrerpolicy="no-referrer"></a>`).join('');
    const tags = values => values?.length ? values.map(value => badge(value.name, 'purple')).join('') : '<span class="text-secondary">Chưa có thông tin</span>';
    openDialog('Chi tiết phòng', `${gallery ? `<div class="room-gallery mb-4">${gallery}</div>` : ''}<h3 class="fs-5">${escape(room.name)}</h3>${roomStatus(room.status)}<div class="detail-grid">${detail('ID phòng', room.id, true)}${detail('Giá thuê / tháng', money(room.rental_price))}${detail('Diện tích', `${number(room.area)} m²`)}${detail('Loại phòng', room.room_type)}${detail('Trạng thái gốc', room.status)}${detail('Địa chỉ', room.location?.name, true)}${detail('Kinh độ', room.location?.longitude)}${detail('Vĩ độ', room.location?.latitude)}${detail('Phí điện', money(room.electricity_fee))}${detail('Phí nước', money(room.water_fee))}${detail('Phí dịch vụ', money(room.service_fee))}${detail('Phí giữ xe', money(room.parking_fee))}</div><small>Đơn vị tính các khoản phí theo dữ liệu backend; API không trả chu kỳ tính phí.</small><div class="mt-3"><strong>Nội thất</strong><div class="detail-tags">${tags(room.interiors)}</div></div><div class="mt-3"><strong>Tiện ích</strong><div class="detail-tags">${tags(room.amenities)}</div></div>`);
  }
  function openDelete(ids) {
    const snapshot = [...new Set(ids)];
    if (!snapshot.length) return;
    const selected = state.rooms.data.filter(room => snapshot.includes(room.id));
    openDialog(`Xóa ${snapshot.length} phòng đã chọn?`, `<p>Thao tác này sẽ xóa vĩnh viễn phòng và dữ liệu liên quan theo xử lý của backend, bao gồm ảnh, tiện ích, nội thất, lịch hẹn và lượt thuê.</p><ul>${selected.map(room => `<li><strong>${escape(room.name)}</strong><br><small class="font-monospace">${escape(room.id)}</small></li>`).join('')}</ul><p class="mb-0">Bạn không thể hoàn tác thao tác này trên giao diện.</p>`, {
      label: `Xác nhận xóa ${snapshot.length} phòng`, danger: true,
      action: async () => {
        const result = await API.deleteRooms(snapshot);
        state.rooms.selected.clear();
        if (snapshot.length === state.rooms.data.length && state.rooms.page > 1) state.rooms.page--;
        return { message: result.message || 'Xóa phòng thành công.', refresh: loadRooms };
      }
    });
  }
  $('action-form').addEventListener('submit', async event => {
    event.preventDefault(); if (state.dialogBusy || !state.dialogAction) return;
    state.dialogBusy = true;
    const label = $('dialog-submit').textContent;
    $('dialog-submit').innerHTML = '<span class="spinner" aria-hidden="true"></span>Đang xử lý…';
    $('dialog-error').hidden = true;
    $('action-dialog').querySelectorAll('button,input').forEach(element => { element.disabled = true; });
    try {
      const result = await state.dialogAction();
      state.dialogBusy = false; $('action-dialog').close();
      if (result?.message) toast(result.message);
      if (result?.refresh) await result.refresh();
    } catch (error) {
      $('dialog-error').textContent = error.message; $('dialog-error').hidden = false;
      if (error.status === 401 || error.status === 403) setConnection('offline');
    } finally {
      state.dialogBusy = false;
      $('dialog-submit').textContent = label;
      $('action-dialog').querySelectorAll('button,input').forEach(element => { element.disabled = false; });
    }
  });
  $('action-dialog').addEventListener('cancel', event => { if (state.dialogBusy) event.preventDefault(); });
  $('action-dialog').addEventListener('close', () => { document.body.classList.remove('modal-open'); state.dialogAction = null; });
  $('dialog-close').addEventListener('click', closeDialog); $('dialog-cancel').addEventListener('click', closeDialog);
  $('open-verify').addEventListener('click', () => openVerify());
  $('members-body').addEventListener('click', event => {
    const button = event.target.closest('[data-action]'); if (!button || button.disabled) return;
    const user = state.members.data.find(item => String(item.id_account) === button.dataset.id); if (!user) return;
    ({ 'member-detail': showMember, verify: openVerify, lock: openLock, 'landlord-rooms': openLandlordRooms })[button.dataset.action]?.(user);
  });
  $('rooms-body').addEventListener('click', event => {
    const button = event.target.closest('[data-action]'); if (!button) return;
    const room = state.rooms.data.find(item => String(item.id) === button.dataset.id); if (!room) return;
    if (button.dataset.action === 'room-detail') showRoom(room);
    if (button.dataset.action === 'delete-room') openDelete([room.id]);
  });
  $('rooms-body').addEventListener('change', event => {
    if (!event.target.matches('.room-checkbox')) return;
    const id = event.target.dataset.id;
    if (event.target.checked) state.rooms.selected.add(id); else state.rooms.selected.delete(id);
    renderSelection();
  });
  $('select-all-rooms').addEventListener('change', event => { visibleRooms().forEach(room => { if (event.target.checked) state.rooms.selected.add(room.id); else state.rooms.selected.delete(room.id); }); renderRooms(); });
  $('delete-selected').addEventListener('click', () => openDelete([...state.rooms.selected]));
  ['member-search', 'role-filter', 'state-filter'].forEach(id => $(id).addEventListener(id === 'member-search' ? 'input' : 'change', renderMembers));
  $('clear-member-filters').addEventListener('click', () => { $('member-search').value = ''; $('state-filter').value = ''; $('role-filter').value = state.view === 'landlords' ? 'landlord' : ''; renderMembers(); });
  ['room-search', 'room-status-filter'].forEach(id => $(id).addEventListener(id === 'room-search' ? 'input' : 'change', () => { state.rooms.selected.clear(); renderRooms(); }));
  $('room-lookup-form').addEventListener('submit', event => {
    event.preventDefault();
    const input = $('landlord-id');
    input.setCustomValidity('');
    if (!API.isUUID(input.value.trim())) { input.setCustomValidity('Vui lòng nhập UUID hồ sơ chủ trọ hợp lệ.'); input.reportValidity(); return; }
    state.rooms.landlordID = input.value.trim(); state.rooms.page = 1;
    $('room-search').value = ''; $('room-status-filter').value = ''; loadRooms();
  });
  $('landlord-id').addEventListener('input', () => $('landlord-id').setCustomValidity(''));
  for (const resource of ['members', 'rooms']) {
    const loader = resource === 'members' ? loadMembers : loadRooms;
    $(`${resource}-prev`).addEventListener('click', () => { if (state[resource].page > 1 && !state[resource].loading) { state[resource].page--; loader(); } });
    $(`${resource}-next`).addEventListener('click', () => { if (!state[resource].loading) { state[resource].page++; loader(); } });
    $(`${resource}-limit`).addEventListener('change', event => { state[resource].limit = Number(event.target.value); state[resource].page = 1; loader(); });
  }
  document.addEventListener('click', event => { const button = event.target.closest('[data-retry]'); if (button) { if (button.dataset.retry === 'members') loadMembers(); else loadRooms(); } });
  $('refresh-button').addEventListener('click', () => { if (state.view === 'rooms') loadRooms(); else loadMembers(); });
  $('connection-shortcut').addEventListener('click', () => { location.hash = 'settings'; });
  $('menu-toggle').addEventListener('click', () => { const open = $('sidebar').classList.toggle('is-open'); $('sidebar-overlay').hidden = !open; $('menu-toggle').setAttribute('aria-expanded', String(open)); });
  $('sidebar-overlay').addEventListener('click', closeMenu);
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && !$('action-dialog').open) closeMenu(); });
  function resetData() {
    for (const resource of ['members', 'rooms']) {
      const data = state[resource]; data.controller?.abort(); data.revision++; data.data = []; data.loaded = false; data.loading = false; data.error = ''; data.page = 1;
    }
    state.rooms.selected.clear(); renderMembers(); renderRooms();
  }
  let settingsController = null;
  $('settings-form').addEventListener('submit', async event => {
    event.preventDefault();
    const submit = event.submitter || $('settings-form').querySelector('[type="submit"]');
    let saved = false;
    try {
      API.configure({ baseURL: $('base-url').value, accessToken: $('access-token').value });
      $('base-url').value = API.getConfig().baseURL;
      saved = true;
      settingsController?.abort(); settingsController = new AbortController();
      const revision = ++state.connectionRevision;
      resetData(); setConnection('waiting'); submit.disabled = true; $('clear-token').disabled = true;
      $('settings-feedback').innerHTML = '<span class="spinner" aria-hidden="true"></span><span class="text-secondary">Đã lưu cấu hình. Đang kiểm tra API…</span>';
      const members = await API.getMembers({ page: 1, limit: state.members.limit, signal: settingsController.signal });
      if (revision !== state.connectionRevision) return;
      state.members.data = members; state.members.loaded = true; renderMembers(); setConnection('online');
      $('settings-feedback').innerHTML = `<span class="success-inline">${icon('check')} Đã lưu cấu hình và kết nối thành công.</span>`;
      toast('Đã kết nối backend thành công.');
    } catch (error) {
      if (error.name === 'AbortError') return;
      if (saved) setConnection('offline');
      $('settings-feedback').innerHTML = `<span class="error-inline">${escape(saved ? 'Đã lưu cấu hình nhưng chưa kết nối được.\n' : '')}${escape(error.message)}</span>`;
    } finally { submit.disabled = false; $('clear-token').disabled = false; }
  });
  $('clear-token').addEventListener('click', () => {
    API.configure({ ...API.getConfig(), accessToken: '' }); $('access-token').value = '';
    state.connectionRevision++; settingsController?.abort(); resetData(); setConnection('idle');
    $('settings-feedback').textContent = 'Đã xóa token của phiên hiện tại.'; toast('Đã xóa access token.');
  });
  window.addEventListener('hashchange', navigate);
  renderRooms(); navigate();
  if (location.protocol === 'file:') toast('Hãy chạy giao diện qua HTTP: python -m http.server 5500 rồi mở http://localhost:5500.', true);
})();
