# Ekzekutoni NJË HERË nga rrënja e projektit:
#   .\scripts\setup_git_hooks.ps1
#
# 1) Pas çdo checkout/branch switch → flutter pub get (rigjeneron plugin files)
# 2) Git nuk ju shqetëson më me "modified" në skedarët e gjeneruar (skip-worktree)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
    Write-Error 'Ekzekutoni nga rrënja e projektit (ku është pubspec.yaml).'
}

$hooksDir = Join-Path $root '.git\hooks'
if (-not (Test-Path $hooksDir)) {
    Write-Error 'Mungon .git\hooks — projekti duhet të jetë git clone.'
}

# --- post-checkout: pas ndërrimit të branch-it ---
$postCheckout = @'
#!/bin/sh
# Rigjeneron skedarët Flutter pas checkout (branch switch, pull, etj.)
if command -v flutter >/dev/null 2>&1; then
  flutter pub get >/dev/null 2>&1 || true
fi
'@

$postCheckout | Set-Content -Path (Join-Path $hooksDir 'post-checkout') -Encoding ASCII -NoNewline
# Git hooks duhen LF
$content = [IO.File]::ReadAllText((Join-Path $hooksDir 'post-checkout'))
$content = $content -replace "`r`n", "`n"
[IO.File]::WriteAllText((Join-Path $hooksDir 'post-checkout'), $content)

Write-Host 'OK: post-checkout hook (flutter pub get pas nderrimit te branch-it)'

# --- skip-worktree: fsheh "modified" lokale ne generated (vetem te juaja) ---
$generated = @(
    'linux/flutter/generated_plugin_registrant.cc',
    'linux/flutter/generated_plugins.cmake',
    'macos/Flutter/GeneratedPluginRegistrant.swift',
    'windows/flutter/generated_plugin_registrant.cc',
    'windows/flutter/generated_plugins.cmake'
)

Push-Location $root
foreach ($f in $generated) {
    if (Test-Path $f) {
        git update-index --skip-worktree $f 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Host "skip-worktree: $f" }
    }
}
Pop-Location

Write-Host ''
Write-Host 'Gati. Kur nderroni branch, hook ben flutter pub get automatikisht.'
Write-Host 'Per te commit-uar ndryshime ne generated (rralle): .\scripts\unskip_generated.ps1'
