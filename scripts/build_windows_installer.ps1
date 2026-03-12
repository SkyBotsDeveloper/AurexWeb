param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$pubspec = Get-Content $pubspecPath -Raw
if ($pubspec -notmatch 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
  throw "Could not read app version from $pubspecPath"
}

$appVersion = $matches[1]
$buildDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$outputDir = Join-Path $repoRoot 'build\windows\installer'
$installerScript = Join-Path $repoRoot 'windows\installer\AurexInstaller.iss'

if (-not $SkipBuild) {
  flutter build windows --release
}

$isccCommand = Get-Command iscc -ErrorAction SilentlyContinue
$iscc = $null
if ($isccCommand) {
  $iscc = $isccCommand.Source
} else {
  $fallbackPaths = @(
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
  )
  foreach ($candidate in $fallbackPaths) {
    if (Test-Path $candidate) {
      $iscc = $candidate
      break
    }
  }
}

if (-not $iscc) {
  throw "Inno Setup Compiler (iscc.exe) was not found. Install Inno Setup 6, then rerun scripts\build_windows_installer.ps1"
}

New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

& $iscc `
  "/DAppVersion=$appVersion" `
  "/DBuildDir=$buildDir" `
  "/DOutputDir=$outputDir" `
  $installerScript

if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}

Write-Host "Installer created in $outputDir"
