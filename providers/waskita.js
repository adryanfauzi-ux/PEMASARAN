// Provider: PT Waskita Karya — We-Proc (platform Virkea).
// Login token (X-Username/X-User-Token) lalu ambil daftar pengumuman.
'use strict';

const API = 'https://api-eproc.waskita.co.id:8443/api';
const meta = { id: 'waskita', name: 'Waskita', color: '#7c3aed' };

async function login(username, password) {
  const res = await fetch(`${API}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'User-Agent': 'Mozilla/5.0' },
    body: JSON.stringify({ data: { login: username, password, remember_me: false } }),
  });
  const json = await res.json().catch(() => null);
  if (res.ok && json?.data?.authn_token) {
    return { ok: true, token: json.data.authn_token, username: json.data.username, name: json.data.full_name };
  }
  const msg = json?.error?.message || json?.message || `Login gagal (HTTP ${res.status})`;
  return { ok: false, message: msg };
}

function mapItem(it) {
  return {
    source: meta.name,
    id: it.id,
    number: it.number || null,
    nama: it.name || '(tanpa nama)',
    kategori: it.prcmt_type_name || '—',
    hps: it.est_total != null && it.est_total !== '' ? Number(it.est_total) : null,
    start: it.opening_date || it.prcmt_from_time || it.announced_at || null,
    end: it.closing_date || it.prcmt_thru_time || null,
    location: it.prcmt_location || null,
    scopeOfWork: it.scope_of_work || null,
    tenderType: it.prcmt_type_name || null,
    state: it.state || null,
    participantState: it.prcmt_participant_state || null,
    extra: {
      buyer: it.purch_org_full_name || null,
      visibility: it.prcmt_type_visibility || null,
      evalMethod: it.eval_method || null,
      bidMethod: it.bid_submission_method || null,
      announcedAt: it.announced_at || null,
      registrationOpen: it.registration_open,
    },
  };
}

async function fetchTenders(cfg) {
  const user = cfg?.username, pass = cfg?.password;
  if (!user || !pass) {
    return { meta, rows: [], login: { attempted: false, ok: false, message: 'Kredensial Waskita belum diisi di .env' } };
  }
  const auth = await login(user, pass);
  if (!auth.ok) {
    return { meta, rows: [], login: { attempted: true, ok: false, message: auth.message } };
  }
  const headers = { 'X-Username': auth.username, 'X-User-Token': auth.token, Accept: 'application/json', 'User-Agent': 'Mozilla/5.0' };
  const res = await fetch(`${API}/prcmt/prcmt_announcements/index_participation?per_page=200`, { headers });
  if (!res.ok) {
    return { meta, rows: [], login: { attempted: true, ok: true, message: `Login OK, tapi gagal ambil data (HTTP ${res.status})` } };
  }
  const json = await res.json();
  const items = json?.data?.items || [];
  return {
    meta,
    rows: items.map(mapItem),
    login: { attempted: true, ok: true, message: `Login OK sebagai ${auth.name} (${items.length} pengumuman)` },
  };
}

module.exports = { meta, fetchTenders };
