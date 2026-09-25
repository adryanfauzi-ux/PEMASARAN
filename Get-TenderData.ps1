<#
.SYNOPSIS
    Menarik data Pengumuman Tender (RUP - Rencana Umum Pengadaan) dari portal
    e-Procurement PT Brantas Abipraya dan menghasilkan dashboard HTML.

.DESCRIPTION
    Data RUP di /rup-v2 bersifat PUBLIK dan tidak memerlukan login.
    Skrip ini mengambil daftar paket (tanggal, nama, HPS, kategori), lalu
    menyuntikkannya ke template menjadi 'tender-dashboard.html' (standalone).

    Jika -Username/-Password diberikan, skrip mencoba login dan menarik
    detail tiap paket (/rup/detail/{id}). Bila login gagal, data publik
    tetap dihasilkan (degradasi mulus).

.EXAMPLE
    .\Get-TenderData.ps1
    Menarik data publik dan membuka dashboard.

.EXAMPLE
    .\Get-TenderData.ps1 -Username vm_pthakaaston -Password 'kata-sandi-benar'
    Menarik data + detail paket (butuh akun DRT yang valid).
#>
[CmdletBinding()]
param(
    [string]$Username,
    [string]$Password,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Base = 'https://eproc.brantas-abipraya.co.id'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $Root 'assets\dashboard-template.html'
$OutHtml = Join-Path $Root 'tender-dashboard.html'
$DataDir = Join-Path $Root 'data'
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }

function Write-Step($m){ Write-Host "  $m" -ForegroundColor Cyan }

# ---------- helpers ----------
function Convert-Hps([string]$raw){
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $s = $raw.Trim()
    # Indonesian format: '.' thousands, ',' decimal -> normalize to invariant
    $s = $s -replace '\.', '' -replace ',', '.'
    $out = 0.0
    if ([double]::TryParse($s, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$out)) { return $out }
    return $null
}

function Split-Range([string]$raw){
    # "2026-09-21 s.d. 2026-09-26"
    $start=$null; $end=$null
    if ($raw -match '(\d{4}-\d{2}-\d{2}).*?(\d{4}-\d{2}-\d{2})') {
        $start = $matches[1]; $end = $matches[2]
    } elseif ($raw -match '(\d{4}-\d{2}-\d{2})') {
        $start = $matches[1]
    }
    return @{ start=$start; end=$end; raw=$raw.Trim() }
}

# ---------- 1. fetch RUP list (public) ----------
Write-Host "`nMengambil data RUP publik dari $Base/rup-v2 ..." -ForegroundColor Green
$listResp = Invoke-WebRequest "$Base/rup-v2" -UseBasicParsing -SessionVariable session -TimeoutSec 60
$html = $listResp.Content

# categories map
$categories = @()
$catBlock = [regex]::Match($html, 'name="p_usaha_jenis_id".*?</select>', 'Singleline').Value
foreach ($m in [regex]::Matches($catBlock, '<option value="([^"]*)"[^>]*>([^<]*)</option>')) {
    $id = $m.Groups[1].Value.Trim(); $name = $m.Groups[2].Value.Trim()
    if ($id -ne '' -and $name -ne 'Semua Kategori') { $categories += [ordered]@{ id=$id; name=$name } }
}
Write-Step ("Kategori terdeteksi: " + $categories.Count)

# rows
$tableHtml = [regex]::Match($html, '<tbody>.*?</tbody>', 'Singleline').Value
$rowMatches = [regex]::Matches($tableHtml, '(?s)<tr>(.*?)</tr>')
$rows = @()
foreach ($rm in $rowMatches) {
    $tds = [regex]::Matches($rm.Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
    if ($tds.Count -lt 4) { continue }
    $rangeText = ($tds[0].Groups[1].Value -replace '<[^>]+>','').Trim()
    $nameCell  = $tds[1].Groups[1].Value
    $rupId = [regex]::Match($nameCell, 'data-id="([^"]*)"').Groups[1].Value
    $nama  = ([regex]::Replace($nameCell, '<[^>]+>','')).Trim()
    $hpsText = ($tds[2].Groups[1].Value -replace '<[^>]+>','').Trim()
    $kategori = ($tds[3].Groups[1].Value -replace '<[^>]+>','').Trim()
    $rng = Split-Range $rangeText
    $rows += [ordered]@{
        start    = $rng.start
        end      = $rng.end
        rentang  = $rng.raw
        nama     = $nama
        rupId    = $rupId
        hps      = (Convert-Hps $hpsText)
        hpsText  = $hpsText
        kategori = $kategori
        detailHtml = $null
    }
}
Write-Step ("Paket RUP ditemukan: " + $rows.Count)

# ---------- 2. optional login + detail ----------
$detailEnabled = $false
if ($Username -and $Password) {
    Write-Host "`nMencoba login sebagai '$Username' ..." -ForegroundColor Green
    try {
        $loginPage = Invoke-WebRequest "$Base/site/login" -UseBasicParsing -WebSession $session -TimeoutSec 60
        $csrf = [regex]::Match($loginPage.Content, 'name="csrf_eproc_frontend" value="([^"]*)"').Groups[1].Value
        $body = "csrf_eproc_frontend=$csrf&username=$([Uri]::EscapeDataString($Username))&password=$([Uri]::EscapeDataString($Password))"
        $login = Invoke-WebRequest "$Base/site/login-submit" -Method POST -WebSession $session -UseBasicParsing `
            -ContentType 'application/x-www-form-urlencoded' -Body $body `
            -Headers @{ 'X-Requested-With'='XMLHttpRequest'; 'Referer'="$Base/site/login" } -TimeoutSec 60
        $j = $null; try { $j = $login.Content | ConvertFrom-Json } catch {}
        if ($j -and ($j.status -eq 200 -or $j.status -eq 302)) {
            Write-Step "Login berhasil."
            $detailEnabled = $true
        } else {
            $msg = if ($j) { $j.message } else { "respons tidak dikenali" }
            Write-Host "  Login gagal: $msg" -ForegroundColor Yellow
            Write-Host "  -> Melanjutkan dengan data publik saja." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Login error: $($_.Exception.Message). Melanjutkan data publik." -ForegroundColor Yellow
    }

    if ($detailEnabled) {
        Write-Host "`nMenarik detail paket ..." -ForegroundColor Green
        foreach ($r in $rows) {
            if (-not $r.rupId) { continue }
            try {
                $dr = Invoke-WebRequest "$Base/rup/detail/$($r.rupId)" -UseBasicParsing -WebSession $session -TimeoutSec 60
                # detail returns HTML fragment when authenticated; guard against full-page redirect
                if ($dr.Content.Length -lt 20000 -and $dr.Content -notmatch '<html') {
                    $r.detailHtml = $dr.Content.Trim()
                    Write-Step ("Detail OK: " + $r.nama)
                }
            } catch { Write-Host "  Detail gagal ($($r.nama)): $($_.Exception.Message)" -ForegroundColor Yellow }
        }
    }
}

# ---------- 3. build payload ----------
$payload = [ordered]@{
    generatedAt   = (Get-Date).ToString('o')
    today         = (Get-Date).ToString('yyyy-MM-dd')
    source        = "$Base/rup-v2"
    detailEnabled = $detailEnabled
    categories    = $categories
    rows          = $rows
}
$json = $payload | ConvertTo-Json -Depth 6 -Compress
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$json | Set-Content -Path (Join-Path $DataDir "tender-$stamp.json") -Encoding UTF8
$json | Set-Content -Path (Join-Path $DataDir "tender-latest.json") -Encoding UTF8
Write-Step ("Data JSON disimpan: data\tender-latest.json")

# ---------- 4. render HTML ----------
if (-not (Test-Path $TemplatePath)) { throw "Template tidak ditemukan: $TemplatePath" }
$template = Get-Content -Path $TemplatePath -Raw
# Escape </script> inside JSON so the inline <script> block stays intact
$safeJson = $json -replace '</', '<\/'
$rendered = $template.Replace('/*__TENDER_JSON__*/', $safeJson)
$rendered | Set-Content -Path $OutHtml -Encoding UTF8
Write-Host "`nDashboard dibuat: $OutHtml" -ForegroundColor Green

if (-not $NoOpen) { Start-Process $OutHtml }
Write-Host "Selesai.`n" -ForegroundColor Green
