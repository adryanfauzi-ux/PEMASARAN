// Web server Pengumuman Tender — agregator multi-portal e-Proc.
// Tanpa dependency eksternal (Node 18+: fetch bawaan).
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
loadEnv(path.join(ROOT, '.env'));

const PORT = Number(process.env.PORT || 3000);
// Di platform hosting (Railway/Render/dll) wajib bind ke 0.0.0.0 agar dapat dijangkau proxy.
const HOST = process.env.HOST || '0.0.0.0';
const CACHE_MINUTES = Number(process.env.CACHE_MINUTES || 30);
const DATA_DIR = path.join(ROOT, 'data');
const PUBLIC_DIR = path.join(ROOT, 'public');

const brantas = require('./providers/brantas');
const waskita = require('./providers/waskita');

// Konfigurasi tiap provider (kredensial dari .env)
const PROVIDERS = [
  { mod: brantas, cfg: {} },
  { mod: waskita, cfg: { username: process.env.WASKITA_USERNAME, password: process.env.WASKITA_PASSWORD } },
];

let cache = null;
let inflight = null;

function loadEnv(file) {
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/i);
    if (m && !line.trim().startsWith('#') && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
    }
  }
}

const localDate = (d = new Date()) => {
  const p = (x) => String(x).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
};

async function collect() {
  const results = await Promise.allSettled(
    PROVIDERS.map((p) => p.mod.fetchTenders(p.cfg))
  );

  const sources = [];
  let rows = [];
  results.forEach((r, i) => {
    const meta = PROVIDERS[i].mod.meta;
    if (r.status === 'fulfilled') {
      rows = rows.concat(r.value.rows);
      sources.push({ id: meta.id, name: meta.name, color: meta.color, count: r.value.rows.length, login: r.value.login });
    } else {
      sources.push({ id: meta.id, name: meta.name, color: meta.color, count: 0, login: { ok: false, message: 'Error: ' + r.reason.message } });
    }
  });

  const categories = [...new Set(rows.map((x) => x.kategori).filter(Boolean))].sort().map((n) => ({ id: n, name: n }));

  const payload = {
    generatedAt: new Date().toISOString(),
    today: localDate(),
    sources,
    categories,
    rows,
  };
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(path.join(DATA_DIR, 'tender-latest.json'), JSON.stringify(payload, null, 2));
  return payload;
}

async function getData(force = false) {
  const fresh = cache && (Date.now() - Date.parse(cache.generatedAt)) < CACHE_MINUTES * 60e3;
  if (!force && fresh) return cache;
  if (!inflight) {
    inflight = collect().then((p) => (cache = p)).finally(() => { inflight = null; });
  }
  return inflight;
}

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };
function sendJson(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  try {
    if (url.pathname === '/api/tenders' && req.method === 'GET') {
      return sendJson(res, 200, await getData(url.searchParams.get('refresh') === '1'));
    }
    if (url.pathname === '/api/health') return sendJson(res, 200, { ok: true });

    const rel = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname).replace(/^\/+/, '');
    const file = path.normalize(path.join(PUBLIC_DIR, rel));
    if (!file.startsWith(PUBLIC_DIR) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end('Not found');
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  } catch (e) {
    console.error(e);
    sendJson(res, 502, { error: 'Gagal mengambil data: ' + e.message });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Pengumuman Tender berjalan di http://localhost:${PORT}`);
  getData().then((p) => {
    console.log(`Total ${p.rows.length} pengumuman dari ${p.sources.length} portal:`);
    p.sources.forEach((s) => console.log(`  - ${s.name}: ${s.count} (${s.login.message})`));
  }).catch((e) => console.error('Scrape awal gagal:', e.message));
});
