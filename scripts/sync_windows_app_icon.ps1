# Verifikon që iconpos.ico ekziston (Runner.rc e referencon drejtpërdrejt).
# Kopjon edhe në resources\app_icon.ico për mjete të vjetra CI.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$iconSrc = Join-Path $root 'assets\images\iconpos.ico'
$iconDest = Join-Path $root 'windows\runner\resources\app_icon.ico'

if (-not (Test-Path $iconSrc)) {
    Write-Error "Mungon $iconSrc"
}

$destDir = Split-Path $iconDest -Parent
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}
Copy-Item $iconSrc $iconDest -Force
Write-Host "OK: $iconSrc (Runner.rc -> assets\images\iconpos.ico)"
Write-Host "Pas ndryshimit te ikones: flutter clean && flutter run -d windows"
