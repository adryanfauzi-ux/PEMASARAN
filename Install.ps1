<#
.SYNOPSIS
    Memasang web app Pengumuman Tender: memastikan Node.js, membuat .env,
    serta shortcut di Desktop dan Start Menu.
.PARAMETER AutoStart
    Juga jalankan server otomatis saat login Windows.
#>
param([switch]$AutoStart)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Node.js
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host 'Node.js belum ada, memasang via winget...' -ForegroundColor Cyan
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements --scope user
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}
Write-Host ("Node.js: " + (node -v)) -ForegroundColor Green

# 2. .env
$envFile = Join-Path $Root '.env'
if (-not (Test-Path $envFile)) { Copy-Item (Join-Path $Root '.env.example') $envFile; Write-Host 'Dibuat .env (isi kredensial bila perlu)' }

# 3. Shortcut
$shell = New-Object -ComObject WScript.Shell
$targets = @(
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path ([Environment]::GetFolderPath('Programs')) '')
)
foreach ($dir in $targets) {
    $lnk = $shell.CreateShortcut((Join-Path $dir 'Pengumuman Tender.lnk'))
    $lnk.TargetPath = Join-Path $Root 'Start-App.cmd'
    $lnk.WorkingDirectory = $Root
    $lnk.WindowStyle = 7
    $lnk.IconLocation = "$env:SystemRoot\System32\shell32.dll,13"
    $lnk.Description = 'Pengumuman Tender - Brantas Abipraya e-Proc'
    $lnk.Save()
    Write-Host "Shortcut dibuat: $dir" -ForegroundColor Green
}

# 4. Auto-start (opsional)
if ($AutoStart) {
    $startup = [Environment]::GetFolderPath('Startup')
    $lnk = $shell.CreateShortcut((Join-Path $startup 'Pengumuman Tender Server.lnk'))
    $lnk.TargetPath = (Get-Command node).Source
    $lnk.Arguments = "`"$(Join-Path $Root 'server.js')`""
    $lnk.WorkingDirectory = $Root
    $lnk.WindowStyle = 7
    $lnk.Save()
    Write-Host 'Server akan berjalan otomatis saat login Windows.' -ForegroundColor Green
}

Write-Host "`nSelesai. Buka 'Pengumuman Tender' dari Desktop, atau http://localhost:3000" -ForegroundColor Green
