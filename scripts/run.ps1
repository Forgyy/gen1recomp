# Run the multi-game LOVE launcher on Windows. ROM import and cache generation
# happen inside the launcher. Extra arguments are passed through to LOVE.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Fail($message) {
    Write-Host "error: $message" -ForegroundColor Red
    exit 1
}

function Find-Love {
    if ($env:LOVE_PATH) {
        if (Test-Path -LiteralPath $env:LOVE_PATH -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:LOVE_PATH).Path
        }
        $candidate = Join-Path $env:LOVE_PATH 'love.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    foreach ($name in 'love', 'lovec') {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    foreach ($directory in @(
        "$env:ProgramFiles\LOVE",
        "${env:ProgramFiles(x86)}\LOVE",
        "$env:LOCALAPPDATA\Programs\LOVE"
    )) {
        foreach ($name in 'love.exe', 'lovec.exe') {
            $candidate = Join-Path $directory $name
            if ($directory -and (Test-Path $candidate)) { return $candidate }
        }
    }
    $parent = Split-Path -Parent $Root
    foreach ($bundle in Get-ChildItem -Path $parent -Directory `
            -Filter 'love-*-win64' -ErrorAction SilentlyContinue) {
        $directories = @($bundle.FullName) + @(
            Get-ChildItem -Path $bundle.FullName -Directory `
                -ErrorAction SilentlyContinue | ForEach-Object FullName
        )
        foreach ($directory in $directories) {
            foreach ($name in 'love.exe', 'lovec.exe') {
                $candidate = Join-Path $directory $name
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }
    return $null
}

$LoveBin = Find-Love
if (-not $LoveBin) {
    Fail 'LOVE not found; install it from https://love2d.org or set LOVE_PATH'
}

& $LoveBin $Root @args
exit $LASTEXITCODE
