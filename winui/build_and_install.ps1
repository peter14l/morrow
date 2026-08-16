# Self-contained build, sign, trust, install, and run script for Oasis WinUI

$ProjectRoot = Get-Item -Path $PSScriptRoot
$CsprojPath = Join-Path $ProjectRoot "src\Oasis.WinUI\Oasis.WinUI.csproj"
$PfxPath = Join-Path $ProjectRoot "src\Oasis.WinUI\Oasis.WinUI_TemporaryKey.pfx"

# 1. Terminate any running instances of Oasis WinUI to release file locks
Write-Host "Killing any running instances of Oasis.WinUI..." -ForegroundColor Yellow
Stop-Process -Name "Oasis.WinUI" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# 2. Clean and Publish to generate MSIX package
Write-Host "Cleaning and building WinUI project..." -ForegroundColor Cyan
dotnet build $CsprojPath -c Release -r win-x64 -p:GenerateAppxPackageOnBuild=true

# 3. Dynamically locate the built MSIX file
$AppPackagesDir = Join-Path $ProjectRoot "src\Oasis.WinUI\AppPackages"
$MsixPath = Get-ChildItem -Path $AppPackagesDir -Filter *.msix -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

if (-not $MsixPath) {
    Write-Error "Could not find the generated MSIX package in $AppPackagesDir."
    exit 1
}
Write-Host "Found MSIX package at: $MsixPath" -ForegroundColor Green

# 4. Locate Signtool
Write-Host "Locating signtool.exe..." -ForegroundColor Cyan
$signtool = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits" -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $signtool) {
    $signtool = "signtool" # Fallback to PATH
}
Write-Host "Using signtool at: $signtool" -ForegroundColor Green

# 5. Trust the Self-Signed Certificate
Write-Host "Trusting certificate in Local Machine store..." -ForegroundColor Cyan
$password = ConvertTo-SecureString "oasis" -AsPlainText -Force
$importedCert = Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation Cert:\LocalMachine\Root -Password $password
Write-Host "Imported Certificate: $($importedCert.Subject) ($($importedCert.Thumbprint))" -ForegroundColor Green

# 6. Sign the MSIX package
Write-Host "Signing MSIX package..." -ForegroundColor Cyan
& $signtool sign /fd SHA256 /f $PfxPath /p "oasis" $MsixPath

# 7. Uninstall old versions if they exist to avoid identity-content collision conflicts
Write-Host "Checking for and removing existing app packages..." -ForegroundColor Cyan
$apps = Get-AppxPackage -Name "NoteSpark.OasisApp"
if ($apps) {
    foreach ($app in $apps) {
        Write-Host "Uninstalling current installation: $($app.PackageFullName)" -ForegroundColor Yellow
        Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
    }
}

# 8. Install the new MSIX
Write-Host "Installing the new MSIX package..." -ForegroundColor Cyan
Add-AppxPackage -Path $MsixPath

# 9. Launch the app
Write-Host "Launching Oasis WinUI..." -ForegroundColor Green
$newApp = Get-AppxPackage -Name "NoteSpark.OasisApp" | Select-Object -First 1
if ($newApp) {
    $appFamilyName = $newApp.PackageFamilyName
    explorer.exe "shell:AppsFolder\$($appFamilyName)!App"
} else {
    Write-Error "App package is not registered after installation."
}
