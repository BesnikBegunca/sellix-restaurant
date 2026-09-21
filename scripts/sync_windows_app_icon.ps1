# Kopjon ikonën SelliX (.ico) te Windows runner. Mos e rigjenero nga PNG —
# PNG-ja e vjetër ishte filxhani, ikona e vërtetë është assets\images\app_icon.ico.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$icoAssets = Join-Path $root 'assets\images\app_icon.ico'
$icoRunner = Join-Path $root 'windows\runner\resources\app_icon.ico'

if (-not (Test-Path $icoAssets)) {
    Write-Error "Mungon $icoAssets"
}

$dir = Split-Path $icoRunner -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Copy-Item $icoAssets $icoRunner -Force
Write-Host "OK: $icoAssets -> $icoRunner"
Write-Host "Runner.rc perdor app_icon.ico. Pastaj: flutter build windows --release --no-tree-shake-icons"
