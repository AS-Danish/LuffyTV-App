[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$androidRoot = Join-Path $projectRoot "android"
$keystorePath = Join-Path $androidRoot "app\luffytv-release.jks"
$propertiesPath = Join-Path $androidRoot "key.properties"

if ((Test-Path -LiteralPath $keystorePath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw "Release signing files already exist. Refusing to overwrite the app's signing identity."
}

$keytoolCommand = Get-Command keytool.exe -ErrorAction SilentlyContinue
$keytoolPath = if ($keytoolCommand) {
    $keytoolCommand.Source
} else {
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
}
if (-not (Test-Path -LiteralPath $keytoolPath)) {
    throw "keytool.exe was not found. Install Android Studio or add a JDK to PATH."
}

$secretBytes = New-Object byte[] 32
$random = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
try {
    $random.GetBytes($secretBytes)
} finally {
    $random.Dispose()
}
$password = [Convert]::ToBase64String($secretBytes).Replace("+", "-").Replace("/", "_").TrimEnd("=")
$alias = "luffytv-release"

& $keytoolPath `
    -genkeypair `
    -v `
    -keystore $keystorePath `
    -storetype JKS `
    -storepass $password `
    -keypass $password `
    -alias $alias `
    -keyalg RSA `
    -keysize 4096 `
    -sigalg SHA256withRSA `
    -validity 10000 `
    -dname "CN=Luffy TV, OU=Mobile, O=Luffy TV, C=IN"
if ($LASTEXITCODE -ne 0) {
    throw "keytool failed with exit code $LASTEXITCODE."
}

$normalizedKeystorePath = $keystorePath.Replace("\", "/")
$properties = @(
    "storePassword=$password"
    "keyPassword=$password"
    "keyAlias=$alias"
    "storeFile=$normalizedKeystorePath"
) -join [Environment]::NewLine

Set-Content -LiteralPath $propertiesPath -Value $properties -Encoding ASCII

Write-Host "Created release signing keystore: $keystorePath"
Write-Host "Created ignored signing configuration: $propertiesPath"
Write-Host "Back up both files before distributing the first APK."
