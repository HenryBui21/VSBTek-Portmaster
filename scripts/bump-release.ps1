<#
.SYNOPSIS
    Tự động tính toán phiên bản tiếp theo, tạo Git tag và đẩy lên GitHub để kích hoạt Release workflow.

.EXAMPLE
    # Kiểm tra version tiếp theo mà không tạo tag (dry-run)
    .\scripts\bump-release.ps1 -DryRun

.EXAMPLE
    # Tăng patch version (vd: v2.2.8 -> v2.2.9), tag và push
    .\scripts\bump-release.ps1

.EXAMPLE
    # Tăng minor version (vd: v2.2.8 -> v2.3.0)
    .\scripts\bump-release.ps1 -Type minor

.EXAMPLE
    # Chỉ định đích danh version
    .\scripts\bump-release.ps1 -Version "v2.2.9"
#>
param(
    [ValidateSet("patch", "minor", "major")]
    [string]$Type = "patch",

    [string]$Version,

    [switch]$DryRun,

    [string]$Remote = "origin"
)

$ErrorActionPreference = "Stop"

# Lấy tag v* lớn nhất hiện tại
$latestTag = (git tag -l "v*" --sort=-v:refname | Select-Object -First 1)
if (-not $latestTag) {
    $latestTag = "v0.0.0"
}

if ($Version) {
    $nextTag = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }
} else {
    $clean = $latestTag.TrimStart("v")
    $parts = $clean.Split(".")
    $major = if ($parts.Length -gt 0) { [int]$parts[0] } else { 0 }
    $minor = if ($parts.Length -gt 1) { [int]$parts[1] } else { 0 }
    $patch = if ($parts.Length -gt 2) { [int]$parts[2] } else { 0 }

    switch ($Type) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }
    $nextTag = "v{0}.{1}.{2}" -f $major, $minor, $patch
}

Write-Host "Phiên bản hiện tại : $latestTag" -ForegroundColor Cyan
Write-Host "Phiên bản tiếp theo: $nextTag" -ForegroundColor Green

if ($DryRun) {
    Write-Host "[DryRun] Dừng lại, chưa tạo tag." -ForegroundColor Yellow
    exit 0
}

# Kiểm tra tag đã tồn tại chưa
$existing = git tag -l $nextTag
if ($existing) {
    Write-Error "Tag $nextTag đã tồn tại! Vui lòng chọn phiên bản khác hoặc xóa tag cũ."
    exit 1
}

# Tạo annotated tag
git tag -a $nextTag -m "Release $nextTag"
Write-Host "Đã tạo tag $nextTag cục bộ thành công." -ForegroundColor Green

# Push tag lên GitHub remote
Write-Host "Đang đẩy tag $nextTag lên $Remote..." -ForegroundColor Cyan
git push $Remote $nextTag

Write-Host "Hoàn thành! GitHub Actions sẽ nhận tag $nextTag và bắt đầu build release." -ForegroundColor Green
