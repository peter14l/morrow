# Oasis Optimized Android Release Build Script (PowerShell)
# Enforces standard Dart compilation flags (--obfuscate, --split-debug-info) and R8 optimizations.

param(
    [switch]$Bundle = $false,
    [switch]$AnalyzeSize = $false
)

$ErrorActionPreference = "Stop"

$SymbolsDir = "build/app/outputs/symbols"
if (!(Test-Path $SymbolsDir)) {
    New-Item -ItemType Directory -Force -Path $SymbolsDir | Out-Null
}

$BuildCmd = "flutter"
$Args = @()

if ($Bundle) {
    $Args += "build", "appbundle"
} else {
    $Args += "build", "apk"
}

$Args += "--release"
$Args += "--obfuscate"
$Args += "--split-debug-info=$SymbolsDir"
$Args += "--tree-shake-icons"

if ($AnalyzeSize) {
    $Args += "--analyze-size"
    $Args += "--target-platform", "android-arm64"
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " Building Oasis for Android (Optimized Production) " -ForegroundColor Cyan
Write-Host " Flags: $($Args -join ' ')" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Cyan

& $BuildCmd @Args

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild completed successfully!" -ForegroundColor Green
    Write-Host "Debug symbols stored at: $SymbolsDir" -ForegroundColor Green
} else {
    Write-Host "`nBuild failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
