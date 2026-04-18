param(
    [string]$GodotExe = "godot",
    [string]$CMakePreset = "windows-vs2026",
    [string]$ExportPreset = "Windows Desktop",
    [string]$AppName = "Wouldyou Spatial Composer.exe"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$godotProjectDir = Join-Path $repoRoot "apps\gesture_tool_godot"
$exportDir = Join-Path $repoRoot "build\windows-app"
$appPath = Join-Path $exportDir $AppName

Write-Host "Configuring native renderer with preset $CMakePreset..."
cmake --preset $CMakePreset
cmake --build --preset $CMakePreset

$rendererCandidates = @(
    (Join-Path $repoRoot "build\windows-vs2026\apps\spatial_preview_cli\Release\spatial_preview_cli.exe"),
    (Join-Path $repoRoot "build\windows-ninja\apps\spatial_preview_cli\spatial_preview_cli.exe"),
    (Join-Path $repoRoot "build\windows-msvc\apps\spatial_preview_cli\Release\spatial_preview_cli.exe")
)

$rendererExe = $rendererCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $rendererExe) {
    throw "Could not find spatial_preview_cli.exe after build."
}

$rendererDir = Split-Path -Parent $rendererExe
$phononDll = Join-Path $rendererDir "phonon.dll"

New-Item -ItemType Directory -Force -Path $exportDir | Out-Null

Write-Host "Exporting Godot app to $appPath ..."
& $GodotExe --headless --path $godotProjectDir --export-release $ExportPreset $appPath

if (-not (Test-Path $appPath)) {
    throw "Godot export did not create $appPath"
}

Write-Host "Copying native renderer next to exported app..."
Copy-Item $rendererExe (Join-Path $exportDir "spatial_preview_cli.exe") -Force

if (Test-Path $phononDll) {
    Copy-Item $phononDll (Join-Path $exportDir "phonon.dll") -Force
}

Write-Host "Packaged standalone app in $exportDir"
