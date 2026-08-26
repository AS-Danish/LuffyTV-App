param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [int]$VersionCode,
    [Parameter(Mandatory = $true)]
    [string]$HttpsUrl
)

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath -ErrorAction Stop).Path
$releaseUri = [Uri]$HttpsUrl
if ($releaseUri.Scheme -ne 'https') {
    throw 'HttpsUrl must use HTTPS.'
}
if ($VersionCode -le 0) {
    throw 'VersionCode must be greater than zero.'
}

$file = Get-Item -LiteralPath $resolvedApk
$hash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Output "ANDROID_VERSION=$Version"
Write-Output "ANDROID_VERSION_CODE=$VersionCode"
Write-Output "ANDROID_APK_URL=$HttpsUrl"
Write-Output "ANDROID_APK_SHA256=$hash"
Write-Output "ANDROID_APK_SIZE=$($file.Length)"
Write-Output "ANDROID_PUBLISHED_AT=$([DateTime]::UtcNow.ToString('o'))"
