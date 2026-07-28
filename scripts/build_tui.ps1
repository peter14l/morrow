# build_tui.ps1
# Interactive Build & Deployment TUI for Oasis

# Dynamically resolve root directory based on script location
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SCRIPT_DIR) {
    $SCRIPT_DIR = Join-Path (Get-Location) "scripts"
}
$ROOT_DIR = Split-Path -Parent $SCRIPT_DIR
$ENV_FILE = Join-Path $ROOT_DIR ".env"
$PUBLISH_DIR = Join-Path $ROOT_DIR "build/web"
$APP_NAME = "Oasis"

function Write-Header($text) {
    Clear-Host
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║  $($text.PadRight(52))║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
}

function Write-Success($text) {
    Write-Host "  [✔] $text" -ForegroundColor Green
}

function Write-Fail($text) {
    Write-Host "  [✘] $text" -ForegroundColor Red
}

function Write-Step($text) {
    Write-Host "  [►] $text" -ForegroundColor Yellow
}

# Helper to run script blocks inside the project root folder
function Invoke-In-Root {
    param($ScriptBlock)
    $origDir = Get-Location
    try {
        Set-Location $ROOT_DIR
        & $ScriptBlock
        return $LASTEXITCODE
    } finally {
        Set-Location $origDir
    }
}

function Stop-BuildProcesses {
    Write-Step "Cleaning up stale build processes..."
    $processes = @("java", "dart", "flutter")
    foreach ($p in $processes) {
        $found = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($found) {
            Write-Host "  ► Terminating $($found.Count) $p processes..." -ForegroundColor DarkGray
            Stop-Process -Name $p -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Success "Stale build processes terminated."
}

function Check-EnvFile {
    if (-not (Test-Path $ENV_FILE)) {
        Write-Fail ".env file missing at: $ENV_FILE"
        return $false
    }
    Write-Success ".env file found."
    return $true
}

function Check-Command($cmdName) {
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Fail "$cmdName is not installed or not in PATH!"
        return $false
    }
    return $true
}

function Run-BuildWeb {
    if (-not (Check-EnvFile)) { return 1 }
    if (-not (Check-Command "flutter")) { return 1 }
    
    Write-Step "Building Flutter Web release..."
    $exitCode = Invoke-In-Root {
        & flutter build web --release --dart-define-from-file=$ENV_FILE
    }
    if ($exitCode -eq 0) {
        Write-Success "Web build completed successfully. Output at: $PUBLISH_DIR"
        return 0
    } else {
        Write-Fail "Web build failed with exit code $exitCode"
        return $exitCode
    }
}

function Run-DeployNetlify {
    if (-not (Test-Path $PUBLISH_DIR)) {
        Write-Fail "Web build output directory '$PUBLISH_DIR' not found! Build web first."
        return 1
    }
    if (-not (Check-Command "netlify")) { return 1 }

    Write-Step "Deploying build/web to Netlify..."
    $exitCode = Invoke-In-Root {
        & netlify deploy --prod --dir=$PUBLISH_DIR
    }
    if ($exitCode -eq 0) {
        Write-Success "Successfully deployed to Netlify production!"
        return 0
    } else {
        Write-Fail "Netlify deployment failed with exit code $exitCode"
        return $exitCode
    }
}

function Run-BuildAndroid {
    if (-not (Check-EnvFile)) { return }
    if (-not (Check-Command "flutter")) { return }

    Write-Step "Building Android APK release..."
    $exitCode = Invoke-In-Root {
        & flutter build apk --release --split-per-abi --no-pub --dart-define-from-file=$ENV_FILE
    }
    if ($exitCode -eq 0) {
        Write-Success "Android build completed successfully."
    } else {
        Write-Fail "Android build failed with exit code $exitCode"
    }
}

function Run-BuildWindows {
    if (-not (Check-EnvFile)) { return }
    if (-not (Check-Command "flutter")) { return }

    Write-Step "Building Windows Release..."
    $exitCode = Invoke-In-Root {
        & flutter build windows --release --no-pub --dart-define-from-file=$ENV_FILE
    }
    if ($exitCode -eq 0) {
        Write-Success "Windows build completed successfully."
        
        Write-Step "Do you want to package it as MSIX? (y/n)"
        $packageAns = Read-Host "Choice"
        if ($packageAns -eq 'y' -or $packageAns -eq 'yes') {
            Write-Step "Creating MSIX package..."
            $msixExit = Invoke-In-Root {
                & dart run msix:create --build-windows false
            }
            if ($msixExit -eq 0) {
                Write-Success "MSIX package created successfully!"
            } else {
                Write-Fail "MSIX creation failed."
            }
        }
    } else {
        Write-Fail "Windows build failed with exit code $exitCode"
    }
}

function Show-Menu {
    Write-Header "OASIS BUILD PIPELINE TUI"
    Write-Host "  Project Root: $ROOT_DIR" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Clean Workspace (flutter clean)"
    Write-Host "  [2] Resolve Dependencies (flutter pub get)"
    Write-Host "  [3] Build Web Release"
    Write-Host "  [4] Deploy Web to Netlify"
    Write-Host "  [5] Full Web Pipeline (Build + Deploy)"
    Write-Host "  [6] Build Android APK"
    Write-Host "  [7] Build Windows Release (+ optional MSIX)"
    Write-Host "  [8] Stop stale build processes (java, dart, flutter)"
    Write-Host "  [0] Exit"
    Write-Host " ════════════════════════════════════════════════════════" -ForegroundColor DarkGray
}

do {
    Show-Menu
    $choice = Read-Host "  Select an option [0-8]"
    Write-Host ""
    
    switch ($choice) {
        "1" {
            if (Check-Command "flutter") {
                Write-Step "Cleaning workspace..."
                Invoke-In-Root { & flutter clean }
            }
        }
        "2" {
            if (Check-Command "flutter") {
                Write-Step "Resolving dependencies..."
                Invoke-In-Root { & flutter pub get }
            }
        }
        "3" {
            $null = Run-BuildWeb
        }
        "4" {
            $null = Run-DeployNetlify
        }
        "5" {
            $buildExit = Run-BuildWeb
            if ($buildExit -eq 0) {
                $null = Run-DeployNetlify
            }
        }
        "6" {
            Run-BuildAndroid
        }
        "7" {
            Run-BuildWindows
        }
        "8" {
            Stop-BuildProcesses
        }
        "0" {
            Write-Host "  Goodbye!`n" -ForegroundColor Cyan
            break
        }
        default {
            Write-Fail "Invalid option! Press enter to try again."
        }
    }
    
    if ($choice -ne "0") {
        Write-Host "`n  Press ENTER to return to the menu..."
        $null = Read-Host
    }
} while ($choice -ne "0")
