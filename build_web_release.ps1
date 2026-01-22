$pubspec = "pubspec.yaml"

# ?? luôn ép thành array
$lines = @(Get-Content $pubspec)

$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*version:\s*') {
        $idx = $i
        break
    }
}

if ($idx -lt 0) {
    Write-Host "? Không tìm th?y dòng version:"
    exit 1
}

# match version: x.y.z (cho phép có +N nhung không dùng)
if ($lines[$idx] -notmatch '^\s*version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?\s*$') {
    Write-Host "? Dòng version không dúng format:"
    Write-Host "   $($lines[$idx])"
    exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]

$old = "$major.$minor.$patch"

# ?? bump patch
$patch++
$new = "$major.$minor.$patch"

$lines[$idx] = "version: $new"

# ? ghi l?i file, gi? newline dúng YAML
Set-Content -Path $pubspec -Value $lines -Encoding UTF8

Write-Host "? Version bumped: $old ? $new"

flutter clean
flutter pub get
flutter build web --release
