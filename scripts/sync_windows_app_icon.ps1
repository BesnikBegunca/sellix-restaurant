# Konverton assets\images\app_icon.png -> .ico për Windows (exe + installer).
# Ekzekuto para: flutter run -d windows  ose  flutter build windows --release

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$pngSrc = Join-Path $root 'assets\images\app_icon.png'
$icoAssets = Join-Path $root 'assets\images\app_icon.ico'
$icoRunner = Join-Path $root 'windows\runner\resources\app_icon.ico'

if (-not (Test-Path $pngSrc)) {
    Write-Error "Mungon $pngSrc"
}

Add-Type -AssemblyName System.Drawing

function Convert-PngToIco {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )
    $bmp = [System.Drawing.Bitmap]::FromFile($PngPath)
    try {
        $size = [Math]::Min($bmp.Width, $bmp.Height)
        if ($size -gt 256) { $size = 256 }
        $resized = New-Object System.Drawing.Bitmap($bmp, $size, $size)
        try {
            $hIcon = $resized.GetHicon()
            $icon = [System.Drawing.Icon]::FromHandle($hIcon)
            try {
                $dir = Split-Path $IcoPath -Parent
                if (-not (Test-Path $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
                $fs = [System.IO.File]::Create($IcoPath)
                try {
                    $icon.Save($fs)
                } finally {
                    $fs.Close()
                }
            } finally {
                $icon.Dispose()
            }
        } finally {
            $resized.Dispose()
        }
    } finally {
        $bmp.Dispose()
    }
}

Convert-PngToIco -PngPath $pngSrc -IcoPath $icoAssets
Convert-PngToIco -PngPath $pngSrc -IcoPath $icoRunner

Write-Host "OK: $pngSrc -> $icoAssets"
Write-Host "OK: $pngSrc -> $icoRunner"
Write-Host "Runner.rc perdor app_icon.ico. Pastaj: flutter clean; flutter run -d windows"
