$pubspec = "pubspec.yaml"

# Luôn ép thành array
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

# match version: x.y.z ho?c x.y.z+N
if ($lines[$idx] -notmatch '^\s*version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(\+[0-9]+)?\s*$') {
    Write-Host "? Dòng version không dúng format:"
    Write-Host "   $($lines[$idx])"
    exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]

$old = "$major.$minor.$patch"

# ===== RULE C?A B?N =====
$MAX_PATCH = 9
$MAX_MINOR = 9

$patch++

if ($patch -gt $MAX_PATCH) {
    $patch = 0
    $minor++
}

if ($minor -gt $MAX_MINOR) {
    $minor = 0
    $major++
}

$new = "$major.$minor.$patch"

$lines[$idx] = "version: $new"

# ghi l?i file
Set-Content -Path $pubspec -Value $lines -Encoding UTF8

Write-Host "? Version bumped: $old ? $new"

# ===== Flutter build =====
flutter clean
flutter pub get
flutter build web --release

# inject version vào index.html
$index = "build\web\index.html"
(Get-Content $index) -replace "__APP_VERSION__", $new | Set-Content $index -Encoding UTF8