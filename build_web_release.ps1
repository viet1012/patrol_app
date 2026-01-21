$pubspec = "pubspec.yaml"
$content = Get-Content $pubspec -Raw

# Tìm version: x.y.z+N
$pattern = "version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)"
$m = [regex]::Match($content, $pattern)

if (-not $m.Success) {
    Write-Host "❌ Không tìm thấy version trong pubspec.yaml (format: version: x.y.z+N)"
    exit 1
}

$ver = $m.Groups[1].Value
$build = [int]$m.Groups[2].Value
$newBuild = $build + 1

$newLine = "version: $ver+$newBuild"
$newContent = [regex]::Replace($content, $pattern, $newLine, 1)

Set-Content $pubspec $newContent -NoNewline

Write-Host "✅ Version bumped: $ver+$build → $ver+$newBuild"

flutter clean
flutter pub get
flutter build web --release
