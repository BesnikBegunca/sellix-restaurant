# Rikthen skedarët e gjeneruar si në branch-in aktual (pas switch të ngatërruar)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

git restore linux/flutter/generated_plugin_registrant.cc `
    linux/flutter/generated_plugins.cmake `
    macos/Flutter/GeneratedPluginRegistrant.swift `
    windows/flutter/generated_plugin_registrant.cc `
    windows/flutter/generated_plugins.cmake `
    pubspec.lock 2>$null

flutter pub get | Out-Null
Pop-Location
Write-Host 'U pastruan skedarët e gjeneruar + flutter pub get.'
