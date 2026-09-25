# Pengumuman Tender — Agregator e-Proc

Web app lokal yang mengumpulkan **pengumuman tender** dari beberapa portal e-Procurement
tempat PT HAKAASTON terdaftar sebagai rekanan, lalu menampilkannya dalam satu dashboard.

## Portal yang didukung

| Portal | Sumber data | Akses |
|---|---|---|
| **Brantas Abipraya** | RUP (Rencana Umum Pengadaan) di `/rup-v2` | Publik |
| **Waskita** | We-Proc `prcmt_announcements` (tender diikuti/diundang) | Login (token) |

Menambah portal baru = tambah satu file di `providers/` lalu daftarkan di `server.js`.

## Instalasi (sekali saja)

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1            # pasang Node.js + shortcut
powershell -ExecutionPolicy Bypass -File .\Install.ps1 -AutoStart # + jalan otomatis saat login Windows
```

## Menjalankan

- Klik shortcut **Pengumuman Tender** (atau `Start-App.cmd`), atau
- `node server.js` lalu buka **http://localhost:3000**

## Konfigurasi (`.env`)

| Variabel | Fungsi |
|---|---|
| `WASKITA_USERNAME`, `WASKITA_PASSWORD` | Login Waskita We-Proc |
| `EPROC_USERNAME`, `EPROC_PASSWORD` | Brantas (opsional; RUP tetap tampil tanpa login) |
| `PORT` | Port web (default 3000) |
| `CACHE_MINUTES` | Lama cache data di server (default 30) |

Kredensial disimpan sebagai teks biasa di `.env` — **jangan dibagikan / di-commit**.

## Isi dashboard

- **KPI**: total pengumuman, sedang berlangsung, akan datang, jumlah portal
- **Filter**: pencarian (nama/nomor), sumber portal, kategori, status
- **Tabel**: sortir per kolom, badge sumber berwarna, format Rupiah, badge status + partisipasi
- **Detail** (modal): nomor, jenis tender, jadwal, lokasi, lingkup pekerjaan, buyer, dll.
- Responsif + mode terang/gelap

## API

- `GET /api/tenders` — data gabungan (cache) · `?refresh=1` — tarik ulang dari semua portal
- `GET /api/health`

## Struktur

```
server.js              # web server + agregator provider
providers/brantas.js   # RUP Brantas Abipraya (publik)
providers/waskita.js   # We-Proc Waskita (login token)
public/index.html      # dashboard
Install.ps1            # installer (Node.js + shortcut)
Start-App.cmd          # peluncur: nyalakan server + buka browser
data/tender-latest.json# snapshot data terakhir
```

## Keamanan

- Kredensial hanya disimpan di `.env` (di-`.gitignore`, tidak pernah di-commit).
- Data tender yang tertarik disimpan di `data/` (juga di-`.gitignore`) karena bersifat privat rekanan.
- Salin `.env.example` menjadi `.env` dan isi kredensial Anda sendiri untuk menjalankan.
