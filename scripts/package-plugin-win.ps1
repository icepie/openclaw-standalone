# OpenClaw plugin offline packager for Windows
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/package-plugin-win.ps1 @scope/plugin another-plugin
# Requires: Node.js 22+ installed on the build machine

param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$PluginSpecs,
    [string]$OutputDir = "output\plugins",
    [string]$BuildRoot = "build\plugin-pack",
    [string]$NpmRegistry = "https://registry.npmmirror.com"
)

$ErrorActionPreference = "Stop"

$SCRIPT_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $SCRIPT_ROOT

Write-Host "=== OpenClaw Plugin Packager ===" -ForegroundColor Cyan
Write-Host "Registry: $NpmRegistry"

$nodeVersion = & node --version 2>$null
if (-not $nodeVersion) {
    Write-Error "Node.js not found. Please install Node.js 22+ first."
    exit 1
}
Write-Host "Node.js version: $nodeVersion"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null

function Get-SafeName {
    param([string]$Name)

    $safe = $Name.TrimStart("@").Replace("/", "-").Replace("@", "-")
    return [regex]::Replace($safe, "[^A-Za-z0-9._-]", "-")
}

function Cleanup-PluginFiles {
    param([string]$PluginDir)

    $filePatterns = @(
        "*.md", "*.ts", "*.map",
        "CHANGELOG*", "HISTORY*", "AUTHORS*", "CONTRIBUTORS*",
        ".npmignore", ".eslintrc*", ".prettierrc*", "tsconfig*.json",
        "Makefile", ".editorconfig", ".travis.yml"
    )
    $dirPatterns = @(
        "test", "tests", "__tests__", "spec", "specs",
        "example", "examples", ".github", ".circleci"
    )

    foreach ($pattern in $filePatterns) {
        Get-ChildItem -Path $PluginDir -Recurse -Filter $pattern -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike "*.d.ts" } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    foreach ($pattern in $dirPatterns) {
        Get-ChildItem -Path $PluginDir -Recurse -Directory -Filter $pattern -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Remove-Item (Join-Path $PluginDir "package-lock.json") -Force -ErrorAction SilentlyContinue
}

foreach ($pluginSpec in $PluginSpecs) {
    $baseName = Get-SafeName $pluginSpec
    $workDir = Join-Path $BuildRoot $baseName
    $distDir = Join-Path $workDir "dist"
    $tmpDir = Join-Path $workDir "tmp"
    $packageDir = Join-Path $workDir "package"

    if (Test-Path $workDir) {
        Remove-Item -Recurse -Force $workDir
    }

    New-Item -ItemType Directory -Force -Path $distDir | Out-Null
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

    Write-Host "`n=== Packaging $pluginSpec ===" -ForegroundColor Cyan

    $packOutput = & npm pack $pluginSpec --pack-destination $distDir --registry $NpmRegistry
    if ($LASTEXITCODE -ne 0) {
        Write-Error "npm pack failed for $pluginSpec"
        exit 1
    }

    $tarballName = ($packOutput | Select-Object -Last 1).Trim()
    $tarballPath = Join-Path $distDir $tarballName

    tar -xzf $tarballPath -C $tmpDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to extract $tarballName"
        exit 1
    }

    Move-Item (Join-Path $tmpDir "package\*") $packageDir
    Remove-Item -Recurse -Force $tmpDir

    $packageJsonPath = Join-Path $packageDir "package.json"
    if (-not (Test-Path $packageJsonPath)) {
        Write-Error "package.json not found after extracting $tarballName"
        exit 1
    }

    Push-Location $packageDir
    & npm install --omit=dev --include=optional --install-strategy=nested --registry $NpmRegistry
    if ($LASTEXITCODE -ne 0) {
        Write-Error "npm install failed for $pluginSpec"
        exit 1
    }
    Pop-Location

    Cleanup-PluginFiles $packageDir

    $pkgJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    $pluginName = $pkgJson.name
    $pluginVersion = $pkgJson.version
    $platform = "win-x64"
    $archiveBase = "$(Get-SafeName $pluginName)-$pluginVersion-$platform"
    $zipPath = Join-Path $OutputDir "$archiveBase.zip"
    $checksumPath = "$zipPath.sha256"

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

    $hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
    "$hash  $([System.IO.Path]::GetFileName($zipPath))" | Set-Content $checksumPath -Encoding UTF8

    Write-Host "Created: $zipPath" -ForegroundColor Green
    Write-Host "Checksum: $(Get-Content $checksumPath)"
}

Write-Host "`n=== Plugin Packaging Complete ===" -ForegroundColor Green
Get-ChildItem $OutputDir | ForEach-Object {
    Write-Host ("  {0} ({1:N1} MB)" -f $_.Name, ($_.Length / 1MB))
}
