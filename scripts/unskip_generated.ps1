# Hiq skip-worktree para commit-it te ndryshimeve ne plugin generated / pubspec.lock

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
    $root = $PSScriptRoot
}

$files = @(
    'linux/flutter/generated_plugin_registrant.cc',
    'linux/flutter/generated_plugins.cmake',
    'macos/Flutter/GeneratedPluginRegistrant.swift',
    'windows/flutter/generated_plugin_registrant.cc',
    'windows/flutter/generated_plugins.cmake',
    'pubspec.lock'
)

Push-Location $root
foreach ($f in $files) {
    git update-index --no-skip-worktree $f 2>$null
}
Pop-Location
Write-Host 'skip-worktree u hoq. git status tani tregon ndryshimet reale.'
