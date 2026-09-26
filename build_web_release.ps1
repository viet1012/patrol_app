$ErrorActionPreference = "Stop"

$pubspec = "pubspec.yaml"
$generatedIndex = "build\web\index.html"
$versionJson = "build\web\version.json"

function Invoke-FlutterStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $pubspec -PathType Leaf)) {
    throw "Missing $pubspec. Run this script from the project root."
}

$pubspecContent = Get-Content -LiteralPath $pubspec -Raw -Encoding UTF8
$versionMatch = [regex]::Match(
    $pubspecContent,
    '(?m)^\s*version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\s*$'
)

if (-not $versionMatch.Success) {
    throw "The pubspec version must use the x.y.z format without a build number."
}

$major = [int]$versionMatch.Groups[1].Value
$minor = [int]$versionMatch.Groups[2].Value
$patch = [int]$versionMatch.Groups[3].Value
$oldVersion = "$major.$minor.$patch"

$maxPatch = 9
$maxMinor = 9
$patch++

if ($patch -gt $maxPatch) {
    $patch = 0
    $minor++
}

if ($minor -gt $maxMinor) {
    $minor = 0
    $major++
}

$newVersion = "$major.$minor.$patch"
$updatedPubspec = $pubspecContent.Remove(
    $versionMatch.Index,
    $versionMatch.Length
).Insert($versionMatch.Index, "version: $newVersion")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath $pubspec),
    $updatedPubspec,
    $utf8NoBom
)

Write-Host "Version bumped: $oldVersion -> $newVersion"

Invoke-FlutterStep -Description "flutter clean" -Arguments @("clean")
Invoke-FlutterStep -Description "flutter pub get" -Arguments @("pub", "get")
Invoke-FlutterStep -Description "flutter build web" -Arguments @(
    "build",
    "web",
    "--release",
    "--pwa-strategy=none"
)

if (-not (Test-Path -LiteralPath $generatedIndex -PathType Leaf)) {
    throw "Generated index was not found: $generatedIndex"
}

$generatedIndexContent = Get-Content `
    -LiteralPath $generatedIndex `
    -Raw `
    -Encoding UTF8
$generatedIndexContent = $generatedIndexContent.Replace(
    "__APP_VERSION__",
    $newVersion
)
[System.IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath $generatedIndex),
    $generatedIndexContent,
    $utf8NoBom
)

$verifiedIndexContent = Get-Content `
    -LiteralPath $generatedIndex `
    -Raw `
    -Encoding UTF8
if ($verifiedIndexContent.Contains("__APP_VERSION__")) {
    throw "Version placeholder remains in $generatedIndex."
}

$versionPayload = [ordered]@{ version = $newVersion } | ConvertTo-Json
[System.IO.File]::WriteAllText(
    (Join-Path (Get-Location) $versionJson),
    "$versionPayload`n",
    $utf8NoBom
)

$requiredFiles = @(
    $generatedIndex,
    "build\web\flutter_bootstrap.js",
    "build\web\main.dart.js",
    $versionJson,
    "build\web\js\zxing.min.js",
    "build\web\js\jsQR.js",
    "build\web\assets\fonts\MaterialIcons-Regular.otf"
)

foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required build output is missing: $requiredFile"
    }
}

$expectedZxing = "./js/zxing.min.js?v=$newVersion"
$expectedJsQr = "./js/jsQR.js?v=$newVersion"
if (-not $verifiedIndexContent.Contains($expectedZxing)) {
    throw "Generated index does not reference $expectedZxing"
}
if (-not $verifiedIndexContent.Contains($expectedJsQr)) {
    throw "Generated index does not reference $expectedJsQr"
}

Write-Host "Web build verified for version $newVersion."
