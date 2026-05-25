# Para build: .\scripts\sync_windows_app_icon.ps1  (app_icon.png -> .ico)
# Pastaj: flutter build windows --release
# Pastaj: ky skript (app_config + Inno)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'sync_windows_app_icon.ps1')

$configSrc = Join-Path $root 'release\app_config.json'
$configExample = Join-Path $root 'release\app_config.example.json'
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'

if (-not (Test-Path $configSrc)) {
    if (-not (Test-Path $configExample)) {
        Write-Error "Mungon release\app_config.json. Kopjoni nga release\app_config.example.json dhe vendosni apiBaseUrl."
    }
    Copy-Item $configExample $configSrc
    Write-Host "Krijoi release\app_config.json nga shembulli — ndryshoni apiBaseUrl para installer-it!"
}

if (-not (Test-Path $releaseDir)) {
    Write-Error "Mungon $releaseDir — ekzekutoni: flutter build windows --release"
}

Copy-Item $configSrc (Join-Path $releaseDir 'app_config.json') -Force
Write-Host "OK: app_config.json -> $releaseDir"
Write-Host "Tani kompiloni installers\urimi_script.iss (ose windows\installer\pos_system.iss) në Inno Setup."
