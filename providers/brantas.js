// Provider: PT Brantas Abipraya — RUP (Rencana Umum Pengadaan), publik.
'use strict';

const BASE = 'https://eproc.brantas-abipraya.co.id';
const stripTags = (s) => s.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&nbsp;/g, ' ').trim();

function parseHps(raw) {
  if (!raw) return null;
  const n = Number(String(raw).trim().replace(/\./g, '').replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

class Jar {
  constructor() { this.c = new Map(); }
  store(res) {
    for (const sc of res.headers.getSetCookie?.() || []) {
      const [pair] = sc.split(';'); const i = pair.indexOf('=');
      if (i > 0) this.c.set(pair.slice(0, i).trim(), pair.slice(i + 1).trim());
    }
  }
  header() { return [...this.c].map(([k, v]) => `${k}=${v}`).join('; '); }
}

const meta = { id: 'brantas', name: 'Brantas Abipraya', color: '#0b5ed7' };

async function fetchTenders() {
  const jar = new Jar();
  const res = await fetch(`${BASE}/rup-v2`, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  jar.store(res);
  const html = await res.text();

  const tbody = (html.match(/<tbody>[\s\S]*?<\/tbody>/) || [''])[0];
  const rows = [];
  for (const tr of tbody.matchAll(/<tr>([\s\S]*?)<\/tr>/g)) {
    const tds = [...tr[1].matchAll(/<td[^>]*>([\s\S]*?)<\/td>/g)].map((m) => m[1]);
    if (tds.length < 4) continue;
    const range = stripTags(tds[0]);
    const dates = range.match(/\d{4}-\d{2}-\d{2}/g) || [];
    rows.push({
      source: meta.name,
      id: (tds[1].match(/data-id="([^"]*)"/) || [])[1] || null,
      number: null,
      nama: stripTags(tds[1]),
      kategori: stripTags(tds[3]),
      hps: parseHps(stripTags(tds[2])),
      start: dates[0] || null,
      end: dates[1] || null,
      location: null,
      scopeOfWork: null,
      tenderType: 'RUP',
      state: null,
      participantState: null,
      extra: { rentang: range },
    });
  }
  return { meta, rows, login: { attempted: false, ok: false, message: 'RUP publik (tanpa login)' } };
}

module.exports = { meta, fetchTenders };
