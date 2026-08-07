# Windows double-click bootstrap for the multi-game LOVE launcher.
# ROM verification and private cache generation happen inside the launcher.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Say($message) { Write-Host "==> $message" -ForegroundColor Green }
function Warn($message) { Write-Host " !! $message" -ForegroundColor Yellow }
function Err($message) { Write-Host "error: $message" -ForegroundColor Red }

function Pause-Exit([int]$code = 0) {
    Write-Host ''
    Read-Host 'Press Enter to close this window' | Out-Null
    exit $code
}

function Ask($question) {
    $answer = Read-Host "$question [Y/n]"
    return ($answer -notmatch '^(n|no)$')
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Find-Love {
    if ($env:LOVE_PATH) {
        if (Test-Path -LiteralPath $env:LOVE_PATH -PathType Leaf) { return $true }
        if (Test-Path (Join-Path $env:LOVE_PATH 'love.exe')) { return $true }
    }
    foreach ($name in 'love', 'lovec') {
        if (Get-Command $name -ErrorAction SilentlyContinue) { return $true }
    }
    foreach ($directory in @(
        "$env:ProgramFiles\LOVE",
        "${env:ProgramFiles(x86)}\LOVE",
        "$env:LOCALAPPDATA\Programs\LOVE"
    )) {
        if ($directory -and (Test-Path (Join-Path $directory 'love.exe'))) {
            return $true
        }
    }
    $parent = Split-Path -Parent $Root
    foreach ($bundle in Get-ChildItem -Path $parent -Directory `
            -Filter 'love-*-win64' -ErrorAction SilentlyContinue) {
        if (Test-Path (Join-Path $bundle.FullName 'love.exe')) { return $true }
        foreach ($child in Get-ChildItem -Path $bundle.FullName -Directory `
                -ErrorAction SilentlyContinue) {
            if (Test-Path (Join-Path $child.FullName 'love.exe')) { return $true }
        }
    }
    return $false
}

Write-Host ''
Write-Host '  Pokemon Red / Blue / Yellow / Crystal - LOVE2D port' `
    -ForegroundColor Cyan
Write-Host ''

if (-not (Find-Love)) {
    Say 'first-time LOVE setup'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Err 'LOVE is not installed and winget is unavailable.'
        Warn 'Install LOVE 11.x from https://love2d.org, then run this again.'
        Pause-Exit 1
    }
    if (Ask 'Install LOVE now via winget?') {
        winget install --exact --id Love2d.Love2d `
            --accept-source-agreements --accept-package-agreements
        Refresh-Path
        if (-not (Find-Love)) {
            Err 'LOVE still was not found; close this window and try again.'
            Pause-Exit 1
        }
    } else {
        Err 'cannot launch without LOVE'
        Pause-Exit 1
    }
}

Say 'launching the game selector'
& powershell -NoProfile -ExecutionPolicy Bypass `
    -File (Join-Path $Root 'scripts\run.ps1')
if ($LASTEXITCODE -ne 0) {
    Err 'the game failed to start'
    Pause-Exit 1
}
exit 0
