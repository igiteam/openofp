#!/usr/bin/env pwsh
# =========================================================
# engine_gitlfs.ps1
# Unified Git LFS tracking for multiple game engines
# =========================================================

param(
    [string]$Engine = "",
    [string]$DoPush = ""
)

# Enable strict error handling
$ErrorActionPreference = "Stop"

try {
    # ------------------ Supported engines ------------------
    $SupportedEngines = @("ue3", "goldsrc", "source", "idtech3", "idtech4", "cryengine1", "thiefdark", "sithengine")

    Write-Host "=== Git LFS Engine Setup ===" -ForegroundColor Cyan

    # ------------------ Interactive engine selection ------------------
    if ([string]::IsNullOrEmpty($Engine)) {
        Write-Host "Please select a game engine to track with Git LFS:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $SupportedEngines.Length; $i++) {
            Write-Host "  $($i+1). $($SupportedEngines[$i])" -ForegroundColor White
        }
        
        $choice = Read-Host "`nEnter number (1-$($SupportedEngines.Length))"
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $SupportedEngines.Length) {
            $Engine = $SupportedEngines[[int]$choice - 1]
            Write-Host "Selected engine: $Engine" -ForegroundColor Green
        } else {
            Write-Host "Invalid selection. Please run the script again." -ForegroundColor Red
            exit 1
        }
    }

    # Validate engine
    if ($SupportedEngines -notcontains $Engine) {
        Write-Host "Unsupported engine: $Engine" -ForegroundColor Red
        Write-Host "Supported engines: $($SupportedEngines -join ', ')" -ForegroundColor Yellow
        exit 1
    }

    # ----------------------- Check dependencies ------------------------
    Write-Host "`nChecking dependencies..." -ForegroundColor Cyan

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git not installed or not in PATH. Please install Git first."
    }

    if (-not (Get-Command git-lfs -ErrorAction SilentlyContinue)) {
        throw "Git LFS not found. Please install Git LFS from: https://git-lfs.github.com/"
    }

    # Check if we're in a git repository
    $gitCheck = git rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not a git repository. Please run this script from within a git repository."
    }

    Write-Host "All dependencies found." -ForegroundColor Green

    # ----------------------- Initialize Git LFS -----------------------
    Write-Host "`nInitializing Git LFS..." -ForegroundColor Cyan
    git lfs install --force

    # ----------------------- Define patterns -----------------------
    $EnginePatterns = @{
        ue3 = @("*.uasset", "*.umap", "*.upk", "*.uexp", "*.ubulk", "*.uptnl", "*.pak", "*.exe", "*.dll", "*.zip")
        goldsrc = @("*.wad", "*.bsp", "*.mdl", "*.spr", "*.wav", "*.mp3")
        source = @("*.vtf", "*.vmt", "*.vmf", "*.mdl", "*.vtx", "*.vvd", "*.phy")
        idtech3 = @("*.pk3", "*.bsp", "*.md3", "*.wav", "*.tga")
        idtech4 = @("*.pk4", "*.bimage", "*.mtr", "*.wav")
        cryengine1 = @("*.cgf", "*.chr", "*.dds", "*.mtl", "*.caf")
        thiefdark = @("*.mis", "*.gam", "*.bin", "*.crf")
        sithengine = @("*.3do", "*.anm", "*.bm", "*.cmp")
    }

    # ----------------------- Scan for large files -----------------------
    Write-Host "Scanning for large files (>10MB)..." -ForegroundColor Cyan
    $largeFiles = Get-ChildItem -Recurse -File | Where-Object { $_.Length -gt 10MB } | Select-Object -First 10
    if ($largeFiles) {
        Write-Host "Large files found:" -ForegroundColor Yellow
        $largeFiles | ForEach-Object {
            Write-Host "  $($_.Name) - $([math]::Round($_.Length/1MB, 2)) MB" -ForegroundColor Gray
        }
    } else {
        Write-Host "No files larger than 10MB found." -ForegroundColor Green
    }

    # ----------------------- Apply LFS tracking -----------------------
    Write-Host "`nSetting up LFS tracking for $Engine..." -ForegroundColor Cyan
    
    $patterns = $EnginePatterns[$Engine]
    if (-not $patterns) {
        throw "No patterns defined for engine: $Engine"
    }

    # Backup existing .gitattributes
    if (Test-Path ".gitattributes") {
        $backupName = ".gitattributes.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item ".gitattributes" $backupName
        Write-Host "Backed up .gitattributes to $backupName" -ForegroundColor Yellow
    }

    # Track each pattern
    foreach ($pattern in $patterns) {
        Write-Host "  Tracking: $pattern" -ForegroundColor Gray
        git lfs track $pattern
    }

    # ----------------------- Show results -----------------------
    Write-Host "`nCurrent .gitattributes:" -ForegroundColor Cyan
    if (Test-Path ".gitattributes") {
        Get-Content ".gitattributes" | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }

    # ----------------------- Commit changes -----------------------
    Write-Host "`nCommitting changes..." -ForegroundColor Cyan
    git add ".gitattributes"
    
    $changes = git status --porcelain ".gitattributes"
    if ($changes) {
        git commit -m "git: Enable LFS tracking for $Engine assets"
        Write-Host "Changes committed successfully." -ForegroundColor Green
    } else {
        Write-Host "No changes to commit." -ForegroundColor Yellow
    }

    # ----------------------- Push if requested -----------------------
    if ($DoPush -eq "push") {
        Write-Host "`nPushing to remote..." -ForegroundColor Cyan
        
        $branch = git branch --show-current
        if (-not $branch) { $branch = "main" }
        
        Write-Host "Pushing LFS objects..." -ForegroundColor Yellow
        git lfs push origin $branch --all
        
        Write-Host "Pushing commits..." -ForegroundColor Yellow
        git push origin $branch
        
        Write-Host "Push completed successfully." -ForegroundColor Green
    } else {
        Write-Host "`nTo push changes run:" -ForegroundColor Cyan
        $branch = git branch --show-current
        if (-not $branch) { $branch = "main" }
        Write-Host "  git lfs push origin $branch --all" -ForegroundColor Gray
        Write-Host "  git push origin $branch" -ForegroundColor Gray
    }

    Write-Host "`n✅ Setup completed successfully for $Engine!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Script execution failed." -ForegroundColor Red
    exit 1
}

# Keep console open if running in separate window
if ($Host.Name -eq "ConsoleHost") {
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}