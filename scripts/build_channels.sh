#!/usr/bin/env bash
# ============================================================
# 微旅途 MicroTrip —— 多渠道一键打包脚本（Bash 版，Windows Git Bash）
# ============================================================
# 用法（项目根目录执行）：
#   bash scripts/build_channels.sh                 # 全部渠道 APK + AAB
#   bash scripts/build_channels.sh huawei,xiaomi   # 仅指定渠道
#   bash scripts/build_channels.sh aab             # 仅 Google Play AAB
#
# 渠道注入：--dart-define=CHANNEL=<渠道>（AppConfig.channel 可读，关于页可见）
# 产物输出到 build/channels/，命名 microtrip-<版本>-<渠道>.apk / .aab
# ============================================================
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build/channels"
mkdir -p "$OUT"
VERSION="3.0.0"

# Git Bash 下 flutter.bat 需要 ProgramFiles 等环境变量，用数组保留引号
ENV_PREFIX=(env 'PROGRAMFILES(X86)=C:\Program Files (x86)' \
                PROGRAMFILES='C:\Program Files' \
                'CommonProgramFiles(X86)=C:\Program Files (x86)\Common Files')

build_apk() {
  local ch="$1"
  echo ""
  echo "===== 构建 APK 渠道: $ch ====="
  "${ENV_PREFIX[@]}" flutter build apk --release --target-platform android-arm64 \
    --dart-define=CHANNEL="$ch"
  if [ ! -f build/app/outputs/flutter-apk/app-release.apk ]; then
    echo "[FAIL] $ch APK 未生成"; exit 1
  fi
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/microtrip-$VERSION-$ch.apk"
  echo "[OK] $OUT/microtrip-$VERSION-$ch.apk"
}

build_aab() {
  echo ""
  echo "===== 构建 Google Play AAB ====="
  "${ENV_PREFIX[@]}" flutter build appbundle --release --target-platform android-arm64 \
    --dart-define=CHANNEL=googleplay
  if [ ! -f build/app/outputs/bundle/release/app-release.aab ]; then
    echo "[FAIL] AAB 未生成"; exit 1
  fi
  cp build/app/outputs/bundle/release/app-release.aab "$OUT/microtrip-$VERSION-googleplay.aab"
  echo "[OK] $OUT/microtrip-$VERSION-googleplay.aab"
}

# 参数解析
if [ "$#" -eq 0 ]; then
  TARGETS=("huawei" "xiaomi" "oppo" "vivo" "aab")
else
  TARGETS=("$@")
fi

for t in "${TARGETS[@]}"; do
  case "$t" in
    aab) build_aab ;;
    googleplay) build_aab ;;
    huawei|xiaomi|oppo|vivo|official) build_apk "$t" ;;
    *) echo "[SKIP] 未知渠道: $t" ;;
  esac
done

echo ""
echo "===== 构建完成，产物清单 ====="
ls -lh "$OUT"
