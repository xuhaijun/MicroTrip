#!/bin/sh
# ============================================================
# 安装 privacy_policy.html 的 git clean filter（htmlclean）。
#
# 目的：IDE 的 HTML 预览会**持续回写** 37 个 data-page-node-id 属性到该文件
# （实测：git checkout 恢复后 2 秒内又被重新注入）。这个文件是隐私政策页面，
# 属于合规交付物，一旦带着这些属性提交，diff 会变得完全不可读、
# 「到底改了什么」无法复核。手工记得跑清理脚本是不可靠的。
#
# 安装后：`git add` 时自动剥离注入属性 —— 工作区可以保持被注入的样子，
# 提交内容始终干净，`git status` 也不再出现这个幽灵改动。
#
# 用法（每个 clone 执行一次）：
#     bash scripts/install_git_filters.sh
#     bash scripts/install_git_filters.sh --uninstall   # 卸载
#
# 幂等：重复执行安全。仅写入本仓库的 local config（不改全局配置）。
# ============================================================
set -u

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

FILTER_NAME=htmlclean
FILTER_CMD="sh scripts/git-htmlclean.sh"
TARGET=privacy_policy.html

# ---------- 卸载 ----------
if [ "${1:-}" = "--uninstall" ]; then
    git config --local --remove-section "filter.$FILTER_NAME" 2>/dev/null || true
    echo "已卸载 filter.$FILTER_NAME。注意 .gitattributes 中的声明仍在，"
    echo "未定义 filter 驱动时 git 会忽略它（行为退回手工清理），不会报错。"
    exit 0
fi

# ---------- 1. 检查 python 可用性 ----------
PY_DESC=""
for candidate in "${MICROTRIP_PYTHON:-}" python3 python py; do
    [ -z "$candidate" ] && continue
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "" >/dev/null 2>&1; then
        PY_DESC=$("$candidate" -c "import sys;print(sys.executable)")
        break
    fi
done

if [ -z "$PY_DESC" ]; then
    echo "⚠️  未找到可用的 python —— filter 会被安装，但运行时只能原样透传（不清理）。"
    echo "    如稍后装好 python，可设置 MICROTRIP_PYTHON 环境变量指向解释器后重试。"
else
    echo "✓ python: $PY_DESC"
fi

# ---------- 2. 自检 wrapper（人造输入 → 必须精确等于期望输出）----------
# 注意：这里必须比对**精确输出**。第一版只判断「输出里没有该属性」，
# 而 python 路径解析失败时输出恰好是空字符串 —— 空输出被误判为「通过」，
# 掩盖了真实故障。空输出是最危险的失败模式，必须单独拦。
PROBE_IN='<p data-page-node-id="AbC123" class="x">hello</p>'
PROBE_EXPECT='<p class="x">hello</p>'
PROBED=$(printf '%s' "$PROBE_IN" | sh scripts/git-htmlclean.sh)
if [ "$PROBED" = "$PROBE_EXPECT" ]; then
    echo "✓ wrapper 自检通过：$PROBE_IN → $PROBED"
elif [ -z "$PROBED" ]; then
    echo "✗ wrapper 自检失败：输出为空（python 可能没跑到目标脚本）"
    echo "    期望：$PROBE_EXPECT"
    echo "    请直接手工复现： echo '$PROBE_IN' | sh scripts/git-htmlclean.sh"
    exit 1
else
    echo "✗ wrapper 自检失败："
    echo "    期望：$PROBE_EXPECT"
    echo "    实际：$PROBED"
    exit 1
fi

# ---------- 2b. 属性是否真的挂上了 ----------
ATTR=$(git check-attr filter -- "$TARGET")
echo "✓ git check-attr: $ATTR"
case "$ATTR" in
    *": $FILTER_NAME") ;;
    *) echo "✗ $TARGET 的 filter 属性未指向 $FILTER_NAME，请检查 .gitattributes"; exit 1 ;;
esac

# ---------- 3. 写入 local config ----------
git config --local "filter.$FILTER_NAME.clean" "$FILTER_CMD"
git config --local "filter.$FILTER_NAME.required" false
echo "✓ 已写入 local config: filter.$FILTER_NAME.clean = $FILTER_CMD"

# ---------- 4. 端到端验证 ----------
# 4a. 哈希对比：raw（磁盘原样）vs filtered（git 实际会写入的对象）
#     两者相同 ⇒ filter 没起作用（未安装 / python 不可用 / 属性没挂上）
# 4b. 决定性验证：真的 add 进索引，然后断言索引里的内容不含注入属性。
#     这是唯一能证明「提交不会带上注入属性」的检查 —— 哈希只能说明「变了」，
#     不能说明「变对了」。仅在暂存区为空时执行（不打扰用户的半成品暂存）。
if [ -f "$TARGET" ] && git rev-parse --verify -q HEAD:"$TARGET" >/dev/null; then
    RAW=$(git hash-object --no-filters "$TARGET")
    FILTERED=$(git hash-object --path="$TARGET" "$TARGET")
    HEADHASH=$(git rev-parse HEAD:"$TARGET")

    echo ""
    echo "端到端验证（$TARGET）"
    echo "  磁盘原样     : $RAW"
    echo "  filter 之后  : $FILTERED   ← git 实际提交的内容"
    echo "  已提交版本   : $HEADHASH"

    if [ "$RAW" = "$FILTERED" ]; then
        echo "  ✗ filter 未生效（filtered 与 raw 相同）。请检查："
        echo "      git config --get filter.$FILTER_NAME.clean"
        echo "      git check-attr filter -- $TARGET"
        exit 1
    fi

    if git diff --cached --quiet 2>/dev/null; then
        git add -- "$TARGET"
        STAGED_HITS=$(git cat-file -p ":$TARGET" | grep -c "data-page-node-id" || true)
        git reset -q -- "$TARGET" 2>/dev/null || true
        if [ "${STAGED_HITS:-0}" -eq 0 ]; then
            echo "  ✓ 决定性验证通过：索引里的内容不含注入属性（暂存已还原，未留痕）"
        else
            echo "  ✗ 决定性验证失败：索引里仍有 $STAGED_HITS 处注入属性"
            echo "     这说明 filter 没有真正生效，请勿提交，先排查 python 环境。"
            exit 1
        fi
    else
        echo "  ⚠ 暂存区已有内容，跳过索引验证（避免打扰你的暂存）。"
        echo "     想单独验证：git add -- $TARGET && git cat-file -p :$TARGET | grep -c data-page-node-id"
    fi

    if [ "$FILTERED" = "$HEADHASH" ]; then
        echo "  ✓ 过滤结果与已提交版本一致 —— 幽灵改动已消失"
    else
        echo "  ℹ 过滤结果与已提交版本不同：磁盘内容确实有真实改动（如邮箱变更），"
        echo "     请 git diff 复核后再提交。"
    fi
else
    echo "（跳过端到端验证：$TARGET 或 HEAD 版本不存在）"
fi

echo ""
echo "完成。现在 git status 不应再出现 $TARGET 的无意义改动。"
echo "手工清理仍然可用： python scripts/clean_html_injection.py"
echo "卸载： bash scripts/install_git_filters.sh --uninstall"
