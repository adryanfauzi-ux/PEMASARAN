@echo off
REM Perbarui data pengumuman tender dan buka dashboard
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-TenderData.ps1"
if errorlevel 1 (
  echo.
  echo Terjadi kesalahan. Tekan tombol apa saja untuk menutup.
  pause >nul
)
