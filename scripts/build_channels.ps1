# ============================================================
# 微旅途 MicroTrip —— 多渠道一键打包脚本
# ============================================================
# 用法（项目根目录执行）：
#   powershell -ExecutionPolicy Bypass -File scripts\build_channels.ps1              # 全部渠道 APK + AAB
#   powershell -ExecutionPolicy Bypass -File scripts\build_channels.ps1 -Channels huawei,xiaomi
#   powershell -ExecutionPolicy Bypass -File scripts\build_channels.ps1 -AabOnly     # 仅 Google Play AAB
#
# 渠道注入方式：--dart-define=CHANNEL=<渠道>（App 内 AppConfig.channel 可读，
# 关于页可见），不引入 gradle flavor，保持 debug/日常构建流程零影响。
# 产物统一输出到 build\channels\，命名 microtrip-<版本>-<渠道>.apk / .aab
# ============================================================
param(
  [string]$Channels = "",   # 逗号分隔，留空 = 全部
  [switch]$AabOnly          # 仅构建 Google Play AAB
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

# 渠道清单（与商店一一对应；official = 官网/直接安装）
$AllChannels = @("huawei", "xiaomi", "oppo", "vivo", "official")
$Version = "3.0.0"
$OutDir = Join-Path $Root "build\channels"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 校验版本号与 pubspec 一致，防止双处漂移
$pubspec = Get-Content (Join-Path $Root "pubspec.yaml") -Raw
if ($pubspec -notmatch "version:\s*${Version}\+") {
  Write-Host "[WARN] pubspec.yaml 版本与脚本 VERSION=${Version} 不一致，请同步修改！" -ForegroundColor Yellow
}

function Build-Apk([string]$ch) {
  Write-Host "`n===== 构建 APK 渠道: $ch =====" -ForegroundColor Cyan
  flutter build apk --release --target-platform android-arm64 `
    --dart-define=CHANNEL=$ch
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk ($ch) 失败" }
  $src = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
  $dst = Join-Path $OutDir "microtrip-$Version-$ch.apk"
  Copy-Item $src $dst -Force
  Write-Host "[OK] $dst" -ForegroundColor Green
}

function Build-Aab {
  Write-Host "`n===== 构建 Google Play AAB =====" -ForegroundColor Cyan
  flutter build appbundle --release --target-platform android-arm64 `
    --dart-define=CHANNEL=googleplay
  if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle 失败" }
  $src = Join-Path $Root "build\app\outputs\bundle\release\app-release.aab"
  $dst = Join-Path $OutDir "microtrip-$Version-googleplay.aab"
  Copy-Item $src $dst -Force
  Write-Host "[OK] $dst" -ForegroundColor Green
}

if ($AabOnly) {
  Build-Aab
  exit 0
}

$targets = if ($Channels -ne "") { $Channels.Split(",") } else { $AllChannels }
foreach ($ch in $targets) {
  if ($ch -eq "googleplay") { Build-Aab } else { Build-Apk $ch }
}

Write-Host "`n===== 全部完成，产物清单 =====" -ForegroundColor Cyan
Get-ChildItem $OutDir | Format-Table Name, @{L="MB";E={[math]::Round($_.Length/1MB,1)}} -AutoSize
