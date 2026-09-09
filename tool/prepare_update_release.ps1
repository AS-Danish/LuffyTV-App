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

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath -ErrorAction Stop).Path
$releaseUri = [Uri]$HttpsUrl
if ($releaseUri.Scheme -ne 'https') {
    throw 'HttpsUrl must use HTTPS.'
}
if ($VersionCode -le 0) {
    throw 'VersionCode must be greater than zero.'
}

$file = Get-Item -LiteralPath $resolvedApk
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedApk)
try {
    $nativeAbis = @(
        $archive.Entries |
            Where-Object { $_.FullName -match '^lib/([^/]+)/[^/]+\.so$' } |
            ForEach-Object { [regex]::Match($_.FullName, '^lib/([^/]+)/').Groups[1].Value } |
            Sort-Object -Unique
    )
} finally {
    $archive.Dispose()
}
if ($nativeAbis.Count -ne 1 -or $nativeAbis[0] -ne 'arm64-v8a') {
    throw "Production APK must contain only arm64-v8a native libraries. Found: $($nativeAbis -join ', ')."
}

$hash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Output "APK_ABI=arm64-v8a"
Write-Output "ANDROID_VERSION=$Version"
Write-Output "ANDROID_VERSION_CODE=$VersionCode"
Write-Output "ANDROID_APK_URL=$HttpsUrl"
Write-Output "ANDROID_APK_SHA256=$hash"
Write-Output "ANDROID_APK_SIZE=$($file.Length)"
Write-Output "ANDROID_PUBLISHED_AT=$([DateTime]::UtcNow.ToString('o'))"
