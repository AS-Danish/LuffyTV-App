[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $projectRoot
try {
    & flutter build apk `
        --release `
        --flavor sideload `
        --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter ARM64 release build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-sideload-release.apk"
if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "Expected release APK was not produced at $apkPath."
}

$apk = Get-Item -LiteralPath $apkPath
$versionMatch = Select-String `
    -LiteralPath (Join-Path $projectRoot "pubspec.yaml") `
    -Pattern '^version:\s*([^+\s]+)\+(\d+)\s*$'
if ($null -eq $versionMatch) {
    throw "pubspec.yaml must contain a version in the form x.y.z+build."
}
$versionName = $versionMatch.Matches[0].Groups[1].Value
$versionCode = $versionMatch.Matches[0].Groups[2].Value
$namedApkPath = Join-Path `
    $apk.DirectoryName `
    "luffytv-$versionName-build$versionCode-arm64.apk"
Copy-Item -LiteralPath $apk.FullName -Destination $namedApkPath -Force
$namedApk = Get-Item -LiteralPath $namedApkPath

Write-Host "ARM64 release APK: $($namedApk.FullName)"
Write-Host ("Size: {0:N1} MB ({1} bytes)" -f ($namedApk.Length / 1MB), $namedApk.Length)
