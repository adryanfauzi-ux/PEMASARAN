@echo off
REM Menjalankan web app Pengumuman Tender lalu membuka browser
cd /d "%~dp0"
set PORT=3000
powershell -NoProfile -Command "try { Invoke-WebRequest http://127.0.0.1:%PORT%/api/health -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  start "Pengumuman Tender Server" /min node "%~dp0server.js"
  timeout /t 3 /nobreak >nul
)
start "" http://localhost:%PORT%
